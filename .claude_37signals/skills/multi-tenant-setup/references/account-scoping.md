# Account Scoping Reference

## AccountScoped Concern

Every model that stores tenant data includes this concern:

```ruby
module AccountScoped
  extend ActiveSupport::Concern

  included do
    belongs_to :account
    validates :account_id, presence: true

    before_validation :set_account_from_current, on: :create

    scope :for_account, ->(account) { where(account: account) }
  end

  private

  def set_account_from_current
    self.account ||= Current.account
  end
end
```

## Model Examples

### Top-Level Resource

```ruby
class Board < ApplicationRecord
  include AccountScoped

  belongs_to :creator, class_name: "User"
  has_many :cards, dependent: :destroy
  has_many :columns, dependent: :destroy

  validates :name, presence: true, length: { maximum: 100 }

  scope :recent, -> { order(created_at: :desc) }

  # Account is set automatically from Current.account
end
```

### Child Resource (Inherits Account)

```ruby
class Card < ApplicationRecord
  include AccountScoped

  belongs_to :board
  belongs_to :column
  belongs_to :creator, class_name: "User"

  has_many :comments, dependent: :destroy

  validates :title, presence: true, length: { maximum: 200 }

  # Ensure account matches parent's account
  validate :account_matches_board

  private

  # Override to inherit from parent
  def set_account_from_current
    self.account ||= board&.account || Current.account
  end

  def account_matches_board
    if board && account_id != board.account_id
      errors.add(:account_id, "must match board's account")
    end
  end
end

class Comment < ApplicationRecord
  include AccountScoped

  belongs_to :card
  belongs_to :creator, class_name: "User"

  validates :body, presence: true

  private

  def set_account_from_current
    self.account ||= card&.account || Current.account
  end
end
```

## Query Scoping

Always query through `Current.account`, never globally:

```ruby
# GOOD: Scoped through Current.account
@boards = Current.account.boards.includes(:creator).recent
@board = Current.account.boards.find(params[:id])

# GOOD: Nested resources scoped through parent
@board = Current.account.boards.find(params[:board_id])
@card = @board.cards.find(params[:id])  # Double-scoped

# BAD: Global query (data leak risk)
@board = Board.find(params[:id])
@cards = Card.where(status: :active)
```

## Data Isolation Enforcement

```ruby
module AccountIsolation
  extend ActiveSupport::Concern

  included do
    validate :validate_account_consistency, on: :create
  end

  private

  def validate_account_consistency
    self.class.reflect_on_all_associations(:belongs_to).each do |assoc|
      next if assoc.name == :account
      next unless assoc.options[:class_name]

      related = send(assoc.name)
      next unless related

      if related.respond_to?(:account_id) && related.account_id != account_id
        errors.add(assoc.name, "must belong to the same account")
      end
    end
  end
end

# Usage
class Card < ApplicationRecord
  include AccountScoped
  include AccountIsolation

  belongs_to :board
  belongs_to :column

  # Automatically validates:
  # - board.account_id == card.account_id
  # - column.account_id == card.account_id
end
```

## Migration Pattern

Adding `account_id` to an existing table:

```ruby
class AddAccountToCards < ActiveRecord::Migration[8.0]
  def change
    add_reference :cards, :account, type: :uuid, null: true

    reversible do |dir|
      dir.up do
        # Backfill from parent association
        execute <<-SQL
          UPDATE cards
          SET account_id = boards.account_id
          FROM boards
          WHERE cards.board_id = boards.id
        SQL

        change_column_null :cards, :account_id, false
      end
    end

    add_index :cards, [:account_id, :created_at]
    add_index :cards, [:account_id, :board_id]
  end
end
```

Batch migration for multiple tables:

```ruby
class AddAccountToMultipleTables < ActiveRecord::Migration[8.0]
  def change
    [:cards, :comments, :activities, :attachments].each do |table|
      add_reference table, :account, type: :uuid, null: true
      add_index table, [:account_id, :created_at]
    end

    reversible do |dir|
      dir.up do
        # Card gets account from board
        execute <<-SQL
          UPDATE cards
          SET account_id = boards.account_id
          FROM boards WHERE cards.board_id = boards.id
        SQL

        # Comment gets account from card
        execute <<-SQL
          UPDATE comments
          SET account_id = cards.account_id
          FROM cards WHERE comments.card_id = cards.id
        SQL

        # Make non-null after backfill
        [:cards, :comments, :activities, :attachments].each do |table|
          change_column_null table, :account_id, false
        end
      end
    end
  end
end
```

## Testing Account Scoping

```ruby
test "sets account from Current on create" do
  Current.account = accounts(:acme)
  board = Board.create!(name: "Test Board", creator: users(:alice))
  assert_equal accounts(:acme), board.account
end

test "validates presence of account_id" do
  board = Board.new(name: "Test", creator: users(:alice))
  assert_not board.valid?
  assert_includes board.errors[:account_id], "can't be blank"
end

test "validates account matches board" do
  card = Card.new(
    title: "Test",
    board: boards(:design),
    account: accounts(:globex),  # Different account!
    creator: users(:alice)
  )
  assert_not card.valid?
  assert_includes card.errors[:account_id], "must match board's account"
end

test "index scopes to current account" do
  get account_boards_path(accounts(:acme))
  assert_response :success
  # Boards from other accounts should not appear
end

test "show rejects boards from other accounts" do
  other_board = Board.create!(
    name: "Other", account: accounts(:globex), creator: users(:bob)
  )
  assert_raises ActiveRecord::RecordNotFound do
    get account_board_path(accounts(:acme), other_board)
  end
end
```
