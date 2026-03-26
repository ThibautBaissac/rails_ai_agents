# State Record Examples

Complete examples of each state record type used in 37signals-style Rails applications.

## Closure (simple toggle state)

The most common state record. Tracks open/closed state.

### Migration

```ruby
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
```

### Model

```ruby
# app/models/closure.rb
class Closure < ApplicationRecord
  belongs_to :account, default: -> { card.account }
  belongs_to :card, touch: true
  belongs_to :user, optional: true

  validates :card, uniqueness: true

  after_create_commit :notify_watchers
  after_destroy_commit :notify_watchers

  private

  def notify_watchers
    card.notify_watchers_later
  end
end
```

### Concern

```ruby
# app/models/card/closeable.rb
module Card::Closeable
  extend ActiveSupport::Concern

  included do
    has_one :closure, dependent: :destroy

    scope :open, -> { where.missing(:closure) }
    scope :closed, -> { joins(:closure) }

    after_create_commit :track_card_created_event
  end

  def close(user: Current.user)
    create_closure!(user: user)
    track_event "card_closed", user: user
  end

  def reopen
    closure&.destroy!
    track_event "card_reopened"
  end

  def closed?
    closure.present?
  end

  def open?
    !closed?
  end

  def closed_at
    closure&.created_at
  end

  def closed_by
    closure&.user
  end

  private

  def track_card_created_event
    track_event "card_created" if open?
  end
end
```

## Publication (state with metadata)

State record with additional data like a public URL key.

### Migration

```ruby
class CreateBoardPublications < ActiveRecord::Migration[8.2]
  def change
    create_table :board_publications, id: :uuid do |t|
      t.references :account, null: false, type: :uuid
      t.references :board, null: false, type: :uuid
      t.string :key, null: false
      t.text :description

      t.timestamps
    end

    add_index :board_publications, :board_id, unique: true
    add_index :board_publications, :key, unique: true
  end
end
```

### Model

```ruby
# app/models/board/publication.rb
class Board::Publication < ApplicationRecord
  belongs_to :account, default: -> { board.account }
  belongs_to :board, touch: true

  has_secure_token :key

  validates :board, uniqueness: true

  def public_url
    Rails.application.routes.url_helpers.public_board_url(key)
  end
end
```

### Concern

```ruby
# app/models/board/publishable.rb
module Board::Publishable
  extend ActiveSupport::Concern

  included do
    has_one :publication, dependent: :destroy

    scope :published, -> { joins(:publication) }
    scope :private, -> { where.missing(:publication) }
  end

  def publish(description: nil)
    create_publication!(description: description)
    track_event "board_published"
  end

  def unpublish
    publication&.destroy!
    track_event "board_unpublished"
  end

  def published?
    publication.present?
  end

  def public_url
    publication&.public_url
  end

  def publication_key
    publication&.key
  end
end
```

## Goldness (marker state)

Simple marker with no metadata beyond timestamps.

### Migration

```ruby
class CreateCardGoldnesses < ActiveRecord::Migration[8.2]
  def change
    create_table :card_goldnesses, id: :uuid do |t|
      t.references :account, null: false, type: :uuid
      t.references :card, null: false, type: :uuid

      t.timestamps
    end

    add_index :card_goldnesses, :card_id, unique: true
  end
end
```

### Model

```ruby
# app/models/card/goldness.rb
class Card::Goldness < ApplicationRecord
  belongs_to :account, default: -> { card.account }
  belongs_to :card, touch: true

  validates :card, uniqueness: true
end
```

### Concern

```ruby
# app/models/card/golden.rb
module Card::Golden
  extend ActiveSupport::Concern

  included do
    has_one :goldness, dependent: :destroy

    scope :golden, -> { joins(:goldness) }
    scope :not_golden, -> { where.missing(:goldness) }
    scope :with_golden_first, -> {
      left_outer_joins(:goldness)
        .select("cards.*", "card_goldnesses.created_at as golden_at")
        .order(Arel.sql("golden_at IS NULL, golden_at DESC"))
    }
  end

  def gild
    create_goldness! unless golden?
    track_event "card_gilded"
  end

  def ungild
    goldness&.destroy!
    track_event "card_ungilded"
  end

  def golden?
    goldness.present?
  end

  def gilded_at
    goldness&.created_at
  end
end
```

## NotNow (marker with user tracking)

Tracks who postponed the card.

### Migration

```ruby
class CreateCardNotNows < ActiveRecord::Migration[8.2]
  def change
    create_table :card_not_nows, id: :uuid do |t|
      t.references :account, null: false, type: :uuid
      t.references :card, null: false, type: :uuid
      t.references :user, null: true, type: :uuid

      t.timestamps
    end

    add_index :card_not_nows, :card_id, unique: true
  end
end
```

### Model

```ruby
# app/models/card/not_now.rb
class Card::NotNow < ApplicationRecord
  belongs_to :account, default: -> { card.account }
  belongs_to :card, touch: true
  belongs_to :user, optional: true

  validates :card, uniqueness: true
end
```

### Concern

```ruby
# app/models/card/not_nowable.rb
module Card::NotNowable
  extend ActiveSupport::Concern

  included do
    has_one :not_now, dependent: :destroy

    scope :postponed, -> { joins(:not_now) }
    scope :active, -> { where.missing(:not_now) }
  end

  def postpone(user: Current.user)
    create_not_now!(user: user) unless postponed?
    track_event "card_postponed", user: user
  end

  def resume
    not_now&.destroy!
    track_event "card_resumed"
  end

  def postponed?
    not_now.present?
  end

  def postponed_at
    not_now&.created_at
  end

  def postponed_by
    not_now&.user
  end
end
```

## Archival (state with reason)

State record that captures why the action was taken.

### Migration

```ruby
class CreateCardArchivals < ActiveRecord::Migration[8.2]
  def change
    create_table :card_archivals, id: :uuid do |t|
      t.references :account, null: false, type: :uuid
      t.references :card, null: false, type: :uuid
      t.references :user, null: true, type: :uuid
      t.text :reason

      t.timestamps
    end

    add_index :card_archivals, :card_id, unique: true
  end
end
```

### Concern

```ruby
# app/models/card/archivable.rb
module Card::Archivable
  extend ActiveSupport::Concern

  included do
    has_one :archival, dependent: :destroy

    scope :archived, -> { joins(:archival) }
    scope :active, -> { where.missing(:archival) }
  end

  def archive(user: Current.user, reason: nil)
    create_archival!(user: user, reason: reason)
    track_event "card_archived", user: user, particulars: { reason: reason }
  end

  def unarchive
    archival&.destroy!
    track_event "card_unarchived"
  end

  def archived?
    archival.present?
  end

  def archival_reason
    archival&.reason
  end
end
```

## Common state records by domain

### Card states
- `Closure` -- card is closed
- `Card::Goldness` -- card is marked important
- `Card::NotNow` -- card is postponed
- `Card::Archival` -- card is archived

### Board states
- `Board::Publication` -- board is publicly published
- `Board::Archival` -- board is archived
- `Board::Lock` -- board is locked (read-only)

### User states
- `User::Suspension` -- user is suspended
- `User::Activation` -- user has activated account
- `User::Verification` -- user email is verified

### Project states
- `Project::Completion` -- project is completed
- `Project::Hold` -- project is on hold
- `Project::Cancellation` -- project is cancelled

## Testing state records

```ruby
class ClosureTest < ActiveSupport::TestCase
  test "closure belongs to card" do
    closure = closures(:logo_closed)
    assert_instance_of Card, closure.card
  end

  test "closure tracks who closed it" do
    closure = closures(:logo_closed)
    assert_instance_of User, closure.user
  end

  test "destroying closure notifies watchers" do
    closure = closures(:logo_closed)
    assert_enqueued_with job: NotifyWatchersJob do
      closure.destroy!
    end
  end
end

class Card::CloseableTest < ActiveSupport::TestCase
  setup do
    @card = cards(:logo)
    @user = users(:david)
  end

  test "close creates closure record" do
    assert_difference -> { Closure.count }, 1 do
      @card.close(user: @user)
    end
    assert @card.closed?
    assert_equal @user, @card.closed_by
  end

  test "reopen destroys closure record" do
    @card.close(user: @user)
    assert_difference -> { Closure.count }, -1 do
      @card.reopen
    end
    assert @card.open?
  end

  test "open scope excludes closed cards" do
    @card.close
    refute_includes Card.open, @card
    assert_includes Card.closed, @card
  end

  test "closed_at returns closure creation time" do
    freeze_time do
      @card.close
      assert_equal Time.current, @card.closed_at
    end
  end
end
```

## Migrating from boolean to state record

### Step 1: Create state record

```ruby
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
```

### Step 2: Backfill existing data

```ruby
class BackfillClosuresFromBoolean < ActiveRecord::Migration[8.2]
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
  end
end
```

### Step 3: Update model, include concern

### Step 4: Remove boolean column (after verification)

```ruby
class RemoveClosedFromCards < ActiveRecord::Migration[8.2]
  def change
    remove_column :cards, :closed, :boolean
    remove_column :cards, :closed_at, :datetime
  end
end
```
