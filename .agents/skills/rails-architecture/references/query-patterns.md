# Query Object Patterns

## Basic Query Structure

```ruby
# app/queries/[name]_query.rb
class NameQuery
  attr_reader :account

  def initialize(account:)
    @account = account
  end

  # @return [ActiveRecord::Relation<Model>]
  def call
    account.models
      .where(conditions)
      .order(created_at: :desc)
  end
end
```

## Query Categories

### 1. Filter Queries

Return filtered ActiveRecord relations:

```ruby
# app/queries/active_events_query.rb
class ActiveEventsQuery
  attr_reader :account

  def initialize(account:)
    @account = account
  end

  def call(date_range: nil)
    scope = account.events.where(status: :active)
    scope = scope.where(event_date: date_range) if date_range
    scope.includes(:venue, :vendors).order(event_date: :asc)
  end
end
```

### 2. Aggregation Queries

Return computed statistics:

```ruby
# app/queries/revenue_stats_query.rb
class RevenueStatsQuery
  attr_reader :account

  def initialize(account:)
    @account = account
  end

  def call(period: :month)
    {
      total: total_revenue,
      by_period: revenue_by_period(period),
      by_category: revenue_by_category,
      growth_rate: calculate_growth
    }
  end

  private

  def total_revenue
    account.orders.completed.sum(:total_cents)
  end

  def revenue_by_period(period)
    group_clause = case period
    when :day then "DATE(created_at)"
    when :week then "DATE_TRUNC('week', created_at)"
    when :month then "DATE_TRUNC('month', created_at)"
    end

    account.orders.completed
      .group(Arel.sql(group_clause))
      .sum(:total_cents)
  end

  def revenue_by_category
    account.orders.completed
      .joins(line_items: :product)
      .group("products.category")
      .sum(:total_cents)
  end
end
```

### 3. Dashboard Queries

Multiple related metrics:

```ruby
# app/queries/dashboard_stats_query.rb
class DashboardStatsQuery
  attr_reader :user, :account

  def initialize(user:)
    @user = user
    @account = user.account
  end

  def upcoming_events(limit: 5)
    account.events
      .where("event_date >= ?", Date.current)
      .order(event_date: :asc)
      .limit(limit)
  end

  def pending_tasks_count
    account.tasks.pending.count
  end

  def leads_by_status
    account.leads.group(:status).count
  end

  def recent_activity(limit: 10)
    account.activities
      .includes(:user, :trackable)
      .order(created_at: :desc)
      .limit(limit)
  end
end
```

### 4. Search Queries

Full-text search with filters:

```ruby
# app/queries/vendor_search_query.rb
class VendorSearchQuery
  attr_reader :account

  def initialize(account:)
    @account = account
  end

  def call(term:, filters: {})
    scope = account.vendors

    scope = apply_search(scope, term) if term.present?
    scope = apply_filters(scope, filters)
    scope = apply_sorting(scope, filters[:sort])

    scope.includes(:category, :reviews)
  end

  private

  def apply_search(scope, term)
    scope.where(
      "name ILIKE :term OR description ILIKE :term",
      term: "%#{sanitize_like(term)}%"
    )
  end

  def apply_filters(scope, filters)
    scope = scope.where(category_id: filters[:category]) if filters[:category]
    scope = scope.where(active: true) if filters[:active_only]
    scope = scope.where("rating >= ?", filters[:min_rating]) if filters[:min_rating]
    scope
  end

  def apply_sorting(scope, sort)
    case sort
    when "name" then scope.order(name: :asc)
    when "rating" then scope.order(rating: :desc)
    when "recent" then scope.order(created_at: :desc)
    else scope.order(name: :asc)
    end
  end

  def sanitize_like(term)
    term.gsub(/[%_]/) { |x| "\\#{x}" }
  end
end
```

### 5. Report Queries

Complex data for exports:

```ruby
# app/queries/event_report_query.rb
class EventReportQuery
  attr_reader :account

  def initialize(account:)
    @account = account
  end

  def call(date_range:)
    account.events
      .where(event_date: date_range)
      .includes(:venue, :vendors, :attendees)
      .select(
        "events.*",
        "COUNT(DISTINCT attendees.id) as attendee_count",
        "SUM(event_vendors.amount_cents) as total_vendor_cost"
      )
      .joins(:attendees, :event_vendors)
      .group("events.id")
      .order(event_date: :asc)
  end
end
```

## Performance Patterns

### Eager Loading

```ruby
def call
  account.events
    .includes(:venue)                    # Belongs-to
    .includes(:vendors)                  # Has-many through
    .includes(attendees: :user)          # Nested
    .preload(:documents)                 # Separate query
    .eager_load(:primary_contact)        # LEFT JOIN
end
```

### Batch Processing

```ruby
def process_all
  account.events.find_each(batch_size: 100) do |event|
    yield event
  end
end
```

### Subquery Optimization

```ruby
def call
  # Use subquery instead of pluck for large datasets
  active_vendor_ids = account.vendors.active.select(:id)

  account.events
    .where(vendor_id: active_vendor_ids)
    .order(created_at: :desc)
end
```

## Multi-Tenancy Patterns

### Always Scope Through Account

```ruby
# GOOD
def call
  account.events.where(status: :active)
end

# BAD - Security risk!
def call
  Event.where(account_id: account.id, status: :active)
end
```

### Test Isolation

```ruby
RSpec.describe ActiveEventsQuery do
  let(:account) { create(:account) }
  let(:other_account) { create(:account) }

  let!(:our_event) { create(:event, account: account) }
  let!(:their_event) { create(:event, account: other_account) }

  it "only returns events for the account" do
    result = described_class.new(account: account).call
    expect(result).to include(our_event)
    expect(result).not_to include(their_event)
  end
end
```

## Composition Patterns

### Query Chaining

```ruby
# Queries return relations, enabling chaining
events = ActiveEventsQuery.new(account: account).call
upcoming = events.where("event_date > ?", Date.current)
paginated = upcoming.page(params[:page]).per(20)
```

### Query Composition

```ruby
class ComplexReportQuery
  def initialize(account:)
    @events_query = ActiveEventsQuery.new(account: account)
    @revenue_query = RevenueStatsQuery.new(account: account)
  end

  def call(date_range:)
    {
      events: @events_query.call(date_range: date_range),
      revenue: @revenue_query.call
    }
  end
end
```

## Usage in Controllers

```ruby
class EventsController < ApplicationController
  def index
    @events = ActiveEventsQuery.new(account: current_account)
      .call
      .page(params[:page])
  end

  def dashboard
    @stats = DashboardStatsQuery.new(user: current_user)
  end
end
```

## Checklist

- [ ] Constructor accepts `account:` or `user:`
- [ ] Always scoped through account (multi-tenant)
- [ ] Return type documented (`@return`)
- [ ] Uses `.includes()` to prevent N+1
- [ ] Search terms sanitized
- [ ] Spec tests tenant isolation
- [ ] Complex queries explain their purpose
