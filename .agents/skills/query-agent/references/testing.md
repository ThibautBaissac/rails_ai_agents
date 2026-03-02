# Query Object RSpec Tests

## Basic Query Tests

```ruby
# spec/queries/entities/search_query_spec.rb
require 'rails_helper'

RSpec.describe Entities::SearchQuery do
  describe '#call' do
    subject(:results) { described_class.new.call(filters) }

    let!(:published_entity) { create(:entity, status: 'published', name: 'Alpha') }
    let!(:draft_entity) { create(:entity, status: 'draft', name: 'Beta') }
    let!(:archived_entity) { create(:entity, status: 'archived', name: 'Gamma') }

    context 'without filters' do
      let(:filters) { {} }

      it 'returns all entities' do
        expect(results).to contain_exactly(published_entity, draft_entity, archived_entity)
      end

      it 'orders by created_at desc' do
        expect(results.first).to eq(archived_entity)
      end
    end

    context 'with status filter' do
      let(:filters) { { status: 'published' } }

      it 'returns only published entities' do
        expect(results).to contain_exactly(published_entity)
      end
    end

    context 'with search query' do
      let(:filters) { { q: 'alpha' } }

      it 'returns entities matching the query' do
        expect(results).to contain_exactly(published_entity)
      end

      it 'is case insensitive' do
        filters[:q] = 'ALPHA'
        expect(results).to contain_exactly(published_entity)
      end
    end

    context 'with sort parameter' do
      let(:filters) { { sort: 'name' } }

      it 'sorts by name ascending' do
        expect(results.pluck(:name)).to eq(%w[Alpha Beta Gamma])
      end
    end

    context 'with multiple filters' do
      let(:filters) { { status: 'published', q: 'alpha' } }

      it 'applies all filters' do
        expect(results).to contain_exactly(published_entity)
      end
    end
  end
end
```

## Testing Complex Queries

```ruby
# spec/queries/users/active_users_query_spec.rb
require 'rails_helper'

RSpec.describe Users::ActiveUsersQuery do
  describe '#call' do
    subject(:results) { described_class.new.call(days: 30) }

    let!(:active_user) { create(:user) }
    let!(:inactive_user) { create(:user) }
    let!(:recently_active_user) { create(:user) }

    before do
      create(:post, user: active_user, created_at: 10.days.ago)
      create(:comment, user: active_user, created_at: 5.days.ago)
      create(:post, user: inactive_user, created_at: 60.days.ago)
      create(:comment, user: recently_active_user, created_at: 2.days.ago)
    end

    it 'returns users active in the last 30 days' do
      expect(results).to contain_exactly(active_user, recently_active_user)
    end

    it 'excludes inactive users' do
      expect(results).not_to include(inactive_user)
    end

    it 'orders by activity count' do
      expect(results.first).to eq(active_user)
    end

    it 'includes activity counts' do
      user = results.find { |u| u.id == active_user.id }
      expect(user.posts_count).to eq(1)
      expect(user.comments_count).to eq(1)
    end
  end
end
```

## Testing Query Performance (N+1 Prevention)

```ruby
# spec/queries/posts/search_query_spec.rb
require 'rails_helper'

RSpec.describe Posts::SearchQuery do
  describe '#call' do
    let!(:posts) { create_list(:post, 3, :with_author, :with_category) }

    it 'avoids N+1 queries' do
      query = described_class.new

      # First call to load associations
      query.call({})

      expect {
        results = query.call({})
        results.each do |post|
          post.author.name
          post.category.name
        end
      }.not_to exceed_query_limit(3)
    end
  end
end
```

## Query Optimization Tips

### Always Include Necessary Associations

```ruby
# ❌ BAD - N+1 queries
def default_relation
  Entity.all
end

# ✅ GOOD - Preload associations
def default_relation
  Entity.includes(:user, :submissions)
end
```

### Use `then` for Chainable Filters

```ruby
# ✅ Clean and readable
relation
  .then { |rel| filter_by_status(rel, status) }
  .then { |rel| filter_by_user(rel, user_id) }
  .then { |rel| search(rel, query) }
```

### Sanitize User Input

```ruby
# ✅ GOOD - Sanitized
def search(relation, query)
  return relation if query.blank?

  relation.where(
    'name ILIKE ?',
    "%#{sanitize_sql_like(query)}%"
  )
end
```

### Use Parameterized Queries

```ruby
# ❌ BAD - SQL injection risk
relation.where("name = '#{query}'")

# ✅ GOOD - Parameterized
relation.where('name = ?', query)
relation.where(name: query)
```
