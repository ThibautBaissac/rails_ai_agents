# Query Object Patterns

## ApplicationQuery Base Class

```ruby
# app/queries/application_query.rb
class ApplicationQuery
  attr_reader :relation

  def initialize(relation = default_relation)
    @relation = relation
  end

  def call(params = {})
    raise NotImplementedError, "#{self.class} must implement #call"
  end

  def self.call(*args)
    new.call(*args)
  end

  private

  def default_relation
    raise NotImplementedError, "#{self.class} must implement #default_relation"
  end

  def sanitize_sql_like(string)
    ActiveRecord::Base.sanitize_sql_like(string)
  end
end
```

## Basic Search Query

```ruby
# app/queries/entities/search_query.rb
module Entities
  class SearchQuery < ApplicationQuery
    def call(filters = {})
      relation
        .then { |rel| filter_by_status(rel, filters[:status]) }
        .then { |rel| filter_by_user(rel, filters[:user_id]) }
        .then { |rel| search(rel, filters[:q]) }
        .then { |rel| sort(rel, filters[:sort]) }
    end

    private

    def default_relation
      Entity.includes(:user)
    end

    def filter_by_status(relation, status)
      return relation if status.blank?
      relation.where(status: status)
    end

    def filter_by_user(relation, user_id)
      return relation if user_id.blank?
      relation.where(user_id: user_id)
    end

    def search(relation, query)
      return relation if query.blank?

      relation.where(
        'name ILIKE :q OR description ILIKE :q',
        q: "%#{sanitize_sql_like(query)}%"
      )
    end

    def sort(relation, sort_param)
      case sort_param
      when 'name' then relation.order(name: :asc)
      when 'oldest' then relation.order(created_at: :asc)
      else relation.order(created_at: :desc)
      end
    end
  end
end
```

## Search Query with Multiple Filters

```ruby
# app/queries/posts/search_query.rb
module Posts
  class SearchQuery < ApplicationQuery
    ALLOWED_STATUSES = %w[draft published archived].freeze
    ALLOWED_SORT_FIELDS = %w[title created_at updated_at].freeze

    def call(filters = {})
      relation
        .then { |rel| filter_by_status(rel, filters[:status]) }
        .then { |rel| filter_by_author(rel, filters[:author_id]) }
        .then { |rel| filter_by_category(rel, filters[:category_id]) }
        .then { |rel| filter_by_date_range(rel, filters[:from_date], filters[:to_date]) }
        .then { |rel| search_text(rel, filters[:q]) }
        .then { |rel| sort(rel, filters[:sort_by], filters[:sort_dir]) }
    end

    private

    def default_relation
      Post.includes(:author, :category)
    end

    def filter_by_status(relation, status)
      return relation if status.blank?
      return relation unless ALLOWED_STATUSES.include?(status)

      relation.where(status: status)
    end

    def filter_by_author(relation, author_id)
      return relation if author_id.blank?
      relation.where(author_id: author_id)
    end

    def filter_by_category(relation, category_id)
      return relation if category_id.blank?
      relation.where(category_id: category_id)
    end

    def filter_by_date_range(relation, from_date, to_date)
      relation = relation.where('created_at >= ?', from_date) if from_date.present?
      relation = relation.where('created_at <= ?', to_date) if to_date.present?
      relation
    end

    def search_text(relation, query)
      return relation if query.blank?

      sanitized = sanitize_sql_like(query)
      relation.where(
        'title ILIKE :q OR body ILIKE :q',
        q: "%#{sanitized}%"
      )
    end

    def sort(relation, field, direction)
      field = 'created_at' unless ALLOWED_SORT_FIELDS.include?(field)
      direction = direction == 'asc' ? :asc : :desc

      relation.order(field => direction)
    end
  end
end
```

## Reporting Query with Aggregations

```ruby
# app/queries/orders/revenue_report_query.rb
module Orders
  class RevenueReportQuery < ApplicationQuery
    def call(start_date:, end_date:, group_by: :day)
      relation
        .where(created_at: start_date..end_date)
        .where(status: %w[paid delivered])
        .group_by_period(group_by, :created_at)
        .select(
          date_trunc_sql(group_by),
          'COUNT(*) as orders_count',
          'SUM(total) as total_revenue',
          'AVG(total) as average_order_value'
        )
    end

    private

    def default_relation
      Order.all
    end

    def date_trunc_sql(period)
      case period
      when :hour then "DATE_TRUNC('hour', created_at) as period"
      when :day then "DATE_TRUNC('day', created_at) as period"
      when :week then "DATE_TRUNC('week', created_at) as period"
      when :month then "DATE_TRUNC('month', created_at) as period"
      else "DATE_TRUNC('day', created_at) as period"
      end
    end
  end
end
```

## Complex Join Query

```ruby
# app/queries/users/active_users_query.rb
module Users
  class ActiveUsersQuery < ApplicationQuery
    def call(days: 30)
      relation
        .joins(:posts, :comments)
        .where('posts.created_at >= ? OR comments.created_at >= ?', days.days.ago, days.days.ago)
        .distinct
        .select(
          'users.*',
          'COUNT(DISTINCT posts.id) as posts_count',
          'COUNT(DISTINCT comments.id) as comments_count'
        )
        .group('users.id')
        .having('COUNT(DISTINCT posts.id) > 0 OR COUNT(DISTINCT comments.id) > 0')
        .order('posts_count + comments_count DESC')
    end

    private

    def default_relation
      User.all
    end
  end
end
```

## Scope-Based Dashboard Query

```ruby
# app/queries/entities/dashboard_query.rb
module Entities
  class DashboardQuery < ApplicationQuery
    def call(user:, filters: {})
      relation
        .for_user(user)
        .then { |rel| apply_visibility(rel, filters[:visibility]) }
        .then { |rel| apply_time_range(rel, filters[:time_range]) }
        .recent
        .with_stats
    end

    private

    def default_relation
      Entity.includes(:user, :submissions)
    end

    def apply_visibility(relation, visibility)
      case visibility
      when 'mine'
        relation.where(user: user)
      when 'public'
        relation.where(visibility: 'public')
      else
        relation
      end
    end

    def apply_time_range(relation, time_range)
      case time_range
      when 'today'
        relation.where('created_at >= ?', Time.current.beginning_of_day)
      when 'week'
        relation.where('created_at >= ?', 1.week.ago)
      when 'month'
        relation.where('created_at >= ?', 1.month.ago)
      else
        relation
      end
    end
  end
end
```

## Full-Text Search Query

```ruby
# app/queries/articles/full_text_search_query.rb
module Articles
  class FullTextSearchQuery < ApplicationQuery
    def call(query)
      return relation.none if query.blank?

      sanitized_query = sanitize_sql_like(query)
      search_terms = sanitized_query.split.map { |term| "%#{term}%" }

      relation
        .where(build_search_condition(search_terms))
        .order(Arel.sql("ts_rank(to_tsvector('english', title || ' ' || body), plainto_tsquery('english', ?)) DESC"), query)
    end

    private

    def default_relation
      Article.published.includes(:author)
    end

    def build_search_condition(terms)
      conditions = terms.map do |term|
        "title ILIKE :term OR body ILIKE :term OR author.name ILIKE :term"
      end

      [conditions.join(' OR '), { term: terms }]
    end
  end
end
```

## Geolocation Query

```ruby
# app/queries/locations/nearby_query.rb
module Locations
  class NearbyQuery < ApplicationQuery
    EARTH_RADIUS_KM = 6371.0

    def call(latitude:, longitude:, radius_km: 10)
      relation
        .select(
          'locations.*',
          distance_sql(latitude, longitude)
        )
        .having("distance <= ?", radius_km)
        .order('distance ASC')
    end

    private

    def default_relation
      Location.all
    end

    def distance_sql(lat, lng)
      <<~SQL
        (
          #{EARTH_RADIUS_KM} * acos(
            cos(radians(#{lat})) *
            cos(radians(latitude)) *
            cos(radians(longitude) - radians(#{lng})) +
            sin(radians(#{lat})) *
            sin(radians(latitude))
          )
        ) as distance
      SQL
    end
  end
end
```

## Pagination-Aware Catalog Query

```ruby
# app/queries/products/catalog_query.rb
module Products
  class CatalogQuery < ApplicationQuery
    def call(filters = {}, page: 1, per_page: 20)
      relation
        .then { |rel| filter_by_category(rel, filters[:category]) }
        .then { |rel| filter_by_price_range(rel, filters[:min_price], filters[:max_price]) }
        .then { |rel| filter_by_availability(rel, filters[:in_stock]) }
        .then { |rel| sort(rel, filters[:sort]) }
        .page(page)
        .per(per_page)
    end

    private

    def default_relation
      Product.includes(:category, :reviews)
    end

    def filter_by_category(relation, category_id)
      return relation if category_id.blank?
      relation.where(category_id: category_id)
    end

    def filter_by_price_range(relation, min_price, max_price)
      relation = relation.where('price >= ?', min_price) if min_price.present?
      relation = relation.where('price <= ?', max_price) if max_price.present?
      relation
    end

    def filter_by_availability(relation, in_stock)
      return relation if in_stock.blank?

      case in_stock
      when 'true', true
        relation.where('stock > 0')
      when 'false', false
        relation.where(stock: 0)
      else
        relation
      end
    end

    def sort(relation, sort_param)
      case sort_param
      when 'price_asc' then relation.order(price: :asc)
      when 'price_desc' then relation.order(price: :desc)
      when 'name' then relation.order(name: :asc)
      when 'popular' then relation.order(views_count: :desc)
      else relation.order(created_at: :desc)
      end
    end
  end
end
```

## Usage in Controllers

```ruby
# app/controllers/entities_controller.rb
class EntitiesController < ApplicationController
  def index
    @entities = Entities::SearchQuery
      .new
      .call(search_params)
      .page(params[:page])
  end

  private

  def search_params
    params.permit(:status, :user_id, :q, :sort)
  end
end
```
