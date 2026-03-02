---
name: database-migrations
description: >-
  Creates safe database migrations with proper indexes and rollback strategies.
  Use when creating tables, adding columns, creating indexes, handling
  zero-downtime migrations, or when user mentions migrations, schema changes,
  or database structure.
license: MIT
compatibility: Ruby 3.3+, Rails 8.1+, PostgreSQL or SQLite
metadata:
  author: ThibautBaissac
  version: "1.0"
---

# Database Migration Patterns for Rails 8

## Overview

Safe database migrations are critical for production stability:
- Zero-downtime deployments
- Reversible migrations
- Proper indexing
- Data integrity constraints
- Performance considerations

## Quick Start

```bash
# Generate migration
bin/rails generate migration AddStatusToEvents status:integer

# Run migrations
bin/rails db:migrate

# Rollback
bin/rails db:rollback

# Check status
bin/rails db:migrate:status
```

## Safety Checklist

```
Migration Safety:
- [ ] Migration is reversible (has down or uses change)
- [ ] Large tables use batching for updates
- [ ] Indexes added concurrently (if needed)
- [ ] Foreign keys have indexes
- [ ] NOT NULL added in two steps (for existing columns)
- [ ] Default values don't lock table
- [ ] Tested rollback locally
```

## Safe Migration Patterns

### Pattern 1: Add Column (Safe)

```ruby
# db/migrate/20240115000001_add_status_to_events.rb
class AddStatusToEvents < ActiveRecord::Migration[8.0]
  def change
    add_column :events, :status, :integer, default: 0, null: false
  end
end
```

### Pattern 2: Add Column with NOT NULL (Two-Step)

For existing tables with data, add NOT NULL in two migrations:

```ruby
# Step 1: Add column with default (allows NULL temporarily)
# db/migrate/20240115000001_add_priority_to_tasks.rb
class AddPriorityToTasks < ActiveRecord::Migration[8.0]
  def change
    add_column :tasks, :priority, :integer, default: 0
  end
end

# Step 2: Add NOT NULL constraint after backfill
# db/migrate/20240115000002_add_not_null_to_tasks_priority.rb
class AddNotNullToTasksPriority < ActiveRecord::Migration[8.0]
  def change
    change_column_null :tasks, :priority, false
  end
end
```

### Pattern 3: Add Index (Production Safe)

```ruby
# db/migrate/20240115000001_add_index_to_events_status.rb
class AddIndexToEventsStatus < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_index :events, :status, algorithm: :concurrently, if_not_exists: true
  end
end
```

### Pattern 4: Add Foreign Key with Index

```ruby
# db/migrate/20240115000001_add_account_to_events.rb
class AddAccountToEvents < ActiveRecord::Migration[8.0]
  def change
    add_reference :events, :account, null: false, foreign_key: true, index: true
  end
end
```

### Pattern 5: Rename Column (Safe)

```ruby
# db/migrate/20240115000001_rename_name_to_title_on_events.rb
class RenameNameToTitleOnEvents < ActiveRecord::Migration[8.0]
  def change
    rename_column :events, :name, :title
  end
end
```

### Pattern 6: Remove Column (Safe)

First, remove references in code, then migrate:

```ruby
# db/migrate/20240115000001_remove_legacy_field_from_events.rb
class RemoveLegacyFieldFromEvents < ActiveRecord::Migration[8.0]
  def change
    # safety_assured tells strong_migrations this is intentional
    safety_assured { remove_column :events, :legacy_field, :string }
  end
end
```

### Pattern 7: Add Enum Column

```ruby
# db/migrate/20240115000001_add_status_enum_to_orders.rb
class AddStatusEnumToOrders < ActiveRecord::Migration[8.0]
  def change
    # Use integer for Rails enum
    add_column :orders, :status, :integer, default: 0, null: false

    # Add index for queries
    add_index :orders, :status
  end
end
```

In model:
```ruby
class Order < ApplicationRecord
  enum :status, { pending: 0, confirmed: 1, shipped: 2, delivered: 3, cancelled: 4 }
end
```

## Dangerous Operations (Avoid)

### DON'T: Change Column Type Directly

```ruby
# DANGEROUS - can lose data or lock table
class ChangeColumnType < ActiveRecord::Migration[8.0]
  def change
    change_column :events, :budget, :decimal  # DON'T DO THIS
  end
end
```

### DO: Add New Column, Migrate Data, Remove Old

```ruby
# Step 1: Add new column
class AddBudgetDecimalToEvents < ActiveRecord::Migration[8.0]
  def change
    add_column :events, :budget_decimal, :decimal, precision: 10, scale: 2
  end
end

# Step 2: Backfill data (in a rake task or separate migration)
class BackfillEventsBudget < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def up
    Event.in_batches.update_all("budget_decimal = budget")
  end

  def down
    # Data migration, no rollback needed
  end
end

# Step 3: Remove old column (after code updated)
class RemoveOldBudgetFromEvents < ActiveRecord::Migration[8.0]
  def change
    safety_assured { remove_column :events, :budget, :integer }
    rename_column :events, :budget_decimal, :budget
  end
end
```

## Data Migrations

### Safe Backfill Pattern

```ruby
class BackfillEventStatus < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def up
    Event.unscoped.in_batches(of: 1000) do |batch|
      batch.where(status: nil).update_all(status: 0)
      sleep(0.1) # Reduce database load
    end
  end

  def down
    # No rollback for data migration
  end
end
```

### Using Background Job for Large Tables

```ruby
# Migration just adds column
class AddProcessedAtToEvents < ActiveRecord::Migration[8.0]
  def change
    add_column :events, :processed_at, :datetime
  end
end

# Separate job for backfill
class BackfillProcessedAtJob < ApplicationJob
  def perform(start_id, end_id)
    Event.where(id: start_id..end_id, processed_at: nil)
         .update_all(processed_at: Time.current)
  end
end

# Rake task to enqueue
# lib/tasks/backfill.rake
namespace :backfill do
  task processed_at: :environment do
    Event.in_batches(of: 10_000) do |batch|
      BackfillProcessedAtJob.perform_later(batch.minimum(:id), batch.maximum(:id))
    end
  end
end
```

## Index Strategies

### Composite Indexes

```ruby
# For queries: WHERE account_id = ? AND status = ?
add_index :events, [:account_id, :status]

# Order matters! This index helps:
# - WHERE account_id = ?
# - WHERE account_id = ? AND status = ?
# But NOT:
# - WHERE status = ?
```

### Partial Indexes

```ruby
# Index only active records
add_index :events, :event_date, where: "status = 0", name: "index_events_on_date_active"

# Index only non-null values
add_index :users, :reset_token, where: "reset_token IS NOT NULL"
```

### Unique Indexes

```ruby
# Unique constraint
add_index :users, :email, unique: true

# Unique within scope
add_index :event_vendors, [:event_id, :vendor_id], unique: true
```

## Foreign Keys

### Adding Foreign Keys

```ruby
class AddForeignKeys < ActiveRecord::Migration[8.0]
  def change
    # With automatic index
    add_reference :events, :venue, foreign_key: true

    # To existing column
    add_foreign_key :events, :accounts

    # With specific column name
    add_foreign_key :events, :users, column: :organizer_id
  end
end
```

### Foreign Key Options

```ruby
# ON DELETE CASCADE (delete children when parent deleted)
add_foreign_key :comments, :posts, on_delete: :cascade

# ON DELETE NULLIFY (set to NULL when parent deleted)
add_foreign_key :posts, :users, column: :author_id, on_delete: :nullify

# ON DELETE RESTRICT (prevent parent deletion)
add_foreign_key :orders, :users, on_delete: :restrict
```

## Strong Migrations Gem

### Installation

```ruby
# Gemfile
gem 'strong_migrations'
```

### Configuration

```ruby
# config/initializers/strong_migrations.rb
StrongMigrations.start_after = 20240101000000

# Target version for safe operations
StrongMigrations.target_version = 16  # PostgreSQL version

# Custom checks
StrongMigrations.add_check do |method, args|
  if method == :add_column && args[1] == :events
    stop! "Check with team before modifying events table"
  end
end
```

### Handling Warnings

```ruby
class AddColumnWithDefault < ActiveRecord::Migration[8.0]
  def change
    # Tell strong_migrations this is safe
    safety_assured do
      add_column :events, :priority, :integer, default: 0, null: false
    end
  end
end
```

## Reversible Migrations

### Using change (Automatic Reversal)

```ruby
class CreateEvents < ActiveRecord::Migration[8.0]
  def change
    create_table :events do |t|
      t.string :name, null: false
      t.date :event_date
      t.references :account, null: false, foreign_key: true
      t.timestamps
    end

    add_index :events, [:account_id, :event_date]
  end
end
```

### Using up/down (Manual Reversal)

```ruby
class ChangeEventsStructure < ActiveRecord::Migration[8.0]
  def up
    # Complex change
    execute <<-SQL
      ALTER TABLE events ADD CONSTRAINT check_positive_budget
      CHECK (budget_cents >= 0)
    SQL
  end

  def down
    execute <<-SQL
      ALTER TABLE events DROP CONSTRAINT check_positive_budget
    SQL
  end
end
```

### Irreversible Migrations

```ruby
class DropLegacyTable < ActiveRecord::Migration[8.0]
  def up
    drop_table :legacy_events
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "Cannot restore dropped table"
  end
end
```

## Testing Migrations

### Test Rollback

```bash
# Migrate and rollback
bin/rails db:migrate
bin/rails db:rollback
bin/rails db:migrate

# Check for issues
bin/rails db:migrate:status
```

### Schema Check

```ruby
# spec/db/schema_spec.rb
RSpec.describe "Database Schema" do
  it "has all foreign keys indexed" do
    foreign_keys = ActiveRecord::Base.connection.foreign_keys(:events)
    indexes = ActiveRecord::Base.connection.indexes(:events)

    foreign_keys.each do |fk|
      indexed = indexes.any? { |idx| idx.columns.first == fk.column }
      expect(indexed).to be(true), "Missing index for #{fk.column}"
    end
  end
end
```

## Performance Tips

### Avoid Table Locks

```ruby
# DON'T - Locks entire table
add_index :large_table, :column

# DO - Non-blocking
disable_ddl_transaction!
add_index :large_table, :column, algorithm: :concurrently
```

### Batch Operations

```ruby
# DON'T - Updates all at once
Event.update_all(status: 0)

# DO - Updates in batches
Event.in_batches(of: 1000) do |batch|
  batch.update_all(status: 0)
end
```

## Checklist

- [ ] Migration is reversible
- [ ] Indexes on foreign keys
- [ ] Concurrent index creation for large tables
- [ ] NOT NULL added safely (two-step)
- [ ] Data migrations use batching
- [ ] Tested rollback locally
- [ ] strong_migrations gem checks pass
- [ ] No table locks during deploy
