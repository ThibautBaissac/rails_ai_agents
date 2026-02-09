---
name: 37signals-migration
description: Create simple migrations with UUIDs, proper account scoping, and no foreign keys. Triggers on migration, database, schema, add column, create table, index.
allowed-tools: Read, Write, Edit, Bash
---

# 37signals Migration Skill

## Overview

Create migrations using UUIDs as primary keys, adding account_id to every multi-tenant table, and explicitly avoiding foreign key constraints.

## Core Philosophy

- **UUIDs everywhere**: Non-sequential, globally unique, safe for URLs
- **No foreign keys**: Application enforces referential integrity
- **account_id on everything**: Multi-tenancy support on every table
- **Simple indexes**: Index foreign keys and common query patterns

## Key Patterns

### Pattern 1: Primary Resource Table

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
  end
end
```

### Pattern 2: State Record Table

```ruby
class CreateClosures < ActiveRecord::Migration[8.2]
  def change
    create_table :closures, id: :uuid do |t|
      t.references :account, null: false, type: :uuid, index: true
      t.references :card, null: false, type: :uuid
      t.references :user, null: true, type: :uuid, index: true
      t.text :reason

      t.timestamps
    end

    add_index :closures, :card_id, unique: true  # Only one closure per card
  end
end
```

### Pattern 3: Join Table

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

### Pattern 4: Polymorphic Table

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

### Pattern 5: Adding Columns

```ruby
class AddColorToCards < ActiveRecord::Migration[8.2]
  def change
    add_column :cards, :color, :string
    add_index :cards, :color
  end
end
```

### Pattern 6: Adding References

```ruby
class AddParentToCards < ActiveRecord::Migration[8.2]
  def change
    add_reference :cards, :parent, type: :uuid, null: true, index: true
    # No foreign key constraint!
  end
end
```

### Pattern 7: Session/Token Table

```ruby
class CreateSessions < ActiveRecord::Migration[8.2]
  def change
    create_table :sessions, id: :uuid do |t|
      t.references :identity, null: false, type: :uuid, index: true
      t.string :token, null: false
      t.string :user_agent
      t.string :ip_address

      t.timestamps
    end

    add_index :sessions, :token, unique: true
    add_index :sessions, :created_at
  end
end
```

## Index Strategies

```ruby
# Foreign keys (always index)
add_index :cards, :board_id

# Composite for common queries
add_index :cards, [:board_id, :position]
add_index :cards, [:account_id, :status]

# Unique constraints
add_index :closures, :card_id, unique: true
add_index :assignments, [:card_id, :user_id], unique: true
```

## Data Type Patterns

```ruby
# Strings
t.string :title           # VARCHAR(255)
t.string :status          # For enums
t.text :body              # Unlimited length

# With defaults
t.string :status, default: "draft", null: false
t.boolean :admin, default: false, null: false
t.integer :position, default: 0

# JSON (PostgreSQL)
t.jsonb :settings, default: {}
```

## Safe Migrations

```ruby
# Add column without default first
add_column :cards, :color, :string

# Then backfill and add default
Card.in_batches.update_all(color: "blue")
change_column_default :cards, :color, "blue"
```

## Commands

```bash
bin/rails generate migration CreateCards title:string
bin/rails generate migration AddColorToCards color:string
bin/rails db:migrate
bin/rails db:rollback
bin/rails db:migrate:status
```

## Boundaries

### Always
- Use UUIDs for primary keys (`id: :uuid`)
- Add `account_id` to multi-tenant tables
- Add indexes on foreign keys
- Include timestamps
- Make migrations reversible

### Never
- Add foreign key constraints
- Use integer primary keys
- Skip account_id on tenant tables
- Forget indexes on references
- Use booleans for business state (use state records)
