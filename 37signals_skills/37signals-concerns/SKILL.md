---
name: 37signals-concerns
description: Extract and organize model and controller concerns for horizontal code sharing. Triggers on concerns, modules, mixins, shared behavior, code extraction, DRY.
allowed-tools: Read, Write, Edit, Bash
---

# 37signals Concerns Skill

## Overview

Extract repeated patterns across models or controllers into concerns. Each concern is self-contained with all related code (associations, validations, scopes, methods) in one place.

## Core Philosophy

- **Concerns for horizontal behavior**: When multiple models need the same behavior
- **Self-contained**: All related code in one concern
- **Cohesive**: Focused on one aspect (Closeable, Watchable, Searchable)
- **Composable**: Models include multiple concerns to build behavior

## Model Concern Structure

### Pattern 1: State Management Concern

```ruby
# app/models/card/closeable.rb
module Card::Closeable
  extend ActiveSupport::Concern

  included do
    has_one :closure, dependent: :destroy

    scope :open, -> { where.missing(:closure) }
    scope :closed, -> { joins(:closure) }
  end

  def close(user: Current.user)
    create_closure!(user: user)
  end

  def reopen
    closure&.destroy!
  end

  def closed?
    closure.present?
  end

  def open?
    !closed?
  end
end
```

### Pattern 2: Association Concern

```ruby
# app/models/card/assignable.rb
module Card::Assignable
  extend ActiveSupport::Concern

  included do
    has_many :assignments, dependent: :destroy
    has_many :assignees, through: :assignments, source: :user

    scope :assigned_to, ->(user) { joins(:assignments).where(assignments: { user: user }) }
    scope :unassigned, -> { where.missing(:assignments) }
  end

  def assign(user)
    assignments.create!(user: user) unless assigned_to?(user)
  end

  def unassign(user)
    assignments.where(user: user).destroy_all
  end

  def assigned_to?(user)
    assignees.include?(user)
  end
end
```

### Pattern 3: Behavior Concern

```ruby
# app/models/card/searchable.rb
module Card::Searchable
  extend ActiveSupport::Concern

  included do
    scope :search, ->(query) { where("title LIKE ? OR body LIKE ?", "%#{query}%", "%#{query}%") }
  end

  class_methods do
    def search_with_ranking(query)
      search(query).order("search_rank DESC")
    end
  end
end
```

## Controller Concern Structure

### Pattern 1: Resource Scoping

```ruby
# app/controllers/concerns/card_scoped.rb
module CardScoped
  extend ActiveSupport::Concern

  included do
    before_action :set_card
    before_action :set_board
  end

  private

  def set_card
    @card = Current.account.cards.find(params[:card_id])
  end

  def set_board
    @board = @card.board
  end

  def render_card_replacement
    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.replace(dom_id(@card), partial: "cards/card") }
      format.html { redirect_to @card }
    end
  end
end
```

### Pattern 2: Request Context

```ruby
# app/controllers/concerns/current_request.rb
module CurrentRequest
  extend ActiveSupport::Concern

  included do
    before_action :set_current_request_details
  end

  private

  def set_current_request_details
    Current.user = current_user
    Current.account = current_account
  end
end
```

## Concern Composition

Models include multiple concerns:

```ruby
class Card < ApplicationRecord
  include Assignable
  include Closeable
  include Commentable
  include Eventable
  include Positionable
  include Searchable
  include Watchable

  # Minimal model code - behavior is in concerns
  belongs_to :board
  validates :title, presence: true
end
```

## When to Extract

Extract when you see:

1. **Repeated associations**
   ```ruby
   # Multiple models have:
   has_many :comments, as: :commentable
   # → Extract to Commentable concern
   ```

2. **Repeated state patterns**
   ```ruby
   has_one :closure
   def close; end
   def closed?; end
   # → Extract to Closeable concern
   ```

3. **Repeated scopes**
   ```ruby
   scope :recent, -> { order(created_at: :desc) }
   # → Extract to Timestampable concern
   ```

## Naming Conventions

### Model concerns (adjectives):
- `Closeable` - can be closed
- `Publishable` - can be published
- `Watchable` - can be watched
- `Assignable` - can be assigned
- `Searchable` - can be searched
- `Positionable` - has position

### Controller concerns (nouns/descriptive):
- `CardScoped` - scopes to card
- `FilterScoped` - handles filtering
- `Authentication` - handles auth

## Testing Concerns

```ruby
# test/models/concerns/closeable_test.rb
class CloseableTest < ActiveSupport::TestCase
  class DummyCloseable < ApplicationRecord
    self.table_name = "cards"
    include Card::Closeable
  end

  test "close creates closure record" do
    record = DummyCloseable.create!(title: "Test")

    assert_difference -> { Closure.count }, 1 do
      record.close
    end

    assert record.closed?
  end

  test "reopen destroys closure" do
    record = DummyCloseable.create!(title: "Test")
    record.close
    record.reopen

    assert record.open?
  end
end
```

## File Locations

- Model concerns: `app/models/[model]/[concern].rb` or `app/models/concerns/[concern].rb`
- Controller concerns: `app/controllers/concerns/[concern].rb`

## Commands

```bash
ls app/models/concerns/                    # List concerns
bin/rails runner "puts Card.included_modules"  # Check included modules
grep -r "def close" app/models/            # Find duplicated code
```

## Boundaries

### Always
- Extract repeated code into concerns
- Keep concerns focused on one aspect
- Include all related code (associations, scopes, methods)
- Use `extend ActiveSupport::Concern`
- Namespace model concerns under the model
- Write tests for concerns

### Never
- Create god concerns with too many responsibilities
- Use concerns to hide service objects
- Skip the `included do` block for callbacks/associations
- Create concerns for one-off code
- Forget to test concerns in isolation
