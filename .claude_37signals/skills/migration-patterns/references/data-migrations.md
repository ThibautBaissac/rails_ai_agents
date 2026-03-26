# Data Migrations Reference

## Safe backfill patterns

### Batch updates

```ruby
class BackfillAccountIdOnCards < ActiveRecord::Migration[8.2]
  def up
    Card.in_batches.each do |batch|
      batch.update_all(
        "account_id = (SELECT account_id FROM boards WHERE boards.id = cards.board_id)"
      )
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
```

### Boolean to state record migration

```ruby
class MigrateClosedToClosures < ActiveRecord::Migration[8.2]
  def up
    Card.where(closed: true).find_each do |card|
      Closure.create!(
        card: card,
        account: card.account,
        created_at: card.closed_at || card.updated_at
      )
    end
  end

  def down
    Closure.destroy_all
    Card.joins(:closure).update_all(closed: true)
  end
end
```

## Two-step column addition (zero downtime)

### Step 1: Add column without default

```ruby
class AddColorToCards < ActiveRecord::Migration[8.2]
  def change
    add_column :cards, :color, :string
  end
end
```

Deploy code that handles nil color first.

### Step 2: Backfill and add default

```ruby
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

## Safe column removal (two deploys)

### Deploy 1: Stop using the column in code

Ensure no code reads or writes the column. Add to `ignored_columns` if needed:

```ruby
class Card < ApplicationRecord
  self.ignored_columns += ["old_field"]
end
```

### Deploy 2: Remove the column

```ruby
class RemoveOldFieldFromCards < ActiveRecord::Migration[8.2]
  def change
    safety_assured do
      remove_column :cards, :old_field, :boolean
    end
  end
end
```

## Safe operations (no downtime needed)

```ruby
add_column :cards, :color, :string              # Adding columns
add_index :cards, :status, algorithm: :concurrently  # Concurrent index (PostgreSQL)
create_table :new_table, id: :uuid              # Creating tables
add_reference :cards, :parent, type: :uuid      # Adding references
```

## Unsafe operations (require extra care)

```ruby
# Removing columns -- two-step process above
remove_column :cards, :old_field

# Changing column types -- may lock table
change_column :cards, :position, :bigint

# Renaming columns -- alias in model first
rename_column :cards, :body, :description

# Adding NOT NULL to existing column -- backfill first
change_column_null :cards, :status, false
```

## Reversible vs irreversible

### Automatically reversible (use `def change`)

```ruby
def change
  create_table :cards, id: :uuid
  add_column :cards, :color, :string
  add_index :cards, :status
  rename_column :cards, :body, :description
end
```

### Manually reversible (use `def up` / `def down`)

```ruby
def up
  Card.where(status: "active").update_all(status: "published")
end

def down
  Card.where(status: "published").update_all(status: "active")
end
```

### Explicitly irreversible

```ruby
def up
  remove_column :cards, :old_field
end

def down
  raise ActiveRecord::IrreversibleMigration
end
```

## Removing foreign key constraints

If inheriting a project with FK constraints:

```ruby
class RemoveAllForeignKeyConstraints < ActiveRecord::Migration[8.2]
  def up
    foreign_keys = ActiveRecord::Base.connection.tables.flat_map do |table|
      ActiveRecord::Base.connection.foreign_keys(table)
    end

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

```ruby
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
