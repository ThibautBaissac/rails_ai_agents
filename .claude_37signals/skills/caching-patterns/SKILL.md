---
name: caching-patterns
description: >-
  Implements HTTP caching with ETags, fragment caching, Russian doll caching,
  and Solid Cache configuration. Use when optimizing performance, adding caching
  layers, or when user mentions ETags, fresh_when, stale?, cache keys, or
  Russian doll caching.
  WHEN NOT: For Turbo Stream real-time updates (use turbo-patterns), for
  background job cache warming logic (use job-patterns).
license: MIT
compatibility: Ruby 3.3+, Rails 8.0+, Solid Cache
---

# Caching Patterns

## Philosophy: Cache Aggressively, Invalidate Precisely

- HTTP caching with ETags and `fresh_when` for free 304 Not Modified responses
- Russian doll caching with `touch: true` for automatic cache invalidation
- Fragment caching in views with cache keys based on `updated_at` timestamps
- Solid Cache (database-backed, no Redis) for production caching
- Collection caching with `cache_collection` for lists
- Low-level caching with `Rails.cache.fetch` for expensive computations

## Project Knowledge

**Stack:** Solid Cache (database-backed), Turbo for page refreshes, ETags with
conditional GET, fragment caching in ERB views, collection caching for lists.

**Multi-tenancy:** Cache keys scoped to account. URL-based:
`app.myapp.com/123/projects/456`.

**Commands:**
```bash
rails solid_cache:install        # Install Solid Cache
rails db:migrate                 # Run cache migrations
rails cache:clear                # Clear cache
```

## Caching Strategy Hierarchy

Apply caching in this order (highest impact first):

1. **HTTP caching** -- `fresh_when` / `stale?` in controllers (free 304s)
2. **Fragment caching** -- `cache` blocks in views (Russian doll)
3. **Collection caching** -- `cache_collection` for lists of partials
4. **Low-level caching** -- `Rails.cache.fetch` for expensive computations

## Pattern 1: HTTP Caching with ETags

See @references/http-caching.md for full details.

```ruby
# Single resource -- returns 304 if ETag matches
class BoardsController < ApplicationController
  def show
    @board = Current.account.boards.find(params[:id])
    fresh_when @board
  end

  def index
    @boards = Current.account.boards.includes(:creator)
    fresh_when @boards
  end
end

# Composite ETag from multiple objects
def show
  fresh_when [@board, @card, Current.user]
end

# API with stale? for conditional rendering
def show
  @board = Current.account.boards.find(params[:id])
  if stale?(@board)
    render json: @board
  end
end

# Custom ETag with parameters
fresh_when etag: [@activities, @report_date, Current.user.timezone]
```

## Pattern 2: Russian Doll Caching

See @references/fragment-caching.md for full details.

Set up touch cascades in models:

```ruby
class Card < ApplicationRecord
  belongs_to :board, touch: true
end

class Comment < ApplicationRecord
  belongs_to :card, touch: true
  # Updating comment touches card -> touches board -> invalidates all caches
end
```

Nest cache blocks in views:

```erb
<% cache @board do %>
  <h1><%= @board.name %></h1>
  <% @board.columns.each do |column| %>
    <% cache column do %>
      <% column.cards.each do |card| %>
        <% cache card do %>
          <%= render card %>
        <% end %>
      <% end %>
    <% end %>
  <% end %>
<% end %>
```

## Pattern 3: Collection Caching

```erb
<%# Cache each item individually with multi-fetch optimization %>
<% cache_collection @boards, partial: "boards/board" %>

<%# Manual alternative %>
<% @boards.each do |board| %>
  <% cache board do %>
    <%= render "boards/board", board: board %>
  <% end %>
<% end %>
```

Use counter caches to avoid N+1 in cache keys:

```ruby
class Card < ApplicationRecord
  belongs_to :board, counter_cache: true, touch: true
end

class Board < ApplicationRecord
  def cache_key_with_version
    "#{cache_key}/cards-#{cards_count}-#{updated_at.to_i}"
  end
end
```

## Pattern 4: Fragment Caching with Custom Keys

```erb
<%# Multiple dependencies %>
<% cache ["board_header", @board, Current.user] do %>
  <h1><%= @board.name %></h1>
  <% if Current.user.can_edit?(@board) %>
    <%= link_to "Edit", edit_board_path(@board) %>
  <% end %>
<% end %>

<%# With expiration %>
<% cache ["board_stats", @board], expires_in: 15.minutes do %>
  <div class="stats"><%= @board.cards.count %> cards</div>
<% end %>

<%# Conditional caching %>
<% cache_if @enable_caching, board do %>
  <%= board.name %>
<% end %>

<%# Multi-key with locale %>
<% cache ["dashboard", Current.account, Current.user,
          @boards.maximum(:updated_at), I18n.locale] do %>
  <%= render "boards_summary", boards: @boards %>
<% end %>
```

## Pattern 5: Low-Level Caching

```ruby
class Board < ApplicationRecord
  def statistics
    Rails.cache.fetch([self, "statistics"], expires_in: 1.hour) do
      {
        total_cards: cards.count,
        completed_cards: cards.joins(:closure).count,
        total_comments: cards.joins(:comments).count
      }
    end
  end

  # Race condition protection for expensive operations
  def expensive_calculation
    Rails.cache.fetch(
      [self, "expensive_calculation"],
      expires_in: 1.hour,
      race_condition_ttl: 10.seconds
    ) { calculate_complex_metrics }
  end

  # Version-based cache busting
  STATS_VERSION = 2
  def versioned_statistics
    Rails.cache.fetch([self, "statistics", "v#{STATS_VERSION}"],
                      expires_in: 1.hour) { calculate_statistics }
  end
end
```

## Pattern 6: Cache Invalidation

See @references/cache-invalidation.md for full details.

```ruby
# Prefer touch: true cascades (automatic)
belongs_to :board, touch: true

# Manual invalidation for low-level caches
class Card < ApplicationRecord
  after_create_commit :clear_board_caches
  after_destroy_commit :clear_board_caches

  private

  def clear_board_caches
    Rails.cache.delete([board, "statistics"])
    Rails.cache.delete([board, "card_distribution"])
  end
end

# Sweeper pattern for batch invalidation
class CacheSweeper
  def self.clear_board_caches(board)
    Rails.cache.delete([board, "statistics"])
    Rails.cache.delete([board, "card_distribution"])
    Rails.cache.delete([board, "activity_summary", Date.current])
  end
end
```

## Pattern 7: Solid Cache Configuration

```ruby
# config/environments/production.rb
config.cache_store = :solid_cache_store

# config/environments/development.rb
config.cache_store = :memory_store, { size: 64.megabytes }

# config/environments/test.rb
config.cache_store = :null_store
```

## Pattern 8: Cache Warming

```ruby
class CacheWarmerJob < ApplicationJob
  queue_as :low_priority

  def perform(account)
    account.boards.find_each do |board|
      board.statistics
      board.card_distribution
    end
  end
end

# config/recurring.yml
cache:
  daily_refresh:
    class: DailyCacheRefreshJob
    schedule: every day at 3am
    queue: low_priority
```

## Boundaries

### Always
- Use `fresh_when` for index and show actions
- Use `touch: true` on associations for automatic invalidation
- Use Solid Cache in production (database-backed, no Redis)
- Include `expires_in` for time-based data
- Scope cache keys to account in multi-tenant apps
- Use counter caches for counts
- Eager load associations to prevent N+1 queries

### Ask First
- Whether to cache user-specific content
- Cache expiration times (freshness vs performance)
- Whether to warm caches in background jobs

### Never
- Use Redis for caching (use Solid Cache)
- Cache without considering invalidation strategy
- Forget `touch: true` with Russian doll caching
- Cache CSRF tokens or sensitive user data
- Use generic cache keys without version/timestamp
- Cache in test environment (use `:null_store`)
- Cache across account boundaries in multi-tenant apps
