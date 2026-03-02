---
name: rails-query-object
description: >-
  Creates query objects for complex database queries following TDD. Use when
  encapsulating complex queries, aggregating statistics, building reports,
  or when user mentions queries, stats, dashboards, or data aggregation.
license: MIT
compatibility: Ruby 3.3+, Rails 8.1+, RSpec
metadata:
  author: ThibautBaissac
  version: "1.0"
---

# Rails Query Object Generator (TDD)

Creates query objects that encapsulate complex database queries with specs first.

## Quick Start

1. Write failing spec in `spec/queries/`
2. Run spec to confirm RED
3. Implement query object in `app/queries/`
4. Run spec to confirm GREEN

## Project Conventions

Query objects in this project:
- Accept context via constructor (`user:` or `account:`)
- Return `ActiveRecord::Relation` for chainability OR `Hash` for aggregations
- Have a `call` method for primary operation
- Support multi-tenancy (scoped to account)

## TDD Workflow

### Step 1: Create Query Spec (RED)

```ruby
# spec/queries/[name]_query_spec.rb
RSpec.describe [Name]Query do
  subject(:query) { described_class.new(account: account) }

  let(:user) { create(:user) }
  let(:account) { user.account }
  let(:other_account) { create(:user).account }

  # Test data for current account
  let!(:resource1) { create(:resource, account: account) }
  let!(:resource2) { create(:resource, account: account) }

  # Test data for other account (should not appear)
  let!(:other_resource) { create(:resource, account: other_account) }

  describe "#initialize" do
    it "requires an account parameter" do
      expect { described_class.new }.to raise_error(ArgumentError)
    end

    it "stores the account" do
      expect(query.account).to eq(account)
    end
  end

  describe "#call" do
    it "returns expected result type" do
      expect(query.call).to be_a(ActiveRecord::Relation)
      # OR for hash results:
      # expect(query.call).to be_a(Hash)
    end

    it "only returns resources for the account (multi-tenant)" do
      result = query.call
      expect(result).to include(resource1, resource2)
      expect(result).not_to include(other_resource)
    end
  end

  describe "multi-tenant isolation" do
    it "ensures account A cannot see account B data" do
      other_query = described_class.new(account: other_account)

      expect(query.call).not_to include(other_resource)
      expect(other_query.call).not_to include(resource1)
    end
  end
end
```

### Step 2: Run Spec (Confirm RED)

```bash
bundle exec rspec spec/queries/[name]_query_spec.rb
```

### Step 3: Implement Query Object (GREEN)

```ruby
# app/queries/[name]_query.rb
class [Name]Query
  attr_reader :account

  def initialize(account:)
    @account = account
  end

  # Returns [description of result]
  # @return [ActiveRecord::Relation<Resource>] OR [Hash]
  def call
    account.resources
      .where(condition: value)
      .order(created_at: :desc)
  end
end
```

### Step 4: Run Spec (Confirm GREEN)

```bash
bundle exec rspec spec/queries/[name]_query_spec.rb
```

## Query Object Patterns

### Pattern 1: Simple Filtered Query

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

### Pattern 2: Aggregation Query (Multiple Methods)

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

### Pattern 3: Grouping Query

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

## Usage in Controllers

```ruby
# Simple query
def index
  @leads_by_status = LeadsByStatusQuery.new(account: current_account).call
end

# Aggregation query with presenter
def index
  stats_query = DashboardStatsQuery.new(user: current_user)
  @stats = DashboardStatsPresenter.new(stats_query)
end
```

## Checklist

- [ ] Spec written first (RED)
- [ ] Constructor accepts context (`user:` or `account:`)
- [ ] Multi-tenant isolation tested
- [ ] Return type documented (`@return`)
- [ ] Methods have clear, descriptive names
- [ ] Complex queries use `.includes()` to prevent N+1
- [ ] All specs GREEN
