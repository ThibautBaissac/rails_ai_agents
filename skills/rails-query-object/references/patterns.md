# Query Object Patterns

## Pattern 1: Simple Filtered Query

```ruby
# app/queries/stale_leads_query.rb
class StaleLeadsQuery
  attr_reader :account

  def initialize(account:)
    @account = account
  end

  def call
    account.leads.stale
  end
end
```

## Pattern 2: Aggregation Query (Multiple Methods)

```ruby
# app/queries/dashboard_stats_query.rb
class DashboardStatsQuery
  attr_reader :user, :account

  def initialize(user:)
    @user = user
    @account = user.account
  end

  def upcoming_events(limit: 3)
    account.events
      .where("event_date >= ?", Date.today)
      .order(event_date: :asc)
      .limit(limit)
  end

  def pending_commissions_total
    EventVendor
      .joins(:event)
      .where(events: { account_id: account.id })
      .where(commission_status: :to_invoice)
      .sum(:commission_value)
  end

  def top_vendors(limit: 5)
    account.vendors
      .left_joins(:event_vendors)
      .select("vendors.*, COUNT(event_vendors.id) as events_count")
      .group("vendors.id")
      .order("events_count DESC")
      .limit(limit)
  end

  def leads_by_status
    account.leads.group(:status).count
  end
end
```

## Pattern 3: Grouping Query

```ruby
# app/queries/leads_by_status_query.rb
class LeadsByStatusQuery
  attr_reader :account

  def initialize(account:)
    @account = account
  end

  def call
    leads = account.leads.order(created_at: :desc)
    result = Lead.statuses.keys.map(&:to_sym).index_with { [] }

    leads.group_by(&:status).each do |status, status_leads|
      result[status.to_sym] = status_leads
    end

    result
  end
end
```
