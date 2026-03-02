---
name: performance-optimization
description: >-
  Identifies and fixes Rails performance issues including N+1 queries, slow
  queries, and memory problems. Use when optimizing queries, fixing N+1 issues,
  improving response times, or when user mentions performance, slow,
  optimization, or Bullet gem.
license: MIT
compatibility: Ruby 3.3+, Rails 8.1+, Bullet gem recommended
metadata:
  author: ThibautBaissac
  version: "1.0"
---

# Performance Optimization for Rails 8

## Overview

Performance optimization focuses on:
- N+1 query detection and prevention
- Query optimization
- Memory management
- Response time improvements
- Database indexing

## Quick Start

```ruby
# Gemfile
group :development, :test do
  gem 'bullet'           # N+1 detection
  gem 'rack-mini-profiler' # Request profiling
  gem 'memory_profiler'  # Memory analysis
end
```

## Bullet Configuration

```ruby
# config/environments/development.rb
config.after_initialize do
  Bullet.enable = true
  Bullet.alert = true
  Bullet.bullet_logger = true
  Bullet.console = true
  Bullet.rails_logger = true
  Bullet.add_footer = true

  # Raise errors in test
  # Bullet.raise = true
end

# config/environments/test.rb
config.after_initialize do
  Bullet.enable = true
  Bullet.raise = true  # Fail tests on N+1
end
```

## N+1 Query Problems

### The Problem

```ruby
# BAD: N+1 query - 1 query for events, N queries for venues
@events = Event.all
@events.each do |event|
  puts event.venue.name  # Query per event!
end

# Generated SQL:
# SELECT * FROM events
# SELECT * FROM venues WHERE id = 1
# SELECT * FROM venues WHERE id = 2
# SELECT * FROM venues WHERE id = 3
# ... (N more queries)
```

### The Solution

```ruby
# GOOD: Eager loading - 2 queries total
@events = Event.includes(:venue)
@events.each do |event|
  puts event.venue.name  # No additional query
end

# Generated SQL:
# SELECT * FROM events
# SELECT * FROM venues WHERE id IN (1, 2, 3, ...)
```

## Eager Loading Methods

### includes (Preferred)

```ruby
# Single association
Event.includes(:venue)

# Multiple associations
Event.includes(:venue, :organizer)

# Nested associations
Event.includes(venue: :address)
Event.includes(vendors: { category: :parent })

# Deep nesting
Event.includes(
  :venue,
  :organizer,
  vendors: [:category, :reviews],
  comments: :user
)
```

### preload vs eager_load

```ruby
# preload: Separate queries (default for includes)
Event.preload(:venue)
# SELECT * FROM events
# SELECT * FROM venues WHERE id IN (...)

# eager_load: Single LEFT JOIN query
Event.eager_load(:venue)
# SELECT events.*, venues.* FROM events LEFT JOIN venues ON ...

# includes chooses automatically based on conditions
Event.includes(:venue).where(venues: { city: 'Paris' })
# Uses LEFT JOIN because of WHERE condition on venue
```

### When to Use Each

| Method | Use When |
|--------|----------|
| `includes` | Most cases (Rails chooses best strategy) |
| `preload` | Forcing separate queries, large datasets |
| `eager_load` | Filtering on association, need single query |
| `joins` | Only need to filter, don't need association data |

## Query Optimization Patterns

### Pattern 1: Scoped Eager Loading

```ruby
# app/models/event.rb
class Event < ApplicationRecord
  scope :with_details, -> {
    includes(:venue, :organizer, vendors: :category)
  }

  scope :with_stats, -> {
    select("events.*,
            (SELECT COUNT(*) FROM comments WHERE comments.event_id = events.id) as comments_count,
            (SELECT COUNT(*) FROM event_vendors WHERE event_vendors.event_id = events.id) as vendors_count")
  }
end

# Controller
@events = Event.with_details.where(account: current_account)
```

### Pattern 2: Counter Caches

```ruby
# Migration
add_column :events, :comments_count, :integer, default: 0, null: false
add_column :events, :vendors_count, :integer, default: 0, null: false

# Model
class Comment < ApplicationRecord
  belongs_to :event, counter_cache: true
end

class EventVendor < ApplicationRecord
  belongs_to :event, counter_cache: :vendors_count
end

# Usage - no query needed
event.comments_count
event.vendors_count
```

### Pattern 3: Select Only Needed Columns

```ruby
# BAD: Loads all columns
User.all.map(&:name)

# GOOD: Loads only name
User.pluck(:name)

# GOOD: For objects with limited columns
User.select(:id, :name, :email).map { |u| "#{u.name} <#{u.email}>" }
```

### Pattern 4: Batch Processing

```ruby
# BAD: Loads all records into memory
Event.all.each { |e| process(e) }

# GOOD: Processes in batches
Event.find_each(batch_size: 500) { |e| process(e) }

# GOOD: For updates
Event.in_batches(of: 1000) do |batch|
  batch.update_all(status: :archived)
end
```

### Pattern 5: Exists? vs Any? vs Present?

```ruby
# BAD: Loads all records
if Event.where(status: :active).any?
if Event.where(status: :active).present?

# GOOD: SELECT 1 LIMIT 1
if Event.where(status: :active).exists?

# GOOD: For checking count
if Event.where(status: :active).count > 0
```

### Pattern 6: Size vs Count vs Length

```ruby
# count: Always queries database
events.count  # SELECT COUNT(*) FROM events

# size: Uses counter cache or count
events.size   # Uses cached value if available

# length: Uses loaded collection or loads all
events.length # Loads all records if not loaded

# Best practices:
events.loaded? ? events.length : events.count
# OR just use size (handles both cases)
```

## Database Indexing

### Finding Missing Indexes

```ruby
# Check for missing foreign key indexes
ActiveRecord::Base.connection.tables.each do |table|
  columns = ActiveRecord::Base.connection.columns(table)
  fk_columns = columns.select { |c| c.name.end_with?('_id') }
  indexes = ActiveRecord::Base.connection.indexes(table)

  fk_columns.each do |col|
    indexed = indexes.any? { |idx| idx.columns.include?(col.name) }
    puts "Missing index: #{table}.#{col.name}" unless indexed
  end
end
```

### Index Types

```ruby
# Single column index
add_index :events, :status

# Composite index (order matters!)
add_index :events, [:account_id, :status]

# Unique index
add_index :users, :email, unique: true

# Partial index
add_index :events, :event_date, where: "status = 0"

# Covering index (PostgreSQL)
add_index :events, [:account_id, :status], include: [:name, :event_date]
```

### When to Add Indexes

| Add Index For | Example |
|--------------|---------|
| Foreign keys | `account_id`, `user_id` |
| Columns in WHERE | `WHERE status = 'active'` |
| Columns in ORDER BY | `ORDER BY created_at DESC` |
| Columns in JOIN | `JOIN ON events.venue_id` |
| Unique constraints | `email`, `uuid` |

## Memory Optimization

### Finding Memory Issues

```ruby
# In console or specs
require 'memory_profiler'

report = MemoryProfiler.report do
  # Code to profile
  Event.includes(:venue, :vendors).to_a
end

report.pretty_print
```

### Memory-Efficient Patterns

```ruby
# BAD: Loads all records
Event.all.map(&:name).join(', ')

# GOOD: Streams results
Event.pluck(:name).join(', ')

# BAD: Builds large array
results = []
Event.find_each { |e| results << e.name }

# GOOD: Uses Enumerator
Event.find_each.map(&:name)
```

### Avoiding Memory Bloat

```ruby
# BAD: Instantiates all AR objects
Event.all.each do |event|
  event.update!(processed: true)
end

# GOOD: Direct SQL update
Event.update_all(processed: true)

# GOOD: Batched updates
Event.in_batches.update_all(processed: true)
```

## Query Analysis

### EXPLAIN in Rails

```ruby
# Analyze query plan
Event.where(status: :active).explain

# Analyze with format
Event.where(status: :active).explain(:analyze)
```

### Logging Slow Queries

```ruby
# config/environments/production.rb
config.active_record.warn_on_records_fetched_greater_than = 1000

# Custom slow query logging
ActiveSupport::Notifications.subscribe("sql.active_record") do |*args|
  event = ActiveSupport::Notifications::Event.new(*args)
  if event.duration > 100  # ms
    Rails.logger.warn("SLOW QUERY (#{event.duration.round}ms): #{event.payload[:sql]}")
  end
end
```

## Testing for Performance

### N+1 Detection in Specs

```ruby
# spec/rails_helper.rb
RSpec.configure do |config|
  config.before(:each) do
    Bullet.start_request
  end

  config.after(:each) do
    Bullet.perform_out_of_channel_notifications if Bullet.notification?
    Bullet.end_request
  end
end

# spec/requests/events_spec.rb
RSpec.describe "Events", type: :request do
  it "loads index without N+1" do
    create_list(:event, 5, :with_venue, :with_vendors)

    expect {
      get events_path
    }.not_to raise_error  # Bullet raises on N+1
  end
end
```

### Query Count Assertions

```ruby
# spec/support/query_counter.rb
module QueryCounter
  def count_queries(&block)
    count = 0
    counter = ->(*, _) { count += 1 }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record", &block)
    count
  end
end

RSpec.configure do |config|
  config.include QueryCounter
end

# Usage
it "makes minimal queries" do
  events = create_list(:event, 5, :with_venue)

  query_count = count_queries do
    Event.with_details.map { |e| e.venue.name }
  end

  expect(query_count).to eq(2)  # events + venues
end
```

## Rack Mini Profiler

### Setup

```ruby
# Gemfile
gem 'rack-mini-profiler'
gem 'stackprof'  # For flamegraphs

# config/initializers/rack_profiler.rb
if Rails.env.development?
  Rack::MiniProfiler.config.position = 'bottom-right'
  Rack::MiniProfiler.config.start_hidden = false
end
```

### Usage

- Visit any page - profiler badge shows in corner
- Click badge to see detailed breakdown
- Add `?pp=flamegraph` for flamegraph
- Add `?pp=help` for all options

## Performance Checklist

### Before Deployment

- [ ] Bullet enabled in development/test
- [ ] No N+1 queries in critical paths
- [ ] Foreign keys have indexes
- [ ] Counter caches for frequent counts
- [ ] Eager loading in controllers
- [ ] Batch processing for large datasets
- [ ] Query analysis for slow endpoints

### Monitoring Queries

```ruby
# app/controllers/application_controller.rb
around_action :log_query_count, if: -> { Rails.env.development? }

private

def log_query_count
  count = 0
  counter = ->(*, _) { count += 1 }
  ActiveSupport::Notifications.subscribed(counter, "sql.active_record") do
    yield
  end
  Rails.logger.info "QUERIES: #{count} for #{request.path}"
end
```

## Quick Fixes Reference

| Problem | Solution |
|---------|----------|
| N+1 on belongs_to | `includes(:association)` |
| N+1 on has_many | `includes(:association)` |
| Slow COUNT | Add counter_cache |
| Loading all columns | Use `select` or `pluck` |
| Large dataset iteration | Use `find_each` |
| Missing index on FK | Add index on `*_id` columns |
| Slow WHERE clause | Add index on filtered column |
| Loading unused associations | Remove from `includes` |
