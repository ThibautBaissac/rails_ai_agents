# Cache Invalidation Reference

## Strategy 1: touch: true (Preferred)

Automatic invalidation through association cascades. This is the primary
mechanism for Russian doll caching.

```ruby
class Comment < ApplicationRecord
  belongs_to :card, touch: true
end

class Card < ApplicationRecord
  belongs_to :board, touch: true
end

# comment.update! -> card.updated_at changes -> board.updated_at changes
# All fragment cache keys change automatically
```

Use `counter_cache: true` alongside `touch: true` for associations where you
display counts:

```ruby
class Card < ApplicationRecord
  belongs_to :board, counter_cache: true, touch: true
end

# Migration
add_column :boards, :cards_count, :integer, default: 0, null: false

reversible do |dir|
  dir.up { Board.find_each { |b| Board.reset_counters(b.id, :cards) } }
end
```

## Strategy 2: Manual Deletion

For low-level `Rails.cache.fetch` caches that don't use `updated_at` keys.

```ruby
class Board < ApplicationRecord
  after_update :clear_statistics_cache, if: :significant_change?

  def clear_statistics_cache
    Rails.cache.delete([self, "statistics"])
    Rails.cache.delete([self, "card_distribution"])
  end

  def refresh_cache
    clear_statistics_cache
    statistics           # Regenerate
    card_distribution    # Regenerate
  end

  private

  def significant_change?
    saved_change_to_name? || saved_change_to_description?
  end
end

class Card < ApplicationRecord
  belongs_to :board, touch: true

  after_create_commit :clear_board_caches
  after_destroy_commit :clear_board_caches

  private

  def clear_board_caches
    Rails.cache.delete([board, "statistics"])
    Rails.cache.delete([board, "card_distribution"])
  end
end
```

## Strategy 3: Cacheable Concern

Reusable concern for common cache management patterns.

```ruby
module Cacheable
  extend ActiveSupport::Concern

  included do
    after_commit :clear_associated_caches
  end

  def clear_associated_caches
    # Override in models
  end

  def cache_key_with_account
    [Current.account, cache_key_with_version]
  end
end

# Usage
class Board < ApplicationRecord
  include Cacheable

  def clear_associated_caches
    Rails.cache.delete([self, "statistics"])
  end
end
```

## Strategy 4: Cache Sweeper

Centralized invalidation for complex dependency graphs.

```ruby
class CacheSweeper
  def self.clear_board_caches(board)
    Rails.cache.delete([board, "statistics"])
    Rails.cache.delete([board, "card_distribution"])
    Rails.cache.delete([board, "activity_summary", Date.current])

    board.account.tap do |account|
      Rails.cache.delete(
        [account, "monthly_metrics", Date.current.beginning_of_month]
      )
    end
  end

  def self.clear_account_caches(account)
    Rails.cache.delete_matched("accounts/#{account.id}/*")
  end

  def self.clear_user_caches(user)
    Rails.cache.delete([user, "preferences"])
    Rails.cache.delete([user, "permissions"])
    Rails.cache.delete([user, "recent_boards"])
  end
end

# Usage in models
class Board < ApplicationRecord
  after_update :sweep_caches

  private

  def sweep_caches
    CacheSweeper.clear_board_caches(self)
  end
end
```

## Strategy 5: Time-Based Expiry

For data where staleness is acceptable within a time window.

```ruby
# Short-lived cache for frequently changing data
Rails.cache.fetch([self, "activity_summary", Date.current],
                  expires_in: 5.minutes) do
  activities.where(created_at: 24.hours.ago..).group(:subject_type).count
end

# Longer cache for expensive computations
Rails.cache.fetch([self, "monthly_metrics", month.beginning_of_month],
                  expires_in: 1.day) do
  calculate_monthly_metrics(month)
end

# Race condition protection for hot keys
Rails.cache.fetch([self, "hot_key"],
                  expires_in: 1.hour,
                  race_condition_ttl: 10.seconds) do
  expensive_operation
end
```

## Strategy 6: Version-Based Busting

When you change the shape of cached data, increment the version to invalidate
all existing entries without waiting for expiry.

```ruby
class Board < ApplicationRecord
  STATS_VERSION = 2  # Increment to bust all caches

  def statistics
    Rails.cache.fetch([self, "statistics", "v#{STATS_VERSION}"],
                      expires_in: 1.hour) do
      calculate_statistics
    end
  end
end
```

## CacheHelper Concern

Standardize cache options across models:

```ruby
module CacheHelper
  extend ActiveSupport::Concern

  class_methods do
    def cache_fetch(key, **options, &block)
      Rails.cache.fetch(
        [name.underscore, key],
        **default_cache_options.merge(options),
        &block
      )
    end

    def default_cache_options
      { expires_in: 1.hour, race_condition_ttl: 5.seconds }
    end
  end

  def cache_fetch(key, **options, &block)
    Rails.cache.fetch(
      [self, key],
      **self.class.default_cache_options.merge(options),
      &block
    )
  end
end

# Usage
class Board < ApplicationRecord
  include CacheHelper

  def statistics
    cache_fetch("statistics") { calculate_statistics }
  end
end
```

## Testing Cache Invalidation

```ruby
test "touching card updates board updated_at" do
  board = boards(:design)
  card = cards(:one)

  assert_changes -> { board.reload.updated_at } do
    card.touch
  end
end

test "statistics are cached" do
  board = boards(:design)
  assert_queries(5) { board.statistics }
  assert_no_queries { board.statistics }
end

test "statistics cache is cleared after card update" do
  board = boards(:design)
  board.statistics  # warm cache

  cards(:one).update!(title: "New title")
  assert_nil Rails.cache.read([board, "statistics"])
end
```
