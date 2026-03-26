# Model Examples

Complete model examples with all 37signals patterns applied.

## Rich model with concerns

```ruby
# app/models/card.rb
class Card < ApplicationRecord
  include Assignable, Attachments, Broadcastable, Closeable, Colored,
          Commentable, Entropic, Eventable, Golden, NotNowable, Pinnable,
          Positionable, Readable, Searchable, Viewable, Watchable

  # Associations
  belongs_to :account, default: -> { board.account }
  belongs_to :board, touch: true
  belongs_to :column, touch: true
  belongs_to :creator, class_name: "User", default: -> { Current.user }

  # Validations
  validates :title, presence: true
  validates :status, inclusion: { in: %w[draft published archived] }

  # Enums
  enum :status, { draft: "draft", published: "published", archived: "archived" }, default: :draft

  # Scopes
  scope :recent, -> { order(created_at: :desc) }
  scope :positioned, -> { order(:position) }
  scope :active, -> { open.published.where.missing(:not_now) }

  # Delegations
  delegate :name, to: :board, prefix: true, allow_nil: true
  delegate :can_administer_card?, to: :board, prefix: false

  # Callbacks
  after_create_commit :broadcast_creation
  after_update_commit :broadcast_update
  after_destroy_commit :broadcast_removal

  # Business logic
  def publish
    update!(status: :published)
    track_event "card_published"
  end

  def archive
    update!(status: :archived)
    track_event "card_archived"
  end

  def move_to_column(new_column)
    update!(column: new_column)
    track_event "card_moved", particulars: {
      from_column_id: column_id_before_last_save,
      to_column_id: new_column.id
    }
  end

  private

  def broadcast_creation
    broadcast_prepend_to board, :cards, target: "cards", partial: "cards/card"
  end
end
```

## State record model

```ruby
# app/models/closure.rb
class Closure < ApplicationRecord
  belongs_to :account, default: -> { card.account }
  belongs_to :card, touch: true
  belongs_to :user, optional: true

  validates :card, uniqueness: true

  after_create_commit :notify_watchers
  after_destroy_commit :notify_watchers

  private

  def notify_watchers
    card.notify_watchers_later
  end
end
```

## Join table model with behavior

```ruby
# app/models/assignment.rb
class Assignment < ApplicationRecord
  belongs_to :account, default: -> { card.account }
  belongs_to :card, touch: true
  belongs_to :user

  validates :user_id, uniqueness: { scope: :card_id }

  after_create_commit :track_assignment_created
  after_destroy_commit :track_assignment_destroyed

  def notify_assignee
    AssignmentMailer.assigned(self).deliver_later
  end

  private

  def track_assignment_created
    card.track_event "card_assigned", user: user, particulars: { assignee_id: user.id }
  end

  def track_assignment_destroyed
    card.track_event "card_unassigned", user: user, particulars: { assignee_id: user.id }
  end
end
```

## Polymorphic model

```ruby
# app/models/comment.rb
class Comment < ApplicationRecord
  belongs_to :account, default: -> { card.account }
  belongs_to :card, touch: true
  belongs_to :creator, class_name: "User", default: -> { Current.user }

  has_many :attachments, as: :attachable, dependent: :destroy

  validates :body, presence: true

  scope :recent, -> { order(created_at: :desc) }
  scope :by_creator, ->(user) { where(creator: user) }

  after_create_commit :notify_recipients_later
  after_create_commit :broadcast_creation

  def notify_recipients_later
    NotifyRecipientsJob.perform_later(self)
  end

  def notify_recipients_now
    recipients = card.watchers + card.assignees + [card.creator]
    recipients.uniq.each do |recipient|
      next if recipient == creator

      Notification.create!(
        recipient: recipient,
        notifiable: self,
        action: "comment_created"
      )
    end
  end

  private

  def broadcast_creation
    broadcast_prepend_to card, :comments
  end
end
```

## PORO for presentation logic

```ruby
# app/models/card/eventable/system_commenter.rb
class Card::Eventable::SystemCommenter
  include ERB::Util

  attr_reader :event

  def initialize(event)
    @event = event
  end

  def create_system_comment
    event.card.comments.create!(
      body: comment_body,
      creator: nil,
      system: true
    )
  end

  private

  def comment_body
    case event.action
    when "card_closed"
      "#{event.user.name} closed this card"
    when "card_assigned"
      "#{event.user.name} assigned this to #{assignee.name}"
    end
  end
end
```

## Migration patterns

### Creating a model

```ruby
class CreateCards < ActiveRecord::Migration[8.2]
  def change
    create_table :cards, id: :uuid do |t|
      t.references :account, null: false, type: :uuid
      t.references :board, null: false, type: :uuid
      t.references :column, null: false, type: :uuid
      t.references :creator, null: false, type: :uuid, foreign_key: { to_table: :users }

      t.string :title, null: false
      t.text :body
      t.string :status, default: "draft", null: false
      t.integer :position

      t.timestamps
    end

    add_index :cards, [:board_id, :position]
    add_index :cards, :status
  end
end
```

### State record migration

```ruby
class CreateClosures < ActiveRecord::Migration[8.2]
  def change
    create_table :closures, id: :uuid do |t|
      t.references :account, null: false, type: :uuid
      t.references :card, null: false, type: :uuid
      t.references :user, null: true, type: :uuid

      t.timestamps
    end

    add_index :closures, :card_id, unique: true
  end
end
```

## Testing models

```ruby
class CardTest < ActiveSupport::TestCase
  setup do
    @card = cards(:logo)
    @user = users(:david)
    Current.user = @user
    Current.account = @card.account
  end

  test "closing card creates closure record" do
    assert_difference -> { Closure.count }, 1 do
      @card.close
    end

    assert @card.closed?
    assert_equal @user, @card.closed_by
  end

  test "open scope excludes closed cards" do
    @card.close

    assert_not_includes Card.open, @card
    assert_includes Card.closed, @card
  end

  test "assign creates assignment and tracks event" do
    assert_difference -> { @card.assignments.count }, 1 do
      @card.assign(@user)
    end

    assert @card.assigned_to?(@user)
    assert_equal "card_assigned", @card.events.last.action
  end

  test "validates title presence" do
    card = Card.new(board: @card.board, column: @card.column)

    assert_not card.valid?
    assert_includes card.errors[:title], "can't be blank"
  end
end
```

## Query methods (class methods for complex queries)

```ruby
def self.search(query)
  where("title LIKE ? OR body LIKE ?", "%#{query}%", "%#{query}%")
    .order("CASE
              WHEN title LIKE ? THEN 3
              WHEN body LIKE ? THEN 2
              ELSE 1
            END DESC", "%#{query}%", "%#{query}%")
end

def self.for_user(user)
  where(creator: user)
    .or(assigned_to(user))
    .or(watched_by(user))
    .distinct
end
```

## Delegation patterns

```ruby
delegate :name, to: :board, prefix: true         # board_name
delegate :email, to: :creator, prefix: :author    # author_email
delegate :can_administer_card?, to: :board, prefix: false
delegate :name, to: :board, prefix: true, allow_nil: true
```
