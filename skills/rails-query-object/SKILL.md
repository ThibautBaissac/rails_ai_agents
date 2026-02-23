---
name: rails-query-object
description: >-
  Generates Rails query objects following TDD (RED → GREEN) with RSpec specs.
  Builds filtered queries, aggregation pipelines, and grouping queries scoped to an account
  for multi-tenant isolation. Places specs in `spec/queries/` and implementations in `app/queries/`.
  Use when encapsulating complex ActiveRecord queries, building dashboard stats, aggregating data
  for reports, creating scoped database lookups, or when user mentions queries, stats, dashboards,
  data aggregation, or query objects.
allowed-tools: Read, Write, Edit, Bash(bundle exec rspec:*), Glob, Grep
---

# Rails Query Object Generator (TDD)

## Workflow

1. Write failing spec in `spec/queries/[name]_query_spec.rb`
2. Run `bundle exec rspec spec/queries/[name]_query_spec.rb` — confirm RED
3. Implement query object in `app/queries/[name]_query.rb`
4. Run spec again — confirm GREEN

## Project Conventions

| Convention | Detail |
|---|---|
| Constructor | Accepts context via `user:` or `account:` |
| Return type | `ActiveRecord::Relation` for chainability, `Hash` for aggregations |
| Entry point | `#call` method for primary operation |
| Multi-tenancy | Always scope queries to `account` |
| Spec location | `spec/queries/[name]_query_spec.rb` |
| Implementation | `app/queries/[name]_query.rb` |

## Spec Template

```ruby
# spec/queries/[name]_query_spec.rb
RSpec.describe [Name]Query do
  subject(:query) { described_class.new(account: account) }

  let(:user) { create(:user) }
  let(:account) { user.account }
  let(:other_account) { create(:user).account }

  let!(:resource1) { create(:resource, account: account) }
  let!(:resource2) { create(:resource, account: account) }
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

## Implementation Template

```ruby
# app/queries/[name]_query.rb
class [Name]Query
  attr_reader :account

  def initialize(account:)
    @account = account
  end

  # @return [ActiveRecord::Relation<Resource>]
  def call
    account.resources
      .where(condition: value)
      .order(created_at: :desc)
  end
end
```

## Controller Usage

```ruby
# Simple query
@leads_by_status = LeadsByStatusQuery.new(account: current_account).call

# Aggregation query with presenter
stats_query = DashboardStatsQuery.new(user: current_user)
@stats = DashboardStatsPresenter.new(stats_query)
```

## Checklist

- [ ] Spec written first (RED)
- [ ] Constructor accepts context (`user:` or `account:`)
- [ ] Multi-tenant isolation tested
- [ ] Return type documented (`@return`)
- [ ] Methods have clear, descriptive names
- [ ] Complex queries use `.includes()` to prevent N+1
- [ ] All specs GREEN

See [references/patterns.md](references/patterns.md) for filtered, aggregation, and grouping query examples.
