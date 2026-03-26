# UUID Setup Reference

## PostgreSQL UUID extension

```ruby
# In first migration or db/migrate/xxx_enable_uuid_extension.rb
class EnableUuidExtension < ActiveRecord::Migration[8.2]
  def change
    enable_extension "pgcrypto"
  end
end
```

## Generator configuration

Set UUID as default primary key type globally:

```ruby
# config/initializers/generators.rb
Rails.application.config.generators do |g|
  g.orm :active_record, primary_key_type: :uuid
end
```

## Schema result

```ruby
# db/schema.rb
ActiveRecord::Schema[8.2].define(version: 2024_12_17_120000) do
  enable_extension "pgcrypto"

  create_table "cards", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.uuid "board_id", null: false
    t.string "title", null: false
    t.string "status", default: "draft", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "status"], name: "index_cards_on_account_id_and_status"
    t.index ["board_id"], name: "index_cards_on_board_id"
    # No foreign key constraints
  end
end
```

## Fixture UUID generation

Fixtures auto-generate UUIDs based on fixture name. You can also specify explicit UUIDs:

```yaml
# test/fixtures/cards.yml
logo:
  id: d0f1c2e3-4b5a-6789-0123-456789abcdef
  account: 37s
  board: projects
  title: "Design new logo"

# Or let Rails auto-generate (preferred)
shipping:
  account: 37s
  board: projects
  title: "Shipping feature"
```

When you need stable fixture IDs for cross-references, use explicit UUIDs. Otherwise, let Rails handle it.

## Base36 encoding (37signals pattern)

37signals uses base36-encoded UUIDv7 for shorter, URL-safe identifiers (25 characters):

```ruby
# lib/id_generator.rb
module IdGenerator
  def self.generate
    # UUIDv7 provides time-ordered UUIDs
    uuid = SecureRandom.uuid_v7
    # Convert to base36 for shorter representation
    uuid.delete("-").to_i(16).to_s(36).rjust(25, "0")
  end
end

# config/initializers/active_record.rb
ActiveRecord::Base.class_eval do
  before_create :set_id, if: -> { id.blank? }

  private

  def set_id
    self.id = IdGenerator.generate
  end
end
```

## Identity/session tables with UUID

```ruby
class CreateIdentities < ActiveRecord::Migration[8.2]
  def change
    create_table :identities, id: :uuid do |t|
      t.string :email_address, null: false
      t.string :password_digest
      t.timestamps
    end
    add_index :identities, :email_address, unique: true
  end
end

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

## Data type reference for UUID columns

```ruby
# All references must specify type: :uuid
t.references :account, null: false, type: :uuid, index: true
t.references :board, null: false, type: :uuid, index: true
t.references :creator, null: false, type: :uuid, index: true

# Self-referential
t.references :parent, null: true, type: :uuid, index: true

# Polymorphic
t.references :commentable, null: false, type: :uuid, polymorphic: true
```
