# Domain Events Reference

## Architecture Overview

```
Model domain method (card.close, card.triage_into)
  -> track_event("closed", particulars: {...})
    -> Eventable concern builds action string ("card_closed")
      -> board.events.create!(action:, eventable:, creator:, particulars:)
        -> Event after_create: eventable.event_was_created(event)
        -> Event after_create_commit: dispatch_webhooks
        -> Event after_create_commit: notify_recipients_later
```

## Event Model

One table, one model. The `action` string + `eventable` polymorphic + `particulars`
JSON replace what would otherwise be dozens of separate event model classes.

```ruby
# app/models/event.rb
class Event < ApplicationRecord
  include Notifiable, Particulars

  belongs_to :account, default: -> { board.account }
  belongs_to :board
  belongs_to :creator, class_name: "User"
  belongs_to :eventable, polymorphic: true

  has_many :webhook_deliveries, class_name: "Webhook::Delivery", dependent: :delete_all

  scope :chronologically, -> { order created_at: :asc, id: :desc }
  scope :preloaded, -> {
    includes(:creator, :board, {
      eventable: [
        :closure, :image_attachment,
        { rich_text_body: :embeds_attachments },
        { rich_text_description: :embeds_attachments },
        { card: [ :closure, :image_attachment ] }
      ]
    })
  }

  after_create -> { eventable.event_was_created(self) }
  after_create_commit :dispatch_webhooks

  delegate :card, to: :eventable

  def action
    super.inquiry
  end

  def notifiable_target
    eventable
  end

  def description_for(user)
    Event::Description.new(self, user)
  end

  private
    def dispatch_webhooks
      Event::WebhookDispatchJob.perform_later(self)
    end
end
```

### Migration

```ruby
class CreateEvents < ActiveRecord::Migration[8.0]
  def change
    create_table :events, id: :uuid do |t|
      t.references :account, null: false, type: :uuid
      t.string :action, null: false
      t.references :board, null: false, type: :uuid
      t.references :creator, null: false, type: :uuid
      t.references :eventable, polymorphic: true, null: false, type: :uuid
      t.json :particulars, default: -> { "(json_object())" }

      t.timestamps
    end

    add_index :events, [:account_id, :action]
    add_index :events, [:board_id, :action, :created_at]
  end
end
```

## Eventable Concern (Base)

The generic concern that any model can include to gain `track_event`:

```ruby
# app/models/concerns/eventable.rb
module Eventable
  extend ActiveSupport::Concern

  included do
    has_many :events, as: :eventable, dependent: :destroy
  end

  def track_event(action, creator: Current.user, board: self.board, **particulars)
    if should_track_event?
      board.events.create!(
        action: "#{eventable_prefix}_#{action}",
        creator:, board:, eventable: self, particulars:
      )
    end
  end

  # Override in model-specific Eventable to react to event creation.
  # Called synchronously within the transaction via Event's after_create.
  def event_was_created(event)
  end

  private
    def should_track_event?
      true
    end

    def eventable_prefix
      self.class.name.demodulize.underscore
    end
end
```

Key design points:
- `eventable_prefix` auto-generates from the class name: `Card` -> `"card"`,
  `Comment` -> `"comment"`. Combined with the action: `"card_closed"`,
  `"comment_created"`.
- `should_track_event?` is a guard -- override it in model-specific concerns
  to skip tracking (e.g., draft cards should not generate events).
- `event_was_created` is a hook for the eventable to react after the event
  is persisted but within the same transaction (create system comments, touch
  timestamps, etc.).

## Model-Specific Eventable Concerns

### Card::Eventable

Cards customize event tracking with publish guards, system comments, and
last-active timestamps:

```ruby
# app/models/card/eventable.rb
module Card::Eventable
  extend ActiveSupport::Concern

  include ::Eventable

  included do
    before_create { self.last_active_at ||= created_at || Time.current }

    after_save :track_title_change, if: :saved_change_to_title?
  end

  def event_was_created(event)
    transaction do
      create_system_comment_for(event)
      touch_last_active_at unless was_just_published?
    end
  end

  def touch_last_active_at
    update!(last_active_at: Time.current)
  end

  private
    def should_track_event?
      published?
    end

    def track_title_change
      if title_before_last_save.present?
        track_event "title_changed",
          particulars: { old_title: title_before_last_save, new_title: title }
      end
    end

    def create_system_comment_for(event)
      SystemCommenter.new(self, event).comment
    end
end
```

### Comment::Eventable

Comments track creation and update the parent card's activity timestamp:

```ruby
# app/models/comment/eventable.rb
module Comment::Eventable
  extend ActiveSupport::Concern

  include ::Eventable

  included do
    after_create_commit :track_creation
  end

  def event_was_created(event)
    card.touch_last_active_at
  end

  private
    def should_track_event?
      !creator.system?
    end

    def track_creation
      track_event("created", board: card.board, creator: creator)
    end
end
```

## How Models Call track_event

Events are tracked inside domain methods, not callbacks. The model concern
contains the business logic and calls `track_event` at the right moment:

### Card::Closeable

```ruby
module Card::Closeable
  def close(user: Current.user)
    unless closed?
      transaction do
        create_closure! user: user
        track_event :closed, creator: user
      end
    end
  end

  def reopen(user: Current.user)
    if closed?
      transaction do
        closure&.destroy
        track_event :reopened, creator: user
      end
    end
  end
end
```

### Card::Assignable

```ruby
module Card::Assignable
  private
    def assign(user)
      assignment = assignments.create assignee: user, assigner: Current.user
      if assignment.persisted?
        watch_by user
        track_event :assigned, assignee_ids: [ user.id ]
      end
    end

    def unassign(user)
      destructions = assignments.destroy_by assignee: user
      track_event :unassigned, assignee_ids: [ user.id ] if destructions.any?
    end
end
```

### Card::Triageable

```ruby
module Card::Triageable
  def triage_into(column)
    transaction do
      update! column: column
      track_event "triaged", particulars: { column: column.name }
    end
  end

  def send_back_to_triage(skip_event: false)
    transaction do
      update! column: nil
      track_event "sent_back_to_triage" unless skip_event
    end
  end
end
```

### Card::Postponable

```ruby
module Card::Postponable
  def postpone(user: Current.user, event_name: :postponed)
    transaction do
      send_back_to_triage(skip_event: true)
      reopen
      create_not_now!(user: user) unless postponed?
      track_event event_name, creator: user
    end
  end

  def auto_postpone(**args)
    postpone(**args, event_name: :auto_postponed)
  end
end
```

### Card::Statuses

```ruby
module Card::Statuses
  included do
    after_create -> { track_event :published }, if: :published?
  end

  def publish
    transaction do
      self.created_at = Time.current
      published!
      track_event :published
    end
  end
end
```

### Board change (on Card model)

```ruby
class Card < ApplicationRecord
  private
    def handle_board_change
      old_board = account.boards.find_by(id: board_id_before_last_save)
      transaction do
        update! column: nil
        track_event "board_changed",
          particulars: { old_board: old_board.name, new_board: board.name }
      end
    end
end
```

## Particulars (Event Metadata)

The `particulars` JSON column stores action-specific data. Use `store_accessor`
for typed access to frequently queried fields:

```ruby
# app/models/event/particulars.rb
module Event::Particulars
  extend ActiveSupport::Concern

  included do
    store_accessor :particulars, :assignee_ids
  end

  def assignees
    @assignees ||= User.where id: assignee_ids
  end
end
```

Access nested particulars via hash dig:

```ruby
event.particulars.dig("particulars", "old_title")
event.particulars.dig("particulars", "column")
event.particulars.dig("particulars", "new_board")
```

## Event Description

A dedicated class generates human-readable descriptions from events:

```ruby
# app/models/event/description.rb
class Event::Description
  def initialize(event, user)
    @event = event
    @user = user
  end

  def to_html
    # "You closed \"Card title\"" or "Alice closed \"Card title\""
  end

  def to_plain_text
    # Plain text for webhooks, emails, Slack
  end

  private
    def action_sentence(creator, card_title)
      case event.action
      when "card_assigned"   then "#{creator} assigned #{assignee_names} to #{card_title}"
      when "card_closed"     then %(#{creator} moved #{card_title} to "Done")
      when "card_reopened"   then "#{creator} reopened #{card_title}"
      when "card_published"  then "#{creator} added #{card_title}"
      when "card_postponed"  then %(#{creator} moved #{card_title} to "Not Now")
      when "card_triaged"    then %(#{creator} moved #{card_title} to "#{column}")
      when "comment_created" then "#{creator} commented on #{card_title}"
      end
    end
end
```

## Complete List of Actions

| Action | Eventable | Particulars |
|--------|-----------|-------------|
| `card_published` | Card | -- |
| `card_closed` | Card | -- |
| `card_reopened` | Card | -- |
| `card_assigned` | Card | `assignee_ids` |
| `card_unassigned` | Card | `assignee_ids` |
| `card_postponed` | Card | -- |
| `card_auto_postponed` | Card | -- |
| `card_triaged` | Card | `column` |
| `card_sent_back_to_triage` | Card | -- |
| `card_title_changed` | Card | `old_title`, `new_title` |
| `card_board_changed` | Card | `old_board`, `new_board` |
| `comment_created` | Comment | -- |

## Testing Events

```ruby
test "closing a card tracks card_closed event" do
  card = cards(:published)

  assert_difference -> { Event.count } do
    card.close(user: users(:alice))
  end

  event = Event.last
  assert_equal "card_closed", event.action
  assert_equal card, event.eventable
  assert_equal users(:alice), event.creator
end

test "triaging a card stores column name in particulars" do
  card = cards(:awaiting_triage)
  column = columns(:in_progress)

  card.triage_into(column)

  event = Event.last
  assert_equal "card_triaged", event.action
  assert_equal({ "column" => column.name }, event.particulars)
end

test "draft cards do not generate events" do
  card = cards(:draft)

  assert_no_difference -> { Event.count } do
    card.close(user: users(:alice))
  end
end

test "system comments do not generate events" do
  comment = comments(:system_generated)

  assert_no_difference -> { Event.count } do
    # system user comments are filtered by should_track_event?
  end
end

test "enqueues webhook dispatch job on event creation" do
  card = cards(:published)

  assert_enqueued_with(job: Event::WebhookDispatchJob) do
    card.close(user: users(:alice))
  end
end
```
