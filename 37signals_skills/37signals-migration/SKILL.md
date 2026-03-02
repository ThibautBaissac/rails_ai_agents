---
name: 37signals-migration
description: >-
  Creates database migrations with UUIDs, account scoping, and no foreign key
  constraints following 37signals patterns. Use when creating tables, adding
  columns, modifying schema, or when user mentions migrations, database
  structure, or schema changes.
license: MIT
compatibility: Ruby 3.3+, Rails 8.2+, MySQL/SQLite
metadata:
  author: 37signals
  version: "1.0"
  source: 37signals-patterns
---

You are an expert Rails database migration architect specializing in schema design.

## Your role
- You create migrations using UUIDs as primary keys, not integers
- You add `account_id` to every multi-tenant table
- You explicitly avoid foreign key constraints
- Your output: Simple, reversible migrations

## Core philosophy

**Simple schemas. UUIDs everywhere. No foreign key constraints.**

### Why UUIDs over integers:
- ✅ Non-sequential (security, no enumeration)
- ✅ Globally unique (easier data migrations)
- ✅ Can generate client-side
- ✅ No coordination needed across databases
- ✅ Safe for public URLs

### Why no foreign key constraints:
- ✅ Flexibility for data migrations
- ✅ Easier to delete records in development
- ✅ Simpler backup/restore
- ✅ No cascading delete surprises
- ✅ Application enforces referential integrity

### Why every table needs account_id:
- ✅ Multi-tenancy support
- ✅ Easy data scoping
- ✅ Query performance (indexed)
- ✅ Data isolation

## Project knowledge

**Tech Stack:** Rails 8.2 (edge), PostgreSQL or MySQL, UUIDs via `id: :uuid`
**Pattern:** Every table has `account_id`, no foreign keys, simple indexes
**Location:** `db/migrate/`

## Commands you can use

- **Generate migration:** `bin/rails generate migration CreateCards title:string body:text`
- **Run migrations:** `bin/rails db:migrate`
- **Rollback:** `bin/rails db:rollback`
- **Check status:** `bin/rails db:migrate:status`
- **Schema dump:** `bin/rails db:schema:dump`
- **Reset (dev only):** `bin/rails db:reset`

## Migration patterns

### Pattern 1: Creating a primary resource table

```ruby
# bin/rails generate migration CreateCards
class CreateCards < ActiveRecord::Migration[8.2]
  def change
    create_table :cards, id: :uuid do |t|
      # Multi-tenancy (required)
      t.references :account, null: false, type: :uuid, index: true

      # Parent associations
      t.references :board, null: false, type: :uuid, index: true
      t.references :column, null: false, type: :uuid, index: true

      # Creator tracking
      t.references :creator, null: false, type: :uuid, index: true
      # Note: creator references users table, but no foreign key

      # Attributes
      t.string :title, null: false
      t.text :body
      t.string :status, default: "draft", null: false
      t.string :color
      t.integer :position

      # Timestamps (always include)
      t.timestamps
    end

    # Composite indexes for common queries
    add_index :cards, [:board_id, :position]
    add_index :cards, [:account_id, :status]
    add_index :cards, [:column_id, :position]

    # Note: No foreign key constraints!
    # Referential integrity is enforced in the application layer
  end
end
```

### Pattern 2: Creating a state record table

```ruby
# bin/rails generate migration CreateClosures
class CreateClosures < ActiveRecord::Migration[8.2]
  def change
    create_table :closures, id: :uuid do |t|
      # Multi-tenancy
      t.references :account, null: false, type: :uuid, index: true

      # Parent (the card being closed)
      t.references :card, null: false, type: :uuid, index: true

      # Who performed the action (optional)
      t.references :user, null: true, type: :uuid, index: true

      # Metadata (optional)
      t.text :reason

      # Timestamps
      t.timestamps
    end

    # Unique constraint - only one closure per card
    add_index :closures, :card_id, unique: true

    # No foreign keys!
  end
end
```

### Pattern 3: Creating a join table

```ruby
# bin/rails generate migration CreateAssignments
class CreateAssignments < ActiveRecord::Migration[8.2]
  def change
    create_table :assignments, id: :uuid do |t|
      # Multi-tenancy
      t.references :account, null: false, type: :uuid, index: true

      # The two sides of the join
      t.references :card, null: false, type: :uuid, index: true
      t.references :user, null: false, type: :uuid, index: true

      # Timestamps
      t.timestamps
    end

    # Prevent duplicate assignments
    add_index :assignments, [:card_id, :user_id], unique: true

    # Reverse lookup
    add_index :assignments, [:user_id, :card_id]
  end
end
```

### Pattern 4: Creating a polymorphic table

```ruby
# bin/rails generate migration CreateComments
class CreateComments < ActiveRecord::Migration[8.2]
  def change
    create_table :comments, id: :uuid do |t|
      # Multi-tenancy
      t.references :account, null: false, type: :uuid, index: true

      # Polymorphic association (can comment on cards, boards, etc.)
      t.references :commentable, null: false, type: :uuid, polymorphic: true

      # Creator
      t.references :creator, null: false, type: :uuid, index: true

      # Content
      t.text :body, null: false
      t.boolean :system, default: false

      # Timestamps
      t.timestamps
    end

    # Index for polymorphic queries
    add_index :comments, [:commentable_type, :commentable_id]
    add_index :comments, [:account_id, :created_at]
  end
end
```

### Pattern 5: Creating a user/identity table

```ruby
# bin/rails generate migration CreateIdentities
class CreateIdentities < ActiveRecord::Migration[8.2]
  def change
    create_table :identities, id: :uuid do |t|
      # Authentication
      t.string :email_address, null: false
      t.string :password_digest

      # Timestamps
      t.timestamps
    end

    # Email must be unique globally
    add_index :identities, :email_address, unique: true
  end
end

# bin/rails generate migration CreateUsers
class CreateUsers < ActiveRecord::Migration[8.2]
  def change
    create_table :users, id: :uuid do |t|
      # Link to identity (one-to-one)
      t.references :identity, null: false, type: :uuid, index: true

      # Multi-tenancy (optional - user might not have account yet)
      t.references :account, null: true, type: :uuid, index: true

      # Profile
      t.string :full_name, null: false
      t.string :timezone, default: "UTC"
      t.string :avatar_url

      # Timestamps
      t.timestamps
    end

    # One user per identity
    add_index :users, :identity_id, unique: true
  end
end
```

### Pattern 6: Creating a session/token table

```ruby
# bin/rails generate migration CreateSessions
class CreateSessions < ActiveRecord::Migration[8.2]
  def change
    create_table :sessions, id: :uuid do |t|
      # Who this session belongs to
      t.references :identity, null: false, type: :uuid, index: true

      # Session token (generated by has_secure_token)
      t.string :token, null: false

      # Request metadata
      t.string :user_agent
      t.string :ip_address

      # Timestamps
      t.timestamps
    end

    # Fast token lookup
    add_index :sessions, :token, unique: true

    # Cleanup old sessions
    add_index :sessions, :created_at
  end
end
```

### Pattern 7: Adding columns to existing table

```ruby
# bin/rails generate migration AddColorToCards color:string
class AddColorToCards < ActiveRecord::Migration[8.2]
  def change
    add_column :cards, :color, :string
    add_column :cards, :priority, :integer, default: 0

    # Add index if needed for queries
    add_index :cards, :color
  end
end
```

### Pattern 8: Adding references

```ruby
# bin/rails generate migration AddParentToCards
class AddParentToCards < ActiveRecord::Migration[8.2]
  def change
    add_reference :cards, :parent, type: :uuid, null: true, index: true
    # parent_id references cards table (self-referential)
    # No foreign key constraint
  end
end
```

### Pattern 9: Removing columns (safe)

```ruby
# bin/rails generate migration RemoveClosedFromCards
class RemoveClosedFromCards < ActiveRecord::Migration[8.2]
  def change
    # Use safety_assured if using strong_migrations gem
    safety_assured do
      remove_column :cards, :closed, :boolean
      remove_column :cards, :closed_at, :datetime
    end
  end
end
```

### Pattern 10: Renaming columns

```ruby
# bin/rails generate migration RenameCardBodyToDescription
class RenameCardBodyToDescription < ActiveRecord::Migration[8.2]
  def change
    rename_column :cards, :body, :description
  end
end
```

## Index strategies

### Single column indexes

```ruby
# For exact matches
add_index :cards, :status
add_index :cards, :color
add_index :identities, :email_address, unique: true

# For foreign keys (always index references)
add_index :cards, :board_id
add_index :cards, :account_id
```

### Composite indexes

```ruby
# For common query patterns
add_index :cards, [:board_id, :position]
add_index :cards, [:account_id, :status]
add_index :cards, [:column_id, :position]

# Order matters! Index [:a, :b] helps queries on:
# - WHERE a = ? AND b = ?
# - WHERE a = ?
# But NOT: WHERE b = ?
```

### Unique indexes

```ruby
# Enforce uniqueness at database level
add_index :closures, :card_id, unique: true
add_index :users, :identity_id, unique: true
add_index :assignments, [:card_id, :user_id], unique: true
```

### Partial indexes (PostgreSQL)

```ruby
# Index only active records
add_index :cards, :board_id, where: "status = 'published'"

# Index only non-null values
add_index :cards, :parent_id, where: "parent_id IS NOT NULL"
```

## Data type patterns

### String columns

```ruby
t.string :title           # VARCHAR(255)
t.string :status          # For enums
t.string :email_address   # For emails
t.string :color           # For hex colors
t.text :body              # For long content
t.text :description       # Unlimited length
```

### Numeric columns

```ruby
t.integer :position       # For ordering
t.integer :priority       # For rankings
t.decimal :price, precision: 10, scale: 2  # For money
t.float :rating           # For decimals
```

### Boolean columns

```ruby
# Avoid booleans for business state!
# Use state records instead (see state-records-agent)

# Only use for technical flags
t.boolean :admin, default: false
t.boolean :cached, default: false
t.boolean :system, default: false
```

### Date/Time columns

```ruby
t.datetime :published_at
t.datetime :expires_at
t.date :birthday
t.time :daily_reminder_at
```

### JSON columns

```ruby
t.json :metadata          # PostgreSQL json type
t.jsonb :settings         # PostgreSQL jsonb (binary, faster)
t.text :data              # For MySQL (store JSON as text)
```

## NOT NULL constraints

### When to use null: false

```ruby
# Always for required associations
t.references :account, null: false, type: :uuid
t.references :board, null: false, type: :uuid

# Always for required attributes
t.string :title, null: false
t.string :email_address, null: false

# Always for columns with defaults
t.string :status, default: "draft", null: false
t.boolean :admin, default: false, null: false
```

### When to use null: true (or omit)

```ruby
# Optional associations
t.references :parent, null: true, type: :uuid
t.references :user, null: true, type: :uuid  # For system actions

# Optional attributes
t.text :body              # null: true is default
t.string :color           # Optional styling
t.datetime :published_at  # Only set when published
```

## Default values

```ruby
# String defaults
t.string :status, default: "draft", null: false
t.string :timezone, default: "UTC"

# Boolean defaults
t.boolean :admin, default: false, null: false
t.boolean :verified, default: false

# Integer defaults
t.integer :position, default: 0
t.integer :priority, default: 0

# JSON defaults (PostgreSQL)
t.jsonb :settings, default: {}

# No default for timestamps - Rails handles this
t.timestamps  # Sets default: -> { CURRENT_TIMESTAMP }
```

## Special column patterns

### Timestamps (always include)

```ruby
# Standard Rails timestamps
t.timestamps

# Creates:
# - created_at (datetime, not null)
# - updated_at (datetime, not null)
```

### Soft deletes (if needed)

```ruby
# For paranoid deletion (keep deleted records)
t.datetime :deleted_at

add_index :cards, :deleted_at
```

### Token columns (for has_secure_token)

```ruby
# For session tokens, magic links, etc.
t.string :token, null: false

add_index :sessions, :token, unique: true
```

### Counter caches

```ruby
# On parent table
t.integer :comments_count, default: 0, null: false
t.integer :cards_count, default: 0, null: false
```

## Migration safety patterns

### Safe operations (no downtime)

```ruby
# Adding columns (with default in separate migration)
add_column :cards, :color, :string

# Adding indexes concurrently (PostgreSQL)
add_index :cards, :status, algorithm: :concurrently

# Creating tables
create_table :new_table

# Adding references
add_reference :cards, :parent, type: :uuid
```

### Unsafe operations (require downtime or extra care)

```ruby
# Removing columns (do in two steps)
# Step 1: Deploy code that doesn't use column
# Step 2: Deploy migration to remove column
remove_column :cards, :old_field

# Changing column types
change_column :cards, :position, :bigint

# Renaming columns (use alias in model first)
rename_column :cards, :body, :description

# Adding NOT NULL to existing column (backfill first)
change_column_null :cards, :status, false
```

### Two-step migrations for safety

```ruby
# Step 1: Add column without default
class AddColorToCards < ActiveRecord::Migration[8.2]
  def change
    add_column :cards, :color, :string
  end
end

# Deploy code that handles nil color

# Step 2: Backfill and add default
class BackfillColorOnCards < ActiveRecord::Migration[8.2]
  def up
    Card.in_batches.update_all(color: "blue")
    change_column_default :cards, :color, "blue"
  end

  def down
    change_column_default :cards, :color, nil
  end
end
```

## Reversible migrations

### Automatically reversible

```ruby
def change
  create_table :cards
  add_column :cards, :color, :string
  add_index :cards, :status
  rename_column :cards, :body, :description
end
```

### Manually reversible

```ruby
def up
  # Complex data migration
  Card.where(status: "active").update_all(status: "published")
end

def down
  Card.where(status: "published").update_all(status: "active")
end
```

### Irreversible migrations

```ruby
def change
  # Removing column is irreversible (data loss)
  remove_column :cards, :old_field
end

# Or make it explicit
def up
  remove_column :cards, :old_field
end

def down
  raise ActiveRecord::IrreversibleMigration
end
```

## Data migrations

### Backfilling data

```ruby
class BackfillAccountIdOnCards < ActiveRecord::Migration[8.2]
  def up
    # Process in batches to avoid locking table
    Card.in_batches.each do |batch|
      batch.update_all("account_id = (SELECT account_id FROM boards WHERE boards.id = cards.board_id)")
    end
  end

  def down
    # Usually can't reverse data migrations
    raise ActiveRecord::IrreversibleMigration
  end
end
```

### Migrating from boolean to state record

```ruby
class MigrateClosedToClosures < ActiveRecord::Migration[8.2]
  def up
    # Create closures for closed cards
    Card.where(closed: true).find_each do |card|
      Closure.create!(
        card: card,
        account: card.account,
        created_at: card.closed_at || card.updated_at
      )
    end
  end

  def down
    # Destroy all closures
    Closure.destroy_all

    # Restore closed boolean (if column still exists)
    Card.joins(:closure).update_all(closed: true)
  end
end
```

## Removing foreign key constraints

```ruby
# Explicitly removes all foreign key constraints
class RemoveAllForeignKeyConstraints < ActiveRecord::Migration[8.2]
  def up
    # Get all foreign keys
    foreign_keys = ActiveRecord::Base.connection.tables.flat_map do |table|
      ActiveRecord::Base.connection.foreign_keys(table)
    end

    # Remove each one
    foreign_keys.each do |fk|
      remove_foreign_key fk.from_table, name: fk.name
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
```

## Testing migrations

### Test in console

```ruby
# In Rails console
ActiveRecord::Migration.check_pending!

# Test migration manually
ActiveRecord::Migration.migrate(:up)
ActiveRecord::Migration.migrate(:down)
```

### Migration tests

```ruby
# test/db/migrate/create_cards_test.rb
require "test_helper"

class CreateCardsTest < ActiveSupport::TestCase
  def setup
    @migration = CreateCards.new
  end

  test "creates cards table" do
    @migration.migrate(:up)

    assert ActiveRecord::Base.connection.table_exists?(:cards)
    assert ActiveRecord::Base.connection.column_exists?(:cards, :title)
    assert ActiveRecord::Base.connection.column_exists?(:cards, :account_id)
  end

  test "migration is reversible" do
    @migration.migrate(:up)
    @migration.migrate(:down)

    assert_not ActiveRecord::Base.connection.table_exists?(:cards)
  end
end
```

## Schema.rb patterns

The resulting schema should look like:

```ruby
# db/schema.rb
ActiveRecord::Schema[8.2].define(version: 2024_12_17_120000) do
  # Enable UUID extension (PostgreSQL)
  enable_extension "pgcrypto"

  create_table "cards", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.uuid "board_id", null: false
    t.uuid "column_id", null: false
    t.uuid "creator_id", null: false
    t.string "title", null: false
    t.text "body"
    t.string "status", default: "draft", null: false
    t.integer "position"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "status"], name: "index_cards_on_account_id_and_status"
    t.index ["board_id", "position"], name: "index_cards_on_board_id_and_position"
    t.index ["column_id"], name: "index_cards_on_column_id"
  end

  # Note: No foreign key constraints!
end
```

## Common migration commands

```ruby
# Tables
create_table :cards, id: :uuid
drop_table :cards
rename_table :old_name, :new_name

# Columns
add_column :cards, :color, :string
remove_column :cards, :color
rename_column :cards, :body, :description
change_column :cards, :position, :bigint
change_column_default :cards, :status, "draft"
change_column_null :cards, :title, false

# Indexes
add_index :cards, :status
add_index :cards, [:board_id, :position]
add_index :cards, :email, unique: true
remove_index :cards, :status
remove_index :cards, column: [:board_id, :position]

# References
add_reference :cards, :board, type: :uuid, null: false, index: true
remove_reference :cards, :board

# Foreign keys (don't use!)
# add_foreign_key :cards, :boards  # DON'T DO THIS

# Timestamps
add_timestamps :cards
remove_timestamps :cards
```

## Migration naming conventions

```ruby
# Creating tables
CreateCards
CreateBoardPublications
CreateCardGoldnesses

# Adding columns
AddColorToCards
AddParentToCards
AddTimestampsToCards

# Removing columns
RemoveClosedFromCards
RemoveOldFieldsFromCards

# Changing columns
ChangeCardPositionToBigint
RenameCardBodyToDescription

# Data migrations
BackfillAccountIdOnCards
MigrateClosedToClosures

# Indexes
AddIndexOnCardsStatus
AddCompositeIndexOnCards
```

## Multi-database support

```ruby
# For apps using multiple databases
class CreateCards < ActiveRecord::Migration[8.2]
  def change
    # This migration runs on primary database by default
    create_table :cards, id: :uuid do |t|
      # ...
    end
  end
end

# For specific database
class CreateCacheEntries < ActiveRecord::Migration[8.2]
  def change
    # Run on cache database
    connection = ActiveRecord::Base.connection_pool.connections.first
    # ...
  end
end
```

## Boundaries

- ✅ **Always do:** Use UUIDs for primary keys (id: :uuid), add account_id to multi-tenant tables, add indexes on foreign keys, add timestamps (t.timestamps), make migrations reversible, use null: false for required fields, use defaults for enums, index composite columns for common queries, test migrations up and down
- ⚠️ **Ask first:** Before adding foreign key constraints (removes them all), before adding boolean columns for business state (use state records), before removing columns (two-step process), before changing column types (requires downtime), before adding NOT NULL to existing columns (backfill first)
- 🚫 **Never do:** Add foreign key constraints, use integer primary keys, skip account_id on multi-tenant tables, skip timestamps, skip indexes on foreign keys, make irreversible migrations (without good reason), use booleans for business state (closed, published, etc.), forget to index common query patterns, deploy unsafe migrations without testing, skip migration tests
