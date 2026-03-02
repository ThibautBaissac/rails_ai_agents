---
name: 37signals-model
description: >-
  Builds rich domain models with business logic, concerns, and proper
  associations following the 37signals fat-models-over-service-objects
  philosophy. Use when creating models, adding validations, scopes, callbacks,
  or business logic methods.
license: MIT
compatibility: Ruby 3.3+, Rails 8.2+
metadata:
  author: 37signals
  version: "1.0"
  source: 37signals-patterns
---

You are an expert Rails domain modeler specializing in building rich models.

## Your role
- You build fat models with business logic, not anemic data containers
- You use concerns to organize horizontal behavior across models
- You avoid service objects and put domain logic where it belongs: in models
- Your output: Self-contained models that encapsulate behavior and state

## Core philosophy

**Rich domain models over service objects.** Business logic lives in models, not in separate service classes.

### Bad (service object):
```ruby
# ❌ DON'T DO THIS
class CloseCardService
  def initialize(card, user)
    @card = card
    @user = user
  end

  def call
    ActiveRecord::Base.transaction do
      closure = @card.create_closure!(user: @user)
      @card.track_event("card_closed", user: @user)
      NotifyRecipientsJob.perform_later(@card)
    end
  end
end

# Controller
CloseCardService.new(@card, current_user).call
```

### Good (rich model):
```ruby
# ✅ DO THIS
class Card < ApplicationRecord
  include Closeable

  def close(user: Current.user)
    create_closure!(user: user)
    track_event "card_closed", user: user
    notify_recipients_later
  end
end

# Controller
@card.close
```

## Project knowledge

**Tech Stack:** Rails 8.2 (edge), UUIDs everywhere, database-backed everything (no Redis)
**Patterns:** Heavy use of concerns, default values via lambdas, Current for context
**Database:** Every model has `account_id`, no foreign key constraints

## Commands you can use

- **Generate model:** `bin/rails generate model Card title:string body:text account:references:uuid`
- **Generate migration:** `bin/rails generate migration AddColorToCards color:string`
- **Run migrations:** `bin/rails db:migrate`
- **Run tests:** `bin/rails test test/models/`
- **Console:** `bin/rails console`
- **Check schema:** `bin/rails db:schema:dump`

## Model structure you generate

### Pattern 1: Rich model with concerns

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

  # Business logic methods
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

### Pattern 2: State record model

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

### Pattern 3: Join table model with behavior

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

### Pattern 4: Polymorphic model

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

  after_create_commit :notify_recipients
  after_create_commit :broadcast_creation

  def notify_recipients_later
    NotifyRecipientsJob.perform_later(self)
  end

  def notify_recipients
    # Business logic for who gets notified
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

### Pattern 5: PORO for complex operations

```ruby
# app/models/card/eventable/system_commenter.rb
# Use POROs for presentation logic, not business logic
class Card::Eventable::SystemCommenter
  include ERB::Util

  attr_reader :event

  def initialize(event)
    @event = event
  end

  def create_system_comment
    event.card.comments.create!(
      body: comment_body,
      creator: nil,  # System comment
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

## Association patterns

### belongs_to with defaults

```ruby
belongs_to :account, default: -> { board.account }
belongs_to :creator, class_name: "User", default: -> { Current.user }
belongs_to :board, touch: true  # Updates parent's updated_at
```

### has_many/has_one patterns

```ruby
has_many :comments, dependent: :destroy
has_many :assignments, dependent: :destroy
has_many :assignees, through: :assignments, source: :user

has_one :closure, dependent: :destroy
has_one :goldness, dependent: :destroy
has_one :publication, dependent: :destroy
```

### Polymorphic associations

```ruby
has_many :attachments, as: :attachable, dependent: :destroy
has_many :events, as: :eventable, dependent: :destroy
belongs_to :notifiable, polymorphic: true
```

### Counter caches

```ruby
belongs_to :card, counter_cache: :comments_count
belongs_to :board, counter_cache: :cards_count
```

## Scope patterns

### Basic scopes

```ruby
scope :recent, -> { order(created_at: :desc) }
scope :positioned, -> { order(:position) }
scope :active, -> { where(archived_at: nil) }
```

### Scopes with arguments

```ruby
scope :by_creator, ->(user) { where(creator: user) }
scope :in_column, ->(column) { where(column: column) }
scope :created_after, ->(date) { where("created_at > ?", date) }
```

### Scopes using joins

```ruby
scope :assigned_to, ->(user) { joins(:assignments).where(assignments: { user: user }) }
scope :watched_by, ->(user) { joins(:watches).where(watches: { user: user }) }
scope :in_board, ->(board) { where(board: board) }
```

### Scopes using where.missing

```ruby
scope :open, -> { where.missing(:closure) }
scope :unassigned, -> { where.missing(:assignments) }
scope :not_golden, -> { where.missing(:goldness) }
scope :active, -> { where.missing(:not_now) }
```

### Scopes for complex queries

```ruby
scope :with_golden_first, -> {
  left_outer_joins(:goldness)
    .select("cards.*", "goldnesses.created_at as golden_at")
    .order(Arel.sql("golden_at IS NULL, golden_at DESC"))
}

scope :entropic, -> {
  open
    .published
    .where.missing(:not_now)
    .where("updated_at < ?", 30.days.ago)
}
```

## Validation patterns

### Simple validations

```ruby
validates :title, presence: true
validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }
validates :status, inclusion: { in: %w[draft published archived] }
validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
```

### Uniqueness validations

```ruby
validates :email_address, uniqueness: { case_sensitive: false }
validates :user_id, uniqueness: { scope: :card_id }
validates :card, uniqueness: true  # For has_one relationships
```

### Conditional validations

```ruby
validates :body, presence: true, if: :published?
validates :closing_note, presence: true, if: -> { closure.present? }
```

### Custom validations

```ruby
validate :ensure_same_account

private

def ensure_same_account
  if board && board.account_id != account_id
    errors.add(:board, "must belong to the same account")
  end
end
```

## Callback patterns

### Use callbacks sparingly

```ruby
# ✅ Good: Broadcasting and tracking
after_create_commit :broadcast_creation
after_create_commit :track_created_event

# ✅ Good: Setting defaults
before_validation :set_default_status, on: :create

# ⚠️ Use with caution: Side effects
after_create_commit :notify_recipients

# ❌ Avoid: Complex business logic
# Put complex logic in explicit methods instead
```

### Callback timing

```ruby
# Before validation
before_validation :normalize_email

# After commit (for external side effects)
after_create_commit :send_notifications
after_update_commit :broadcast_update
after_destroy_commit :cleanup_related_records

# Use _commit callbacks for anything that hits external services
# Regular callbacks can rollback with the transaction
```

## Enum patterns

```ruby
# String enums (preferred for readability in database)
enum :status, {
  draft: "draft",
  published: "published",
  archived: "archived"
}, default: :draft, prefix: true

# Usage:
card.status_draft!
card.status_published?
Card.status_published
```

## Delegation patterns

```ruby
# Delegate to associations
delegate :name, to: :board, prefix: true  # board_name
delegate :email, to: :creator, prefix: :author  # author_email
delegate :can_administer_card?, to: :board, prefix: false

# Delegate with allow_nil
delegate :name, to: :board, prefix: true, allow_nil: true
```

## Query methods (not scopes)

```ruby
# Use class methods for complex queries that need arguments
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

## Business logic methods

### Action methods (verbs)

```ruby
def close(user: Current.user)
  create_closure!(user: user)
  track_event "card_closed", user: user
  notify_watchers_later
end

def assign(user)
  assignments.create!(user: user) unless assigned_to?(user)
  track_event "card_assigned", particulars: { assignee_id: user.id }
end

def move_to_column(new_column)
  update!(column: new_column, position: new_column.cards.maximum(:position).to_i + 1)
  track_event "card_moved"
end
```

### Query methods (predicates)

```ruby
def closed?
  closure.present?
end

def open?
  !closed?
end

def assigned_to?(user)
  assignees.include?(user)
end

def can_be_edited_by?(user)
  user.can_administer_card?(self) || creator == user
end
```

### Computed attributes

```ruby
def closed_at
  closure&.created_at
end

def closed_by
  closure&.user
end

def total_comments
  comments.count
end
```

## _later and _now convention

```ruby
# Async version (queues a job)
def notify_recipients_later
  NotifyRecipientsJob.perform_later(self)
end

# Sync version (immediate execution)
def notify_recipients_now
  recipients.each do |recipient|
    Notification.create!(recipient: recipient, notifiable: self)
  end
end

# Default to sync, call _later from callbacks
def notify_recipients
  notify_recipients_now
end

after_create_commit :notify_recipients_later
```

## Using Current for context

```ruby
# app/models/current.rb
class Current < ActiveSupport::CurrentAttributes
  attribute :session, :user, :identity, :account
end

# In models, use Current for request context
class Card < ApplicationRecord
  belongs_to :creator, class_name: "User", default: -> { Current.user }
  belongs_to :account, default: -> { Current.account }

  def close(user: Current.user)
    create_closure!(user: user)
  end
end
```

## Testing models

```ruby
# test/models/card_test.rb
class CardTest < ActiveSupport::TestCase
  setup do
    @card = cards(:logo)  # Use fixtures
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

## Migration patterns

### Creating models

```ruby
# bin/rails generate model Card title:string body:text account:references:uuid board:references:uuid
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

### State record migrations

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

## When NOT to use models

**Avoid models for:**
- One-off scripts (use rake tasks)
- Complex multi-step workflows (still use models, but orchestrate in controller)
- Pure view logic (use helpers or POROs in `app/models/[model]/`)

**Exception:** Form objects for signup/onboarding

```ruby
# app/models/signup.rb
class Signup
  include ActiveModel::Model

  attr_accessor :email_address, :full_name, :password

  validates :email_address, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :full_name, presence: true

  def save
    return false unless valid?

    ActiveRecord::Base.transaction do
      create_identity
      create_user
      create_account
    end
  end

  private

  def create_identity
    @identity = Identity.create!(email_address: email_address)
  end
end
```

## Boundaries

- ✅ **Always do:** Put business logic in models, use concerns for organization, include tests for all business logic, use bang methods (`create!`, `update!`) in models, leverage associations and scopes, use Current for request context, default values via lambdas
- ⚠️ **Ask first:** Before creating service objects, before adding complex callbacks, before using inheritance (prefer composition with concerns), before creating form objects
- 🚫 **Never do:** Create anemic models (just data, no behavior), put business logic in controllers, skip validations, use magic numbers (use constants or enums), create models without tests, forget `account_id` on multi-tenant models, use foreign key constraints (explicitly removed)
