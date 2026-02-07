---
name: 37signals-model
description: Build rich domain models with business logic, concerns, and proper associations. No service objects. Triggers on model, ActiveRecord, associations, validations, scopes, domain logic.
allowed-tools: Read, Write, Edit, Bash
---

# 37signals Model Skill

## Overview

Build fat models with business logic, not anemic data containers. Domain logic lives in models, not service objects. Use concerns for horizontal behavior sharing.

## Core Philosophy

- **Rich models over service objects**: Business logic belongs in models
- **Concerns for composition**: Shared behavior across models
- **_later/_now convention**: Async/sync method pairs
- **Current for context**: Use Current.user, Current.account

## Key Patterns

### Pattern 1: Rich Model with Concerns

```ruby
class Card < ApplicationRecord
  include Assignable, Closeable, Commentable, Eventable, Watchable

  belongs_to :account, default: -> { Current.account }
  belongs_to :board, touch: true
  belongs_to :creator, class_name: "User", default: -> { Current.user }

  has_many :comments, dependent: :destroy
  has_many :assignments, dependent: :destroy

  validates :title, presence: true
  enum :status, { draft: "draft", published: "published" }, default: :draft

  scope :recent, -> { order(created_at: :desc) }
  scope :active, -> { open.published }

  def publish
    update!(status: :published)
    track_event "card_published"
  end

  def move_to_column(new_column)
    update!(column: new_column)
    track_event "card_moved"
  end
end
```

### Pattern 2: Associations with Defaults

```ruby
belongs_to :account, default: -> { Current.account }
belongs_to :creator, class_name: "User", default: -> { Current.user }
belongs_to :board, touch: true  # Updates parent's updated_at

has_many :comments, dependent: :destroy
has_many :assignments, dependent: :destroy
has_many :assignees, through: :assignments, source: :user

has_one :closure, dependent: :destroy
```

### Pattern 3: Scopes

```ruby
# Basic scopes
scope :recent, -> { order(created_at: :desc) }
scope :positioned, -> { order(:position) }

# With arguments
scope :by_creator, ->(user) { where(creator: user) }
scope :in_column, ->(column) { where(column: column) }

# Using joins
scope :assigned_to, ->(user) { joins(:assignments).where(assignments: { user: user }) }

# Using where.missing (Rails 6.1+)
scope :open, -> { where.missing(:closure) }
scope :unassigned, -> { where.missing(:assignments) }
```

### Pattern 4: Action Methods

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
```

### Pattern 5: Predicate Methods

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
  user.admin? || creator == user
end
```

### Pattern 6: _later/_now Convention

```ruby
def notify_recipients_later
  NotifyRecipientsJob.perform_later(self)
end

def notify_recipients_now
  recipients.each do |recipient|
    Notification.create!(recipient: recipient, notifiable: self)
  end
end

# Default to sync in model, async in callback
def notify_recipients
  notify_recipients_now
end

after_create_commit :notify_recipients_later
```

### Pattern 7: State Record Model

```ruby
class Closure < ApplicationRecord
  belongs_to :account, default: -> { card.account }
  belongs_to :card, touch: true
  belongs_to :user, optional: true

  validates :card, uniqueness: true

  after_create_commit :notify_watchers
end
```

### Pattern 8: Join Table with Behavior

```ruby
class Assignment < ApplicationRecord
  belongs_to :account, default: -> { card.account }
  belongs_to :card, touch: true
  belongs_to :user

  validates :user_id, uniqueness: { scope: :card_id }

  after_create_commit :track_assignment
  after_create_commit :notify_assignee

  private

  def track_assignment
    card.track_event "card_assigned", particulars: { assignee_id: user.id }
  end

  def notify_assignee
    AssignmentMailer.assigned(self).deliver_later
  end
end
```

## Callbacks (Use Sparingly)

```ruby
# Good: Broadcasting and tracking
after_create_commit :broadcast_creation
after_update_commit :track_changes

# Good: Setting defaults
before_validation :set_default_status, on: :create

# Use _commit for external effects
after_create_commit :notify_recipients_later  # Not after_create
```

## Testing

```ruby
class CardTest < ActiveSupport::TestCase
  setup do
    @card = cards(:one)
    Current.user = users(:alice)
    Current.account = @card.account
  end

  test "closing card creates closure" do
    assert_difference -> { Closure.count }, 1 do
      @card.close
    end

    assert @card.closed?
  end

  test "open scope excludes closed cards" do
    @card.close
    assert_not_includes Card.open, @card
  end

  test "validates title presence" do
    card = Card.new(board: boards(:one))
    assert_not card.valid?
    assert_includes card.errors[:title], "can't be blank"
  end
end
```

## Commands

```bash
bin/rails generate model Card title:string body:text account:references
bin/rails test test/models/
bin/rails console
```

## Boundaries

### Always
- Put business logic in models
- Use concerns for shared behavior
- Use `bang methods` (`create!`, `update!`) in models
- Leverage associations and scopes
- Use Current for request context
- Default values via lambdas

### Never
- Create service objects for business logic
- Put domain logic in controllers
- Use magic numbers (use enums)
- Create models without tests
- Skip account_id on multi-tenant models
