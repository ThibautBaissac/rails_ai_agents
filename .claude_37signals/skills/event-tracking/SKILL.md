---
name: event-tracking
description: >-
  Builds event tracking, activity feeds, and webhook systems following 37signals
  patterns with a generic Event model and Eventable concern. Use when implementing
  audit trails, activity feeds, event recording, webhooks, or when user mentions
  events, tracking, webhooks, or activity logs.
  WHEN NOT: For state changes as records (use state-records), for background
  job patterns (use job-patterns), for mailer delivery (use mailer-patterns).
license: MIT
compatibility: Ruby 3.3+, Rails 8.0+, Solid Queue
---

# Event Tracking

## Philosophy: Generic Event Model + Eventable Concern

- One `Event` model with `action` string and `eventable` polymorphic association
- An `Eventable` concern mixed into models that need tracking
- Models call `track_event("closed", particulars: {...})` in their domain methods
- `particulars` JSON field stores action-specific metadata
- Events drive activity feeds, notifications, and webhook deliveries
- Everything is database-backed (Solid Queue for webhooks, no Redis/Kafka)

## Project Knowledge

**Stack:** Solid Queue for background jobs, Turbo Streams for real-time activity
feed updates, UUIDs for all primary keys, MySQL (SaaS) / SQLite (OSS).

**Multi-tenancy:** All events scoped to account via `account_id`. Events also
scoped to board via `board_id`.

**Commands:**
```bash
# Generate Event model
rails generate model Event action:string eventable:references{polymorphic} \
  board:references creator:references account:references particulars:json

# Generate Webhook models
rails generate model Webhook url:text name:string board:references \
  account:references subscribed_actions:text signing_secret:string active:boolean
rails generate model Webhook::Delivery webhook:references event:references \
  account:references state:string request:text response:text
rails generate model Webhook::DelinquencyTracker webhook:references \
  account:references consecutive_failures_count:integer first_failure_at:datetime
```

## Pattern 1: Event Model

See @references/domain-events.md for full implementation details.

A single generic `Event` model records all business events:

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

  def description_for(user)
    Event::Description.new(self, user)
  end

  private
    def dispatch_webhooks
      Event::WebhookDispatchJob.perform_later(self)
    end
end
```

Key design decisions:
- `action` is a plain string like `"card_closed"`, `"comment_created"`,
  `"card_triaged"`. Calling `.inquiry` lets you do `event.action.card_closed?`.
- `eventable` points to the model that triggered the event (Card, Comment, etc.).
- `particulars` is a JSON column for action-specific metadata (old title, new
  board name, assignee IDs, column name, etc.).
- `after_create` (not `after_create_commit`) calls back into the eventable so
  it can create system comments or touch timestamps within the same transaction.
- `after_create_commit` dispatches webhooks asynchronously.

## Pattern 2: Eventable Concern

See @references/domain-events.md for the full concern hierarchy.

The base `Eventable` concern provides `track_event` to any model:

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

Models override `Eventable` with model-specific concerns that customize behavior:

```ruby
# app/models/card/eventable.rb
module Card::Eventable
  extend ActiveSupport::Concern

  include ::Eventable

  included do
    after_save :track_title_change, if: :saved_change_to_title?
  end

  def event_was_created(event)
    transaction do
      create_system_comment_for(event)
      touch_last_active_at
    end
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
end
```

Usage in domain methods -- models call `track_event` directly:

```ruby
# app/models/card/closeable.rb
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

# app/models/card/assignable.rb
def assign(user)
  assignment = assignments.create assignee: user, assigner: Current.user
  if assignment.persisted?
    track_event :assigned, assignee_ids: [ user.id ]
  end
end

# app/models/card/triageable.rb
def triage_into(column)
  transaction do
    update! column: column
    track_event "triaged", particulars: { column: column.name }
  end
end

# app/models/card/postponable.rb
def postpone(user: Current.user, event_name: :postponed)
  transaction do
    create_not_now!(user: user) unless postponed?
    track_event event_name, creator: user
  end
end
```

## Pattern 3: Particulars (Event Metadata)

The `particulars` JSON column stores action-specific data. Use `store_accessor`
to provide typed access to common fields:

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

Examples of particulars stored per action:

| Action | Particulars |
|--------|-------------|
| `card_title_changed` | `{ old_title: "...", new_title: "..." }` |
| `card_board_changed` | `{ old_board: "...", new_board: "..." }` |
| `card_assigned` | `{ assignee_ids: [uuid] }` |
| `card_unassigned` | `{ assignee_ids: [uuid] }` |
| `card_triaged` | `{ column: "In Progress" }` |

## Pattern 4: Activity Feed

See @references/activity-feeds.md for view templates and pagination.

Events ARE the activity feed. No separate `Activity` model needed:

```ruby
# app/controllers/events_controller.rb
class EventsController < ApplicationController
  def index
    @events = Current.account.boards
      .accessible_by(Current.user)
      .events.preloaded.chronologically
  end
end
```

Events are rendered via partials that dispatch on `action` or `eventable_type`:

```erb
<%# app/views/events/_event.html.erb %>
<% cache event do %>
  <% if lookup_context.exists?("events/event/eventable/_#{event.action}") %>
    <%= render "events/event/eventable/#{event.action}", event: event %>
  <% else %>
    <%= render "events/event/eventable/#{event.eventable_type.demodulize.underscore}",
               event: event %>
  <% end %>
<% end %>
```

Event descriptions are handled by a dedicated class:

```ruby
# app/models/event/description.rb
class Event::Description
  def initialize(event, user)
    @event = event
    @user = user
  end

  def to_html
    # Renders "You closed \"Card title\"" or "Alice closed \"Card title\""
    # depending on whether user == creator
  end

  def to_plain_text
    # Plain text version for webhooks, emails, etc.
  end
end
```

## Pattern 5: Webhook System

See @references/webhooks.md for full implementation details.

```ruby
# app/models/webhook.rb
class Webhook < ApplicationRecord
  include Triggerable

  PERMITTED_ACTIONS = %w[
    card_assigned card_closed card_postponed card_published
    card_reopened card_triaged card_unassigned comment_created
  ].freeze

  has_secure_token :signing_secret

  has_many :deliveries, dependent: :delete_all
  has_one :delinquency_tracker, dependent: :delete

  belongs_to :account, default: -> { board.account }
  belongs_to :board

  serialize :subscribed_actions, type: Array, coder: JSON

  scope :active, -> { where(active: true) }

  normalizes :subscribed_actions,
    with: ->(value) { Array.wrap(value).map(&:to_s).uniq & PERMITTED_ACTIONS }

  validates :name, presence: true
  validate :validate_url

  def activate
    update! active: true unless active?
  end

  def deactivate
    update! active: false
  end
end

# app/models/webhook/triggerable.rb
module Webhook::Triggerable
  extend ActiveSupport::Concern

  included do
    scope :triggered_by, ->(event) {
      where(board: event.board).triggered_by_action(event.action)
    }
    scope :triggered_by_action, ->(action) {
      where("subscribed_actions LIKE ?", "%\"#{action}\"%")
    }
  end

  def trigger(event)
    deliveries.create!(event: event) unless account.cancelled?
  end
end
```

Webhook dispatch uses ActiveJob::Continuable for resumable processing:

```ruby
# app/jobs/event/webhook_dispatch_job.rb
class Event::WebhookDispatchJob < ApplicationJob
  include ActiveJob::Continuable

  queue_as :webhooks
  discard_on ActiveJob::DeserializationError

  def perform(event)
    step :dispatch do |step|
      Webhook.active.triggered_by(event).find_each(start: step.cursor) do |webhook|
        webhook.trigger(event)
        step.advance! from: webhook.id
      end
    end
  end
end
```

Deliveries handle SSRF protection, format detection, and delinquency tracking:

```ruby
# app/models/webhook/delivery.rb
class Webhook::Delivery < ApplicationRecord
  belongs_to :webhook
  belongs_to :event
  belongs_to :account, default: -> { webhook.account }

  store :request, coder: JSON
  store :response, coder: JSON

  enum :state, %w[ pending in_progress completed errored ].index_by(&:itself),
    default: :pending

  after_create_commit :deliver_later

  def deliver
    in_progress!
    self.request[:headers] = headers
    self.response = perform_request
    self.state = :completed
    save!
    webhook.delinquency_tracker.record_delivery_of(self)
  rescue
    errored!
    raise
  end

  private
    def headers
      { "User-Agent" => "app/1.0.0 Webhook",
        "Content-Type" => content_type,
        "X-Webhook-Signature" => signature,
        "X-Webhook-Timestamp" => event.created_at.utc.iso8601 }
    end

    def signature
      OpenSSL::HMAC.hexdigest("SHA256", webhook.signing_secret, payload)
    end
end

# app/models/webhook/delinquency_tracker.rb
class Webhook::DelinquencyTracker < ApplicationRecord
  DELINQUENCY_THRESHOLD = 10
  DELINQUENCY_DURATION = 1.hour

  belongs_to :webhook

  def record_delivery_of(delivery)
    if delivery.succeeded?
      reset
    else
      mark_first_failure_time if consecutive_failures_count.zero?
      increment!(:consecutive_failures_count, touch: true)
      webhook.deactivate if delinquent?
    end
  end

  private
    def delinquent?
      failing_for_too_long? && too_many_consecutive_failures?
    end

    def failing_for_too_long?
      first_failure_at&.before?(DELINQUENCY_DURATION.ago)
    end

    def too_many_consecutive_failures?
      consecutive_failures_count >= DELINQUENCY_THRESHOLD
    end
end
```

## Boundaries

### Always
- Use a single generic `Event` model with `action` string and `eventable` polymorphic
- Create an `Eventable` concern -- models call `track_event` in domain methods
- Store action-specific data in `particulars` JSON column
- Dispatch webhooks via background jobs (Solid Queue)
- Include HMAC signature in webhook headers (`X-Webhook-Signature`)
- Scope events to account and board
- Use `after_create_commit` for webhook dispatch (async after transaction)
- Use `after_create` (sync) for side effects that need the transaction (system comments)

### Ask First
- Which business events/actions to track
- Webhook retry strategy and delinquency threshold
- Activity feed pagination and filtering requirements
- Whether events should create system comments on the eventable
- SSRF protection requirements for webhook delivery

### Never
- Create separate model classes per event type (no `CardMoved`, `CommentAdded` models)
- Use external event bus (Kafka, RabbitMQ)
- Track boolean flags instead of event records
- Deliver webhooks synchronously
- Skip SSRF protection on webhook URLs
- Store events without account + board scoping
