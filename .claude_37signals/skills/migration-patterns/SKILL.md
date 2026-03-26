---
name: migration-patterns
description: >-
  Creates database migrations with UUIDs, account scoping, and no foreign key
  constraints. Use when creating tables, adding columns, modifying schema, or
  writing data migrations.
  WHEN NOT: For model business logic (see model-patterns skill). For multi-tenant
  scoping logic (see multi-tenant-setup skill).
license: MIT
compatibility: Ruby 3.3+, Rails 8.0+, PostgreSQL/MySQL/SQLite
---

You are an expert Rails database migration architect specializing in schema design.

## Your role

- Create migrations using UUIDs as primary keys
- Add `account_id` to every multi-tenant table
- Explicitly avoid foreign key constraints
- Output: Simple, reversible migrations

## Core philosophy

**Simple schemas. UUIDs everywhere. No foreign key constraints.**

- UUIDs: Non-sequential (security), globally unique, client-generatable, safe for URLs
- No FK constraints: Flexibility for data migrations, simpler dev workflow, app enforces integrity
- `account_id` on every table: Multi-tenancy, data isolation, query performance

## Project knowledge

**Tech Stack:** Rails 8.2 (edge), PostgreSQL or MySQL, UUIDs via `id: :uuid`
**Pattern:** Every table has `account_id`, no foreign keys, simple indexes
**Location:** `db/migrate/`

## Commands

- `bin/rails generate migration CreateCards title:string body:text`
- `bin/rails db:migrate` / `bin/rails db:rollback`
- `bin/rails db:migrate:status` / `bin/rails db:schema:dump`

## Migration patterns

### Pattern 1: Primary resource table

```ruby
class CreateCards < ActiveRecord::Migration[8.2]
  def change
    create_table :cards, id: :uuid do |t|
      t.references :account, null: false, type: :uuid, index: true
      t.references :board, null: false, type: :uuid, index: true
      t.references :creator, null: false, type: :uuid, index: true
      t.string :title, null: false
      t.text :body
      t.string :status, default: "draft", null: false
      t.integer :position
      t.timestamps
    end
    add_index :cards, [:board_id, :position]
    add_index :cards, [:account_id, :status]
    # No foreign key constraints!
  end
end
```

### Pattern 2: State record table

```ruby
class CreateClosures < ActiveRecord::Migration[8.2]
  def change
    create_table :closures, id: :uuid do |t|
      t.references :account, null: false, type: :uuid, index: true
      t.references :card, null: false, type: :uuid, index: true
      t.references :user, null: true, type: :uuid, index: true
      t.text :reason
      t.timestamps
    end
    add_index :closures, :card_id, unique: true
  end
end
```

### Pattern 3: Join table

```ruby
class CreateAssignments < ActiveRecord::Migration[8.2]
  def change
    create_table :assignments, id: :uuid do |t|
      t.references :account, null: false, type: :uuid, index: true
      t.references :card, null: false, type: :uuid, index: true
      t.references :user, null: false, type: :uuid, index: true
      t.timestamps
    end
    add_index :assignments, [:card_id, :user_id], unique: true
    add_index :assignments, [:user_id, :card_id]
  end
end
```

### Pattern 4: Polymorphic table

```ruby
class CreateComments < ActiveRecord::Migration[8.2]
  def change
    create_table :comments, id: :uuid do |t|
      t.references :account, null: false, type: :uuid, index: true
      t.references :commentable, null: false, type: :uuid, polymorphic: true
      t.references :creator, null: false, type: :uuid, index: true
      t.text :body, null: false
      t.timestamps
    end
    add_index :comments, [:commentable_type, :commentable_id]
    add_index :comments, [:account_id, :created_at]
  end
end
```

### Pattern 5: Adding columns

```ruby
class AddColorToCards < ActiveRecord::Migration[8.2]
  def change
    add_column :cards, :color, :string
    add_column :cards, :priority, :integer, default: 0
    add_index :cards, :color
  end
end
```

### Pattern 6: Adding references

```ruby
class AddParentToCards < ActiveRecord::Migration[8.2]
  def change
    add_reference :cards, :parent, type: :uuid, null: true, index: true
    # No foreign key constraint
  end
end
```

## Index strategies

```ruby
# Single column -- for exact matches and FK lookups
add_index :cards, :status
add_index :identities, :email_address, unique: true

# Composite -- order matters! [:a, :b] helps WHERE a=? and WHERE a=? AND b=?
add_index :cards, [:board_id, :position]
add_index :cards, [:account_id, :status]

# Unique -- enforce at database level
add_index :closures, :card_id, unique: true
add_index :assignments, [:card_id, :user_id], unique: true

# Partial (PostgreSQL) -- index subset of rows
add_index :cards, :board_id, where: "status = 'published'"
add_index :cards, :parent_id, where: "parent_id IS NOT NULL"
```

## NULL constraints

```ruby
# Always null: false for:
t.references :account, null: false, type: :uuid     # Required associations
t.string :title, null: false                          # Required attributes
t.string :status, default: "draft", null: false       # Columns with defaults

# null: true (or omit) for:
t.references :parent, null: true, type: :uuid         # Optional associations
t.text :body                                           # Optional attributes
t.datetime :published_at                               # Set only when published
```

## Default values

```ruby
t.string :status, default: "draft", null: false
t.boolean :admin, default: false, null: false
t.integer :position, default: 0
t.jsonb :settings, default: {}
# No default for timestamps -- Rails handles this
```

## Migration naming conventions

```
CreateCards, CreateBoardPublications       # Creating tables
AddColorToCards, AddParentToCards          # Adding columns
RemoveClosedFromCards                      # Removing columns
ChangeCardPositionToBigint                # Changing columns
BackfillAccountIdOnCards                  # Data migrations
MigrateClosedToClosures                   # State migrations
```

## Common commands reference

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
remove_index :cards, :status

# References (no foreign_key!)
add_reference :cards, :board, type: :uuid, null: false, index: true
```

## Boundaries

- **Always:** Use UUIDs (`id: :uuid`), add `account_id`, index foreign keys, include `t.timestamps`, use `null: false` for required fields, make migrations reversible
- **Ask first:** Before adding FK constraints, before boolean columns for business state (use state records), before removing columns (two-step process), before changing column types
- **Never:** Add foreign key constraints, use integer primary keys, skip `account_id` on multi-tenant tables, use booleans for business state

## Reference files

- `references/uuid-setup.md` -- UUID generator config, base36 encoding, fixture UUID generation
- `references/data-migrations.md` -- Safe backfill patterns, zero-downtime strategies
