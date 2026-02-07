---
name: 37signals-state-records
description: Implement "state as records, not booleans" pattern for rich state tracking. Triggers on state records, boolean to record, Closure, Publication, state tracking.
allowed-tools: Read, Write, Edit, Bash
---

# 37signals State Records Skill

## Overview

Replace boolean columns with separate state record models. Instead of `closed: boolean`, create a `Closure` record that tracks who, when, and why.

## Core Philosophy

Boolean columns give you:
- ✓ Current state

State records give you:
- ✓ Current state
- ✓ When it changed (created_at)
- ✓ Who changed it (user_id)
- ✓ Why it changed (reason)
- ✓ Change history

## Key Patterns

### Pattern 1: Simple Toggle (Closure)

```ruby
# Migration
class CreateClosures < ActiveRecord::Migration[8.2]
  def change
    create_table :closures, id: :uuid do |t|
      t.references :account, null: false, type: :uuid
      t.references :card, null: false, type: :uuid
      t.references :user, null: true, type: :uuid
      t.timestamps
    end
    add_index :closures, :card_id, unique: true
  end
end

# Model
class Closure < ApplicationRecord
  belongs_to :account, default: -> { card.account }
  belongs_to :card, touch: true
  belongs_to :user, optional: true

  validates :card, uniqueness: true
end

# Concern
module Card::Closeable
  extend ActiveSupport::Concern

  included do
    has_one :closure, dependent: :destroy
    scope :open, -> { where.missing(:closure) }
    scope :closed, -> { joins(:closure) }
  end

  def close(user: Current.user)
    create_closure!(user: user)
  end

  def reopen
    closure&.destroy!
  end

  def closed?
    closure.present?
  end

  def closed_at
    closure&.created_at
  end

  def closed_by
    closure&.user
  end
end
```

### Pattern 2: State with Metadata (Publication)

```ruby
class Board::Publication < ApplicationRecord
  belongs_to :board, touch: true
  has_secure_token :key  # Public URL key

  validates :board, uniqueness: true

  def public_url
    Rails.application.routes.url_helpers.public_board_url(key)
  end
end

module Board::Publishable
  extend ActiveSupport::Concern

  included do
    has_one :publication, dependent: :destroy
    scope :published, -> { joins(:publication) }
    scope :private, -> { where.missing(:publication) }
  end

  def publish(description: nil)
    create_publication!(description: description)
  end

  def unpublish
    publication&.destroy!
  end

  def published?
    publication.present?
  end
end
```

### Pattern 3: Marker State (Goldness)

```ruby
class Card::Goldness < ApplicationRecord
  belongs_to :card, touch: true
  validates :card, uniqueness: true
end

module Card::Golden
  extend ActiveSupport::Concern

  included do
    has_one :goldness, dependent: :destroy
    scope :golden, -> { joins(:goldness) }
    scope :not_golden, -> { where.missing(:goldness) }
  end

  def gild
    create_goldness! unless golden?
  end

  def ungild
    goldness&.destroy!
  end

  def golden?
    goldness.present?
  end
end
```

## Query Patterns

```ruby
# Finding by state
Card.open                    # where.missing(:closure)
Card.closed                  # joins(:closure)
Board.published              # joins(:publication)

# Complex combinations
scope :active, -> { open.where.missing(:not_now) }

# Sorting by state
scope :with_golden_first, -> {
  left_outer_joins(:goldness)
    .order(Arel.sql("card_goldnesses.created_at IS NULL, card_goldnesses.created_at DESC"))
}

# Filtering by actor
scope :closed_by, ->(user) { joins(:closure).where(closures: { user: user }) }
```

## CRUD Controllers

```ruby
# Routes
resources :cards do
  resource :closure, only: [:create, :destroy]
  resource :goldness, only: [:create, :destroy]
end

# Controller
class Cards::ClosuresController < ApplicationController
  def create
    @card.close(user: Current.user)
    redirect_to @card
  end

  def destroy
    @card.reopen
    redirect_to @card
  end
end
```

## Migration from Boolean

```ruby
# Step 1: Create state record table
class CreateClosures < ActiveRecord::Migration
  def change
    create_table :closures, id: :uuid do |t|
      t.references :card, null: false, type: :uuid
      t.references :user, type: :uuid
      t.timestamps
    end
    add_index :closures, :card_id, unique: true
  end
end

# Step 2: Backfill
class BackfillClosures < ActiveRecord::Migration
  def up
    Card.where(closed: true).find_each do |card|
      Closure.create!(
        card: card,
        account: card.account,
        created_at: card.closed_at || card.updated_at
      )
    end
  end
end

# Step 3: Remove boolean (after verification)
class RemoveClosedFromCards < ActiveRecord::Migration
  def change
    remove_column :cards, :closed, :boolean
    remove_column :cards, :closed_at, :datetime
  end
end
```

## When to Use

### Use State Records
- ✅ Need to know when state changed
- ✅ Need to know who changed it
- ✅ Might need metadata (reason, notes)
- ✅ State changes are important events

### Use Booleans
- ✅ State is purely technical (cached, processed)
- ✅ Timestamp doesn't matter
- ✅ Who changed it doesn't matter

## Common State Records

- `Closure` - item is closed
- `Publication` - item is published
- `Archival` - item is archived
- `Goldness` - item is marked important
- `NotNow` - item is postponed

## Boundaries

### Always
- Create state record for business states
- Track who and when
- Use `where.missing` for negative scopes
- Add unique index on parent_id
- Include account_id for multi-tenancy

### Never
- Use booleans for important business state
- Skip who/when tracking
- Create multiple state records per parent
- Forget to scope states by account
