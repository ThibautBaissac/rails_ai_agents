---
name: state-records
description: >-
  Implements the state-as-records-not-booleans pattern for rich state tracking.
  Use when modeling state changes, replacing boolean flags with record-based
  state, or when user mentions state records, closures, publications, or
  toggling state. WHEN NOT: Technical flags like cached/processed (use booleans),
  concern extraction (use concern-patterns), general model work (use model-patterns).
license: MIT
compatibility: Ruby 3.3+, Rails 8.0+
---

# State Records (37signals)

State as records, not booleans. Instead of `closed: boolean`, create a `Closure` record.

## Project knowledge

**Tech Stack:** Rails 8.2 (edge), UUIDs everywhere, ActiveRecord associations
**Pattern:** One state model per boolean you'd normally add
**Naming:** Noun forms (Closure, Publication, Goldness, NotNow, Archival)

**Commands:**
```bash
bin/rails generate model Closure card:references:uuid user:references:uuid account:references:uuid
bin/rails db:migrate
bin/rails console                              # Test: Card.open.count
bin/rails test test/models/
```

## Why state records over booleans

Boolean columns give you:
- Current state (open/closed)

State records give you:
- Current state (`closure.present?`)
- When it changed (`closure.created_at`)
- Who changed it (`closure.user`)
- Why it changed (`closure.reason`)
- Change history (via events)

## The pattern

### Boolean approach (avoid for business state):
```ruby
# BAD
class Card < ApplicationRecord
  def close
    update!(closed: true, closed_at: Time.current)
  end

  scope :open, -> { where(closed: false) }
end
```

### State record approach:
```ruby
# GOOD
class Closure < ApplicationRecord
  # touch: true ensures the parent's updated_at changes when state changes,
  # which drives cache invalidation (Russian doll caching, ETags, etc.)
  belongs_to :card, touch: true
  belongs_to :user, optional: true
  belongs_to :account, default: -> { card.account }

  validates :card, uniqueness: true
end

class Card < ApplicationRecord
  has_one :closure, dependent: :destroy

  def close(user: Current.user)
    create_closure!(user: user)
  end

  def reopen
    closure&.destroy!
  end

  def closed?
    closure.present?
  end

  scope :open, -> { where.missing(:closure) }
  scope :closed, -> { joins(:closure) }
end
```

## State record model template

Every state record model follows this structure:

```ruby
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

## State concern template

Every state concern follows this structure:

```ruby
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

## State record with metadata

When state needs additional data (secure tokens, descriptions):

```ruby
class Board::Publication < ApplicationRecord
  belongs_to :account, default: -> { board.account }
  belongs_to :board, touch: true

  has_secure_token :key

  validates :board, uniqueness: true

  def public_url
    Rails.application.routes.url_helpers.public_board_url(key)
  end
end

module Board::Publishable
  extend ActiveSupport::Concern

  included do
    has_one :publication, dependent: :destroy

    scope :published, -> { joins(:publication) }
    scope :private, -> { where.missing(:publication) }
  end

  def publish(description: nil)
    create_publication!(description: description)
    track_event "board_published"
  end

  def unpublish
    publication&.destroy!
    track_event "board_unpublished"
  end

  def published?
    publication.present?
  end

  def public_url
    publication&.public_url
  end
end
```

## Query patterns with state records

```ruby
# Finding by state: positive uses joins, negative uses where.missing
Card.open                    # where.missing(:closure)
Card.closed                  # joins(:closure)
Board.published              # joins(:publication)
Card.golden                  # joins(:goldness)

# Complex combinations
scope :actionable, -> {
  where.missing(:closure).where.missing(:not_now).where.missing(:archival)
}

# Sorting by state
scope :with_golden_first, -> {
  left_outer_joins(:goldness)
    .select("cards.*", "card_goldnesses.created_at as golden_at")
    .order(Arel.sql("golden_at IS NULL, golden_at DESC"))
}

# Filtering by actor
scope :closed_by, ->(user) { joins(:closure).where(closures: { user: user }) }
```

## Controller patterns

State changes map to singular resources with create/destroy:

```ruby
# config/routes.rb
resources :cards do
  resource :closure, only: [:create, :destroy], module: :cards
  resource :goldness, only: [:create, :destroy], module: :cards
  resource :not_now, only: [:create, :destroy], module: :cards
end

# app/controllers/cards/closures_controller.rb
class Cards::ClosuresController < ApplicationController
  include CardScoped

  def create
    @card.close(user: Current.user)
    render_card_replacement
  end

  def destroy
    @card.reopen
    render_card_replacement
  end
end
```

## View patterns

```erb
<%# Toggle button %>
<%= button_to card_goldness_path(card),
    method: card.golden? ? :delete : :post,
    data: { turbo_frame: dom_id(card) } do %>
  <%= card.golden? ? "Ungild" : "Gild" %>
<% end %>

<%# State badge %>
<% if card.closed? %>
  <span class="badge badge--closed">
    Closed <%= time_ago_in_words(card.closed_at) %> ago
    <% if card.closed_by %>by <%= card.closed_by.name %><% end %>
  </span>
<% end %>
```

## When to use state records vs booleans

### Use state records when:
- You need to know when state changed
- You need to know who changed it
- You might store metadata (reason, notes)
- State changes are important business events
- You need queries like "recently closed" or "closed by X"

### Use booleans when:
- State is purely technical (cached, processed)
- Timestamp/actor don't matter
- Performance is critical (millions of rows, frequent updates)
- State changes are not business events

### Quick reference:
- **State records:** closed, published, archived, suspended, verified, pinned, golden, postponed
- **Booleans:** admin, cached, processed, visible

See `references/state-record-examples.md` for complete examples of each state type.

## Migration from boolean to state record

1. Create state record model + migration
2. Backfill existing data
3. Update model code to use concern
4. Remove boolean column (after verification)

## Boundaries

- **Always:** Create state record for business-meaningful states, track who and when, use `where.missing` for negative scopes, add unique index on parent_id, touch parent record, write tests for state transitions
- **Ask first:** Before using boolean columns for business state, before adding complex metadata (might need separate model)
- **Never:** Use booleans for important business state, skip who/when tracking, create multiple state records per parent (use `has_one` with unique index), skip event tracking for state changes
