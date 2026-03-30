---
name: caching-strategies
description: >-
  Implements Rails caching patterns for performance optimization. Use when
  adding fragment caching, Russian doll caching, low-level caching, cache
  invalidation, or when user mentions caching, performance, cache keys,
  or memoization. WHEN NOT: General query optimization (use
  performance-optimization), background job processing, or problems caused by
  N+1 queries rather than missing caches.
paths: "app/views/**/*.erb, app/controllers/**/*.rb"
---

# Caching Strategies for Rails 8

## Overview

Rails provides multiple caching layers:
- **Fragment caching**: Cache view partials
- **Russian doll caching**: Nested cache fragments
- **Low-level caching**: Cache arbitrary data
- **HTTP caching**: Browser and CDN caching
- **Query caching**: Automatic within requests

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

Use `touch: true` on `belongs_to` associations to cascade invalidation up the chain. See [cache-invalidation.md](references/cache-invalidation.md) for examples.

## Collection Caching

### Efficient Collection Rendering

```erb
<%# Caches each item individually %>
<%= render partial: "events/event", collection: @events, cached: true %>

<%# With custom cache key %>
<%= render partial: "events/event",
           collection: @events,
           cached: ->(event) { [event, current_user.admin?] } %>
```

## Low-Level Caching

Use `Rails.cache.fetch` with a block for the most common pattern. See [low-level-caching.md](references/low-level-caching.md) for:
- Basic read/write/fetch examples
- Caching in service objects
- Caching in query objects
- Instance variable memoization
- Request-scoped memoization with `CurrentAttributes`

## Cache Invalidation

Three strategies: time-based expiration, key-based expiration (using `updated_at`), and manual deletion. See [cache-invalidation.md](references/cache-invalidation.md) for:
- Time-based and key-based expiration
- Manual invalidation in model callbacks and services
- Pattern-based deletion (`delete_matched`)
- `touch: true` for Russian doll cascade
- Built-in and custom counter caches

## HTTP Caching

Use `stale?` for conditional GET (ETags/Last-Modified) and `expires_in` for Cache-Control headers. See [http-caching-and-testing.md](references/http-caching-and-testing.md) for full examples.

## Testing Caching

Use a `:caching` metadata tag to enable caching in specs. See [http-caching-and-testing.md](references/http-caching-and-testing.md) for:
- `rails_helper.rb` configuration
- Testing cached view invalidation
- Testing cache invalidation in services
- Performance monitoring and instrumentation

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

## References

- [low-level-caching.md](references/low-level-caching.md) - fetch/read/write, service objects, query objects, memoization
- [cache-invalidation.md](references/cache-invalidation.md) - expiration strategies, manual invalidation, touch, counter caches
- [http-caching-and-testing.md](references/http-caching-and-testing.md) - ETags, Cache-Control, spec configuration, monitoring
