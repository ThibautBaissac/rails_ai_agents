---
name: concern-patterns
description: >-
  Creates and refactors model and controller concerns for shared behavior.
  Use when extracting shared code, organizing models with horizontal concerns,
  DRYing up controllers, or when user mentions concerns, mixins, or modules.
  WHEN NOT: Logic used by only one model (keep in place), service object
  extraction (use model-patterns), or job organization (use job-patterns).
license: MIT
compatibility: Ruby 3.3+, Rails 8.0+
---

# Concern Patterns (37signals)

Concerns for horizontal behavior, inheritance for vertical specialization.

## Project knowledge

**Tech Stack:** Rails 8.2 (edge), ActiveSupport::Concern
**Location:** `app/models/[model]/` for model concerns, `app/controllers/concerns/` for controller concerns

**Commands:**
```bash
ls app/models/concerns/                      # List shared concerns
ls app/models/card/                          # List Card concerns
bin/rails runner "puts Card.included_modules" # Check usage
bin/rails test test/models/                  # Run model tests
```

## Core principles

Each concern should be:
- **Self-contained:** All related code (associations, validations, scopes, methods) in one place
- **Cohesive:** Focused on one aspect (e.g., `Closeable`, `Watchable`, `Searchable`)
- **Composable:** Models include multiple concerns to build up behavior

## When to extract a concern

### Extract when you see:

1. **Repeated associations across models**
   ```ruby
   # Multiple models have:
   has_many :comments, as: :commentable
   # Extract to: app/models/concerns/commentable.rb
   ```

2. **Repeated state patterns**
   ```ruby
   # Multiple models have close/reopen pattern
   # Extract to: Card::Closeable, Board::Publishable, etc.
   ```

3. **Repeated scopes**
   ```ruby
   # Multiple models have:
   scope :recent, -> { order(created_at: :desc) }
   # Extract to: Timestampable concern
   ```

4. **Repeated controller patterns**
   ```ruby
   # Multiple controllers load parent resource
   # Extract to: ParentScoped concern
   ```

### Do NOT extract when:
- Code is used by only one model (YAGNI)
- You'd create a god concern with unrelated methods
- Logic should be in explicit model methods instead

## Model concern structure

### State management concern

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
    track_event "card_closed", user: user
  end

  def reopen
    closure&.destroy!
    track_event "card_reopened"
  end

  def closed?
    closure.present?
  end

  def open?
    !closed?
  end

  def closed_at
    closure&.created_at
  end

  def closed_by
    closure&.user
  end
end
```

### Association concern

```ruby
# app/models/card/assignable.rb
module Card::Assignable
  extend ActiveSupport::Concern

  included do
    has_many :assignments, dependent: :destroy
    has_many :assignees, through: :assignments, source: :assignee

    scope :assigned_to, ->(users) { joins(:assignments).where(assignments: { assignee: users }).distinct }
    scope :unassigned, -> { where.missing(:assignments) }
  end

  def assign(user)
    assignments.create!(user: user) unless assigned_to?(user)
    track_event "card_assigned", user: user, particulars: { assignee_id: user.id }
  end

  def unassign(user)
    assignments.where(user: user).destroy_all
  end

  def assigned_to?(user)
    assignees.include?(user)
  end
end
```

### Behavior concern with class methods

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

    def top_results(query, limit: 10)
      search_with_ranking(query).limit(limit)
    end
  end
end
```

## Controller concern structure

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
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          dom_id(@card, :card_container),
          partial: "cards/container",
          locals: { card: @card.reload }
        )
      end
      format.html { redirect_to @card }
    end
  end
end
```

## Naming conventions

- **Model concerns** (adjectives): `Closeable`, `Publishable`, `Watchable`, `Assignable`, `Searchable`, `Eventable`, `Broadcastable`, `Readable`, `Positionable`
- **Controller concerns** (nouns): `CardScoped`, `BoardScoped`, `FilterScoped`, `CurrentRequest`, `CurrentTimezone`, `Authentication`

## Testing concerns

### Test in isolation:

```ruby
# test/models/concerns/closeable_test.rb
class CloseableTest < ActiveSupport::TestCase
  setup do
    @card = cards(:logo)
  end

  test "close creates closure record" do
    assert_difference -> { Closure.count }, 1 do
      @card.close
    end
    assert @card.closed?
  end

  test "reopen destroys closure record" do
    @card.close
    assert_difference -> { Closure.count }, -1 do
      @card.reopen
    end
    assert @card.open?
  end

  test "closed scope finds closed records" do
    @card.close
    assert_includes Card.closed, @card
    refute_includes Card.open, @card
  end
end
```

## Refactoring workflow

1. **Identify the pattern** -- Find duplicated code across models/controllers
2. **Name the concern** -- Use an adjective describing the capability
3. **Create the file** -- `app/models/[model]/[concern].rb` or `app/controllers/concerns/[concern].rb`
4. **Move code** -- Associations, validations, scopes, methods
5. **Include it** -- Add `include ConcernName` to models/controllers
6. **Write tests** -- Test concern in isolation and in context
7. **Remove duplication** -- Delete the old code from models/controllers

## Files to create

1. **Concern file:** `app/models/card/closeable.rb` or `app/controllers/concerns/card_scoped.rb`
2. **Model/Controller:** Add `include ConcernName`
3. **Test file:** `test/models/concerns/closeable_test.rb`

See `references/concern-catalog.md` for the full catalog of concern types.

## Boundaries

- **Always:** Extract repeated code into concerns, keep concerns focused on one aspect, include all related code (associations, scopes, methods), write tests, use `extend ActiveSupport::Concern`, namespace model concerns under the model
- **Ask first:** Before creating concerns that span multiple domains, before extracting concerns with complex dependencies, before modifying widely-used concerns
- **Never:** Create god concerns with too many responsibilities, use concerns to hide service objects, skip `included do` block for callbacks/associations, create concerns for one-off code
