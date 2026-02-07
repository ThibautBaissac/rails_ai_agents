---
name: 37signals-multi-tenant
description: Implement URL-based multi-tenancy with account scoping and Current attributes. Triggers on multi-tenant, account, tenant, scoping, Current.account.
allowed-tools: Read, Write, Edit, Bash
---

# 37signals Multi-Tenant Skill

## Overview

Implement URL-based multi-tenancy where account_id appears in the URL path, Current.account is set from URL params, and all queries scope through the account.

## Core Philosophy

- **URL-based**: `/accounts/123/boards` (not subdomain-based)
- **account_id everywhere**: Every table has account_id column
- **Current.account from URL**: Not from session or user
- **Explicit scoping**: No default_scope, always scope through Current.account
- **UUIDs**: Prevent enumeration attacks

## Key Patterns

### Pattern 1: Account and Membership Models

```ruby
class Account < ApplicationRecord
  has_many :memberships, dependent: :destroy
  has_many :users, through: :memberships
  has_many :boards, dependent: :destroy
  has_many :cards, dependent: :destroy

  validates :name, presence: true

  def member?(user)
    users.exists?(user.id)
  end

  def add_member(user, role: :member)
    memberships.find_or_create_by!(user: user) { |m| m.role = role }
  end
end

class Membership < ApplicationRecord
  belongs_to :user
  belongs_to :account

  enum :role, { member: 0, admin: 1, owner: 2 }

  validates :user_id, uniqueness: { scope: :account_id }
end
```

### Pattern 2: Current Attributes

```ruby
class Current < ActiveSupport::CurrentAttributes
  attribute :user, :account, :membership

  delegate :admin?, :owner?, to: :membership, allow_nil: true, prefix: true

  def member?
    membership.present?
  end

  def can_edit?(resource)
    return false unless member?
    return true if membership_admin?
    resource.respond_to?(:creator) && resource.creator == user
  end
end
```

### Pattern 3: Application Controller

```ruby
class ApplicationController < ActionController::Base
  before_action :authenticate_user!
  before_action :set_current_account
  before_action :ensure_account_member

  private

  def set_current_account
    if params[:account_id]
      Current.account = current_user.accounts.find(params[:account_id])
      Current.membership = current_user.memberships.find_by(account: Current.account)
    end
  rescue ActiveRecord::RecordNotFound
    redirect_to accounts_path, alert: "Account not found"
  end

  def ensure_account_member
    return unless Current.account
    redirect_to accounts_path unless Current.member?
  end

  def require_admin!
    redirect_to account_path(Current.account) unless Current.membership_admin?
  end
end
```

### Pattern 4: URL-Based Routes

```ruby
Rails.application.routes.draw do
  resources :accounts, only: [:index, :new, :create]

  scope "/:account_id" do
    resource :account, only: [:show, :edit, :update]
    resources :memberships, only: [:index, :create, :destroy]

    resources :boards do
      resources :cards
    end

    root "dashboards#show", as: :account_root
  end

  root "accounts#index"
end
```

### Pattern 5: Account-Scoped Models

```ruby
class Board < ApplicationRecord
  belongs_to :account
  belongs_to :creator, class_name: "User"

  validates :account_id, presence: true

  before_validation :set_account, on: :create

  private

  def set_account
    self.account ||= Current.account
  end
end

# Concern for reuse
module AccountScoped
  extend ActiveSupport::Concern

  included do
    belongs_to :account
    validates :account_id, presence: true
    before_validation :set_account_from_current, on: :create
  end

  private

  def set_account_from_current
    self.account ||= Current.account
  end
end
```

### Pattern 6: Account-Scoped Controllers

```ruby
class BoardsController < ApplicationController
  def index
    @boards = Current.account.boards.includes(:creator)
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
```

### Pattern 7: Account Switching

```ruby
class AccountsController < ApplicationController
  skip_before_action :set_current_account, only: [:index, :new, :create]
  skip_before_action :ensure_account_member, only: [:index, :new, :create]

  def index
    @accounts = current_user.accounts

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
      render :new
    end
  end
end
```

## Path Helpers

```ruby
# Always include account
account_boards_path(Current.account)
account_board_path(Current.account, @board)
account_board_cards_path(Current.account, @board)

# In views
<%= link_to "Boards", account_boards_path(Current.account) %>
```

## Security

```ruby
# Always scope through Current.account
Current.account.boards.find(params[:id])  # ✅

# Never trust params directly
Board.find(params[:id])  # ❌ Security risk

# Validate account consistency
validate :account_matches_parent

def account_matches_parent
  if board && account_id != board.account_id
    errors.add(:account_id, "must match board's account")
  end
end
```

## Testing

```ruby
test "index scopes to current account" do
  other_board = Board.create!(account: accounts(:other), name: "Other")

  get account_boards_path(@account)

  assert_select "h2", text: boards(:one).name
  assert_select "h2", text: other_board.name, count: 0
end

test "cannot access board in other account" do
  other_board = Board.create!(account: accounts(:other), name: "Other")

  assert_raises ActiveRecord::RecordNotFound do
    get account_board_path(@account, other_board)
  end
end
```

## Boundaries

### Always
- Include account_id on every tenant-scoped table
- Use UUIDs for all IDs
- Scope all queries through Current.account
- Set Current.account from URL params
- Use URL-based routing: `/:account_id/boards`
- Validate account consistency across associations

### Never
- Use subdomain-based tenancy
- Use default_scope for account filtering
- Add foreign key constraints
- Set Current.account from user.account
- Allow access without checking account membership
