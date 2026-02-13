---
name: caching-strategies
description: Implements Rails caching patterns for performance optimization. Use when adding fragment caching, Russian doll caching, low-level caching, cache invalidation, or when user mentions caching, performance, cache keys, or memoization.
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# Caching Strategies for Rails 8

## Overview

Rails provides multiple caching layers:
- **Fragment caching**: Cache view partials
- **Russian doll caching**: Nested cache fragments
- **Low-level caching**: Cache arbitrary data
- **HTTP caching**: Browser and CDN caching
- **Query caching**: Automatic within requests

**⚠️ IMPORTANT - Cache Invalidation Philosophy:**

This skill shows the **standard Rails pattern** using `after_commit` callbacks for cache invalidation.

However, **37signals philosophy** recommends:
- ❌ NO callbacks for cache invalidation - it's a side effect
- ✅ Invalidate caches explicitly from controllers after successful save
- Helper methods in models, called from controllers

Choose based on your project's philosophy.

## Quick Start

```ruby
# config/environments/development.rb
config.action_controller.perform_caching = true
config.cache_store = :memory_store

# config/environments/production.rb
config.cache_store = :solid_cache_store  # Rails 8 default
# OR
config.cache_store = :redis_cache_store, { url: ENV["REDIS_URL"] }
```

Enable caching in development:
```bash
bin/rails dev:cache
```

## Cache Store Options

| Store | Use Case | Pros | Cons |
|-------|----------|------|------|
| `:memory_store` | Development | Fast, no setup | Not shared, limited size |
| `:solid_cache_store` | Production (Rails 8) | Database-backed, no Redis | Slightly slower |
| `:redis_cache_store` | Production | Fast, shared | Requires Redis |
| `:file_store` | Simple production | Persistent, no Redis | Slow, not shared |
| `:null_store` | Testing | No caching | N/A |

## Fragment Caching

### Basic Fragment Cache

```erb
<%# app/views/events/_event.html.erb %>
<% cache event do %>
  <article class="event-card">
    <h3><%= event.name %></h3>
    <p><%= event.description %></p>
    <time><%= l(event.event_date, format: :long) %></time>
    <%= render event.venue %>
  </article>
<% end %>
```

### Cache Key Components

Rails generates cache keys from:
- Model name
- Model ID
- `updated_at` timestamp
- Template digest (automatic)

```ruby
# Generated key example:
# views/events/123-20240115120000000000/abc123digest
```

### Custom Cache Keys

```erb
<%# With version %>
<% cache [event, "v2"] do %>
  ...
<% end %>

<%# With user-specific content %>
<% cache [event, current_user] do %>
  ...
<% end %>

<%# With explicit key %>
<% cache "featured-events-#{Date.current}" do %>
  <%= render @featured_events %>
<% end %>
```

## Russian Doll Caching

Nested caches where inner caches are reused when outer cache is invalidated:

```erb
<%# app/views/events/show.html.erb %>
<% cache @event do %>
  <h1><%= @event.name %></h1>

  <section class="vendors">
    <% @event.vendors.each do |vendor| %>
      <% cache vendor do %>
        <%= render partial: "vendors/card", locals: { vendor: vendor } %>
      <% end %>
    <% end %>
  </section>

  <section class="comments">
    <% @event.comments.each do |comment| %>
      <% cache comment do %>
        <%= render comment %>
      <% end %>
    <% end %>
  </section>
<% end %>
```

### Touch for Cascade Invalidation

```ruby
# app/models/comment.rb
class Comment < ApplicationRecord
  belongs_to :event, touch: true  # Updates event.updated_at when comment changes
end

# app/models/event_vendor.rb
class EventVendor < ApplicationRecord
  belongs_to :event, touch: true
  belongs_to :vendor
end
```

## Collection Caching

### Efficient Collection Rendering

```erb
<%# Caches each item individually %>
<%= render partial: "events/event", collection: @events, cached: true %>

<%# Equivalent to: %>
<% @events.each do |event| %>
  <% cache event do %>
    <%= render event %>
  <% end %>
<% end %>
```

### With Custom Cache Key

```erb
<%= render partial: "events/event",
           collection: @events,
           cached: ->(event) { [event, current_user.admin?] } %>
```

## Low-Level Caching

### Basic Read/Write

```ruby
# Read with block (fetch)
Rails.cache.fetch("stats/#{Date.current}", expires_in: 1.hour) do
  # Expensive calculation
  {
    total_events: Event.count,
    total_revenue: Order.sum(:total_cents)
  }
end

# Just read (returns nil if missing)
stats = Rails.cache.read("stats/#{Date.current}")

# Just write
Rails.cache.write("stats/#{Date.current}", stats, expires_in: 1.hour)

# Delete
Rails.cache.delete("stats/#{Date.current}")
```

### In Service Objects

```ruby
# app/services/dashboard_stats_service.rb
class DashboardStatsService
  CACHE_KEY = "dashboard_stats"
  CACHE_TTL = 15.minutes

  def call(account:)
    Rails.cache.fetch(cache_key(account), expires_in: CACHE_TTL) do
      calculate_stats(account)
    end
  end

  def invalidate(account:)
    Rails.cache.delete(cache_key(account))
  end

  private

  def cache_key(account)
    "#{CACHE_KEY}/#{account.id}"
  end

  def calculate_stats(account)
    {
      events_count: account.events.count,
      upcoming_events: account.events.upcoming.count,
      total_revenue: calculate_revenue(account)
    }
  end
end
```

### In Query Objects

```ruby
# app/queries/dashboard_stats_query.rb
class DashboardStatsQuery
  def initialize(account:, use_cache: true)
    @account = account
    @use_cache = use_cache
  end

  def upcoming_events(limit: 5)
    return fetch_upcoming_events(limit) unless @use_cache

    Rails.cache.fetch(cache_key("upcoming", limit), expires_in: 5.minutes) do
      fetch_upcoming_events(limit)
    end
  end

  private

  def cache_key(type, *args)
    "dashboard/#{@account.id}/#{type}/#{args.join('-')}"
  end

  def fetch_upcoming_events(limit)
    @account.events.upcoming.limit(limit).to_a
  end
end
```

## Cache Invalidation

### Time-Based Expiration

```ruby
Rails.cache.fetch("key", expires_in: 1.hour) { ... }
```

### Key-Based Expiration

```ruby
# Cache key includes timestamp, auto-expires when model changes
cache_key = "event/#{event.id}-#{event.updated_at.to_i}"
Rails.cache.fetch(cache_key) { ... }
```

### Manual Invalidation

```ruby
# In model callback
class Event < ApplicationRecord
  after_commit :invalidate_caches

  private

  def invalidate_caches
    Rails.cache.delete("featured_events")
    Rails.cache.delete_matched("dashboard/#{account_id}/*")
  end
end

# In service
class Events::UpdateService
  def call(event, params)
    event.update!(params)
    invalidate_related_caches(event)
    success(event)
  end

  private

  def invalidate_related_caches(event)
    Rails.cache.delete("event_count/#{event.account_id}")
    DashboardStatsService.new.invalidate(account: event.account)
  end
end
```

### Pattern-Based Deletion

```ruby
# Delete all keys matching pattern (Redis only)
Rails.cache.delete_matched("dashboard/*")

# For Solid Cache / Memory Store, use namespaced keys
Rails.cache.delete("dashboard/#{account_id}/stats")
Rails.cache.delete("dashboard/#{account_id}/events")
```

## HTTP Caching

### Conditional GET (ETag/Last-Modified)

```ruby
class EventsController < ApplicationController
  def show
    @event = Event.find(params[:id])

    # Returns 304 Not Modified if unchanged
    if stale?(@event)
      respond_to do |format|
        format.html
        format.json { render json: @event }
      end
    end
  end

  def index
    @events = current_account.events.recent

    # With custom ETag
    if stale?(etag: @events, last_modified: @events.maximum(:updated_at))
      render :index
    end
  end
end
```

### Cache-Control Headers

```ruby
class Api::EventsController < Api::BaseController
  def show
    @event = Event.find(params[:id])

    # Public caching (CDN can cache)
    expires_in 1.hour, public: true

    # Private caching (browser only)
    expires_in 15.minutes, private: true

    render json: @event
  end
end
```

## Memoization

### Instance Variable Memoization

```ruby
class EventPresenter < BasePresenter
  def vendor_count
    @vendor_count ||= event.vendors.count
  end

  def total_cost
    @total_cost ||= calculate_total_cost
  end

  private

  def calculate_total_cost
    event.event_vendors.sum(:amount_cents)
  end
end
```

### Request-Scoped Memoization

```ruby
class Current < ActiveSupport::CurrentAttributes
  attribute :dashboard_stats

  def dashboard_stats
    super || self.dashboard_stats = DashboardStatsQuery.new(user: user).call
  end
end
```

## Counter Caching

### Built-in Counter Cache

```ruby
# Migration
add_column :events, :vendors_count, :integer, default: 0, null: false

# Model
class Vendor < ApplicationRecord
  belongs_to :event, counter_cache: true
end

# Usage (no query needed)
event.vendors_count
```

### Custom Counter Cache

```ruby
class Event < ApplicationRecord
  after_commit :update_account_counters

  private

  def update_account_counters
    account.update_columns(
      events_count: account.events.count,
      active_events_count: account.events.active.count
    )
  end
end
```

## Testing Caching

### Spec Configuration

```ruby
# spec/rails_helper.rb
RSpec.configure do |config|
  config.around(:each, :caching) do |example|
    caching = ActionController::Base.perform_caching
    ActionController::Base.perform_caching = true
    Rails.cache.clear
    example.run
    ActionController::Base.perform_caching = caching
  end
end
```

### Testing Cached Views

```ruby
RSpec.describe "Events", type: :request, :caching do
  it "caches the event show page" do
    event = create(:event)

    # First request - cache miss
    get event_path(event)
    expect(response.body).to include(event.name)

    # Update event
    event.update!(name: "New Name")

    # Second request - should show new name (cache invalidated)
    get event_path(event)
    expect(response.body).to include("New Name")
  end
end
```

### Testing Cache Invalidation

```ruby
RSpec.describe DashboardStatsService do
  describe "#invalidate" do
    it "clears the cache" do
      account = create(:account)
      service = described_class.new

      # Prime cache
      service.call(account: account)

      # Invalidate
      service.invalidate(account: account)

      # Verify cache miss
      expect(Rails.cache.exist?("dashboard_stats/#{account.id}")).to be false
    end
  end
end
```

## Performance Monitoring

### Cache Hit/Miss Logging

```ruby
# config/environments/production.rb
config.action_controller.enable_fragment_cache_logging = true
```

### Custom Instrumentation

```ruby
# Subscribe to cache events
ActiveSupport::Notifications.subscribe("cache_read.active_support") do |*args|
  event = ActiveSupport::Notifications::Event.new(*args)
  Rails.logger.info "Cache #{event.payload[:hit] ? 'HIT' : 'MISS'}: #{event.payload[:key]}"
end
```

## Checklist

- [ ] Cache store configured for environment
- [ ] Fragment caching on expensive partials
- [ ] `touch: true` on belongs_to for Russian doll
- [ ] Collection caching with `cached: true`
- [ ] Low-level caching for expensive queries
- [ ] Cache invalidation strategy defined
- [ ] Counter caches for counts
- [ ] HTTP caching headers for API
- [ ] Cache warming for cold starts (if needed)
- [ ] Monitoring for hit/miss rates
