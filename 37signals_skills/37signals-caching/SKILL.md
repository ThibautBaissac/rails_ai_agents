---
name: 37signals-caching
description: Implement HTTP caching with ETags, fresh_when, Russian doll caching, and fragment caching. Solid Cache for production. Triggers on caching, cache invalidation, fragment caching, ETags, stale, fresh_when.
allowed-tools: Read, Write, Edit, Bash
---

# 37signals Caching Skill

## Overview

Implement aggressive caching strategies following 37signals patterns. HTTP caching with ETags, Russian doll caching with touch: true, fragment caching in views, and Solid Cache (database-backed, no Redis).

## Core Philosophy

- **HTTP caching with ETags**: Free 304 Not Modified responses
- **Russian doll caching**: Nested fragment caches with automatic invalidation via `touch: true`
- **Fragment caching**: Cache partials with `updated_at` based keys
- **Solid Cache**: Database-backed caching, no Redis required

## Key Patterns

### Pattern 1: HTTP Caching with fresh_when

```ruby
class BoardsController < ApplicationController
  def show
    @board = Current.account.boards.find(params[:id])
    fresh_when @board  # Returns 304 if ETag matches
  end

  def index
    @boards = Current.account.boards.includes(:creator)
    fresh_when @boards  # Collection ETag
  end
end

# Composite ETag from multiple objects
def show
  fresh_when [@board, @card, Current.user]
end

# API with stale? check
def show
  if stale?(@board)
    render json: @board
  end
end
```

### Pattern 2: Russian Doll Caching

```ruby
# Set up touch: true for automatic cache invalidation
class Card < ApplicationRecord
  belongs_to :board, touch: true  # Updates board.updated_at
end

class Comment < ApplicationRecord
  belongs_to :card, touch: true  # Cascades: comment → card → board
end
```

```erb
<%# Nested fragment caches %>
<% cache @board do %>
  <h1><%= @board.name %></h1>

  <% @board.columns.each do |column| %>
    <% cache column do %>
      <h2><%= column.name %></h2>

      <% column.cards.each do |card| %>
        <% cache card do %>
          <%= render card %>
        <% end %>
      <% end %>
    <% end %>
  <% end %>
<% end %>
```

**How it works:**
```ruby
# When comment.update! happens:
# 1. comment.updated_at changes
# 2. card.updated_at touches (via touch: true)
# 3. board.updated_at touches (cascades)
# 4. All cache fragments invalidate automatically

# Cache keys look like:
# views/boards/123-20250117120000000000/...
# views/cards/456-20250117120100000000/...
```

### Pattern 3: Collection Caching

```erb
<%# Efficient collection caching %>
<% cache_collection @boards, partial: "boards/board" %>

<%# Manual version %>
<% @boards.each do |board| %>
  <% cache board do %>
    <%= render "boards/board", board: board %>
  <% end %>
<% end %>
```

### Pattern 4: Custom Cache Keys

```erb
<%# Multiple dependencies %>
<% cache ["board_header", @board, Current.user] do %>
  <%= render "header" %>
<% end %>

<%# With expiration %>
<% cache ["board_stats", @board], expires_in: 15.minutes do %>
  <%= expensive_stats_render %>
<% end %>

<%# Conditional caching %>
<% cache_unless Current.user.admin?, @board do %>
  <%= render @board %>
<% end %>
```

### Pattern 5: Low-Level Caching

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

  def expensive_calculation
    Rails.cache.fetch(
      [self, "expensive"],
      expires_in: 1.hour,
      race_condition_ttl: 10.seconds  # Prevents thundering herd
    ) do
      calculate_complex_metrics
    end
  end
end
```

### Pattern 6: Cache Invalidation

```ruby
class Board < ApplicationRecord
  after_update :clear_statistics_cache, if: :significant_change?

  def clear_statistics_cache
    Rails.cache.delete([self, "statistics"])
  end

  def refresh_cache
    clear_statistics_cache
    statistics  # Regenerate
  end
end

class Card < ApplicationRecord
  belongs_to :board, touch: true

  after_create_commit :clear_board_caches
  after_destroy_commit :clear_board_caches

  private

  def clear_board_caches
    Rails.cache.delete([board, "statistics"])
  end
end
```

### Pattern 7: Solid Cache Configuration

```ruby
# config/environments/production.rb
config.cache_store = :solid_cache_store

# config/environments/development.rb
config.cache_store = :memory_store, { size: 64.megabytes }

# config/environments/test.rb
config.cache_store = :null_store
```

### Pattern 8: Counter Caches for Performance

```ruby
class Card < ApplicationRecord
  belongs_to :board, counter_cache: true, touch: true
end

# Migration
add_column :boards, :cards_count, :integer, default: 0, null: false

# Custom cache key with counter
def cache_key_with_version
  "#{cache_key}/cards-#{cards_count}-#{updated_at.to_i}"
end
```

### Pattern 9: Cache Warming

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
```

## Quick Reference

```ruby
# HTTP Caching
fresh_when @board                    # Single resource
fresh_when @boards                   # Collection
fresh_when [@board, @card]           # Composite
if stale?(@board) { render :show }   # Conditional

# Fragment Caching
<% cache @board do %>...<% end %>
<% cache [@board, "header"] do %>...<% end %>
<% cache @board, expires_in: 15.minutes do %>...<% end %>
<% cache_collection @boards, partial: "boards/board" %>

# Low-Level Caching
Rails.cache.fetch([self, "key"]) { expensive }
Rails.cache.fetch([self, "key"], expires_in: 1.hour) { expensive }
Rails.cache.delete([self, "key"])
```

## Commands

```bash
rails solid_cache:install    # Install Solid Cache
rails db:migrate             # Run cache migrations
rails cache:clear            # Clear all caches
```

## Boundaries

### Always
- Use `fresh_when` for HTTP caching in show/index
- Use `touch: true` on associations for auto-invalidation
- Use Russian doll caching (nested fragments)
- Use Solid Cache in production (database-backed)
- Include `updated_at` in cache keys
- Use counter caches for counts
- Eager load associations to prevent N+1

### Never
- Use Redis for caching (use Solid Cache)
- Cache without considering invalidation
- Forget `touch: true` with Russian doll caching
- Cache CSRF tokens or sensitive data
- Use generic cache keys without version/timestamp
- Cache across account boundaries in multi-tenant apps
