# Caching Strategies: Low-Level Caching

## Basic Read/Write/Fetch

```ruby
# Read with block (fetch - preferred pattern)
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

## In Service Objects

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

## In Query Objects

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
