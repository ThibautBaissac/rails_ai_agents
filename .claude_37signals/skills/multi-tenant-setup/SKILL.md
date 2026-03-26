---
name: multi-tenant-setup
description: >-
  Implements URL-based multi-tenancy with account scoping, membership patterns,
  and data isolation following 37signals patterns. Use when setting up
  multi-tenant architecture, account isolation, membership management, or when
  user mentions multi-tenancy, accounts, or tenant separation.
  WHEN NOT: For basic model setup without tenancy (use model-patterns), for
  auth/session setup (use auth-setup).
license: MIT
compatibility: Ruby 3.3+, Rails 8.0+
---

# Multi-Tenant Setup

## Philosophy: URL-Based Multi-Tenancy, Not Subdomain or Schema

- URL-based: `app.myapp.com/123/boards/456` (account_id in path)
- `account_id` on every table (no foreign key constraints)
- `Current.account` set from URL params for all requests
- All queries scoped through `Current.account`
- UUIDs everywhere (prevents enumeration attacks)
- No default scopes (explicit scoping preferred)
- No Apartment gem, no subdomain routing, no schema separation

## Project Knowledge

**Stack:** URL-based multi-tenancy (`/accounts/:account_id/...`), Current
attributes for account/user context, UUIDs for all primary keys, single
database with single schema.

**Auth:** Custom passwordless with `Current.user`, users can belong to multiple
accounts, account membership controls access.

**Commands:**
```bash
rails generate model Account name:string
rails generate model Membership user:references account:references role:integer
rails generate migration AddAccountToCards account:references
```

## Pattern 1: Account Model and Memberships

See @references/membership-patterns.md for full details.

```ruby
# app/models/account.rb
class Account < ApplicationRecord
  has_many :memberships, dependent: :destroy
  has_many :users, through: :memberships

  has_many :boards, dependent: :destroy
  has_many :cards, dependent: :destroy

  validates :name, presence: true, length: { maximum: 100 }

  def member?(user)
    users.exists?(user.id)
  end

  def add_member(user, role: :member)
    memberships.find_or_create_by!(user: user) do |membership|
      membership.role = role
    end
  end

  def owner
    memberships.owner.first&.user
  end
end

# app/models/membership.rb
class Membership < ApplicationRecord
  belongs_to :user
  belongs_to :account

  enum :role, { member: 0, admin: 1, owner: 2 }

  validates :user_id, uniqueness: { scope: :account_id }
  validates :role, presence: true

  scope :active, -> { where(active: true) }
end

# app/models/user.rb
class User < ApplicationRecord
  has_many :memberships, dependent: :destroy
  has_many :accounts, through: :memberships

  def member_of?(account)
    accounts.exists?(account.id)
  end

  def role_in(account)
    memberships.find_by(account: account)&.role
  end

  def admin_of?(account)
    memberships.find_by(account: account)&.admin? ||
      memberships.find_by(account: account)&.owner?
  end
end
```

## Pattern 2: Current Attributes for Request Context

```ruby
# app/models/current.rb
class Current < ActiveSupport::CurrentAttributes
  attribute :user, :account, :membership

  delegate :admin?, :owner?, to: :membership, allow_nil: true, prefix: true

  def member?
    membership.present?
  end

  def can_edit?(resource)
    return false unless member?
    return true if membership_admin? || membership_owner?
    resource.respond_to?(:creator) && resource.creator == user
  end
end

# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  before_action :authenticate_user!
  before_action :set_current_account
  before_action :set_current_membership
  before_action :ensure_account_member

  private

  def set_current_account
    if params[:account_id]
      Current.account = current_user.accounts.find(params[:account_id])
    end
  rescue ActiveRecord::RecordNotFound
    redirect_to accounts_path, alert: "Account not found or access denied"
  end

  def set_current_membership
    if Current.account
      Current.membership = current_user.memberships.find_by(
        account: Current.account
      )
    end
  end

  def ensure_account_member
    return unless Current.account
    unless Current.member?
      redirect_to accounts_path, alert: "You don't have access"
    end
  end

  def require_admin!
    unless Current.membership_admin?
      redirect_to account_path(Current.account), alert: "Admin access required"
    end
  end
end
```

## Pattern 3: URL-Based Routing

```ruby
# config/routes.rb
Rails.application.routes.draw do
  # Auth (no account context)
  resource :session, only: [:new, :create, :destroy]

  # Account selection
  resources :accounts, only: [:index, :new, :create]

  # All routes within account context
  scope "/:account_id" do
    resource :account, only: [:show, :edit, :update, :destroy]
    resources :memberships, only: [:index, :create, :destroy]

    resources :boards do
      resources :cards do
        resources :comments, only: [:create, :destroy]
        resource :closure, only: [:create, :destroy]
      end
    end

    resources :activities, only: [:index]
    root "dashboards#show", as: :account_root
  end

  root "accounts#index"
end
```

Path helpers:
```ruby
account_boards_path(@account)           # => /123/boards
account_board_path(@account, @board)    # => /123/boards/456
account_board_cards_path(@account, @board) # => /123/boards/456/cards
```

## Pattern 4: Account-Scoped Models

See @references/account-scoping.md for full details.

```ruby
# app/models/concerns/account_scoped.rb
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

# Usage
class Board < ApplicationRecord
  include AccountScoped

  belongs_to :creator, class_name: "User"
  has_many :cards, dependent: :destroy

  validates :name, presence: true
end

# Child models inherit account from parent
class Card < ApplicationRecord
  include AccountScoped

  belongs_to :board

  validate :account_matches_board

  private

  def set_account_from_current
    self.account ||= board&.account || Current.account
  end

  def account_matches_board
    if board && account_id != board.account_id
      errors.add(:account_id, "must match board's account")
    end
  end
end
```

## Pattern 5: Account-Scoped Controllers

```ruby
class BoardsController < ApplicationController
  def index
    @boards = Current.account.boards.includes(:creator).recent
  end

  def show
    @board = Current.account.boards.find(params[:id])
  end

  def create
    @board = Current.account.boards.build(board_params)
    @board.creator = Current.user

    if @board.save
      redirect_to account_board_path(Current.account, @board)
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def board_params
    params.require(:board).permit(:name, :description)
  end
end

class CardsController < ApplicationController
  before_action :set_board

  def create
    @card = @board.cards.build(card_params)
    @card.creator = Current.user
    @card.account = Current.account  # Explicit setting

    if @card.save
      redirect_to account_board_card_path(Current.account, @board, @card)
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def set_board
    @board = Current.account.boards.find(params[:board_id])
  end
end
```

## Pattern 6: Account Switching

```ruby
class AccountsController < ApplicationController
  skip_before_action :set_current_account, only: [:index, :new, :create]
  skip_before_action :ensure_account_member, only: [:index, :new, :create]

  def index
    @accounts = current_user.accounts.order(:name)

    if @accounts.size == 1
      redirect_to account_root_path(@accounts.first)
    end
  end

  def create
    @account = Account.new(account_params)

    if @account.save
      @account.add_member(current_user, role: :owner)
      redirect_to account_root_path(@account)
    else
      render :new, status: :unprocessable_entity
    end
  end
end
```

## Pattern 7: Data Isolation and Security

```ruby
# app/models/concerns/account_isolation.rb
module AccountIsolation
  extend ActiveSupport::Concern

  included do
    validate :validate_account_consistency, on: :create
  end

  private

  def validate_account_consistency
    self.class.reflect_on_all_associations(:belongs_to).each do |assoc|
      next if assoc.name == :account
      related = send(assoc.name)
      next unless related
      if related.respond_to?(:account_id) && related.account_id != account_id
        errors.add(assoc.name, "must belong to the same account")
      end
    end
  end
end

# Controller security
module AccountSecurity
  extend ActiveSupport::Concern

  included do
    rescue_from ActiveRecord::RecordNotFound, with: :record_not_found
  end

  private

  def record_not_found
    redirect_to account_root_path(Current.account),
                alert: "Resource not found"
  end
end
```

## Pattern 8: Account Migrations

```ruby
class AddAccountToCards < ActiveRecord::Migration[8.0]
  def change
    add_reference :cards, :account, type: :uuid, null: true

    reversible do |dir|
      dir.up do
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

## Boundaries

### Always
- Use URL-based multi-tenancy (`/:account_id/...`)
- Put `account_id` on every table
- Scope all queries through `Current.account`
- Validate account consistency across associations
- Use UUIDs for all primary keys
- Set `Current.account` from URL in `ApplicationController`
- Double-scope nested resources (through account AND parent)

### Ask First
- Whether to use account slugs vs numeric IDs in URLs
- Cross-account reference patterns (integrations, webhooks)
- Account creation flow and initial setup

### Never
- Use subdomain-based multi-tenancy
- Use schema-based multi-tenancy (Apartment gem)
- Use `default_scope` for account filtering
- Set `Current.account` from user's default account (use URL)
- Skip `account_id` on any table
- Allow cross-account data access without explicit authorization
