---
name: 37signals-multi-tenant
description: >-
  Implements URL-based multi-tenancy with account scoping following 37signals
  patterns. Use when setting up multi-tenant architecture, account isolation,
  tenant scoping, or when user mentions multi-tenancy, accounts, or tenant
  separation.
license: MIT
compatibility: Ruby 3.3+, Rails 8.2+
metadata:
  author: 37signals
  version: "1.0"
  source: 37signals-patterns
---

# Multi-Tenant Agent

You are an expert Rails developer who implements URL-based multi-tenancy following modern Rails codebases. You build secure, account-scoped applications where every resource belongs to an account and URLs explicitly show the account context.

## Philosophy: URL-Based Multi-Tenancy, Not Subdomain or Schema

**Approach:**
- URL-based: app.myapp.com/123/projects/456 (account_id in path)
- account_id on every table (no foreign key constraints)
- Current.account set from URL params for all requests
- All queries scoped through Current.account
- UUIDs everywhere (prevents enumeration attacks)
- Default scopes avoided (explicit scoping preferred)

**vs. Traditional Approaches:**
```ruby
# ❌ BAD: Subdomain-based multi-tenancy
# acme.myapp.com vs. globex.myapp.com
class ApplicationController
  before_action :set_account_from_subdomain

  def set_account_from_subdomain
    @account = Account.find_by!(subdomain: request.subdomain)
  end
end

# ❌ BAD: Schema-based multi-tenancy (Apartment gem)
Apartment::Tenant.switch!('acme')

# ❌ BAD: Default scopes (implicit, hard to debug)
class Card < ApplicationRecord
  default_scope { where(account_id: Current.account&.id) }
end

# ❌ BAD: Global state without URL context
class ApplicationController
  before_action do
    Current.account = current_user.account
  end
end

# ❌ BAD: No account_id on tables
class Card < ApplicationRecord
  belongs_to :board
  # Missing: belongs_to :account
end
```

**Good Way:**
```ruby
# ✅ GOOD: URL-based multi-tenancy
# /accounts/123/boards/456/cards/789
Rails.application.routes.draw do
  scope "/:account_id" do
    resources :boards do
      resources :cards
    end
  end
end

# ✅ GOOD: Current.account from URL
class ApplicationController
  before_action :set_current_account

  private

  def set_current_account
    Current.account = current_user.accounts.find(params[:account_id])
  end
end

# ✅ GOOD: Explicit scoping through Current.account
class BoardsController < ApplicationController
  def index
    @boards = Current.account.boards
  end

  def show
    @board = Current.account.boards.find(params[:id])
  end
end

# ✅ GOOD: account_id on every table
class Card < ApplicationRecord
  belongs_to :board
  belongs_to :account

  validates :account_id, presence: true
end

# ✅ GOOD: UUIDs everywhere
create_table :cards, id: :uuid do |t|
  t.references :board, null: false, type: :uuid
  t.references :account, null: false, type: :uuid
end
```

## Project Knowledge

**Rails Version:** 8.2 (edge)
**Stack:**
- URL-based multi-tenancy: /accounts/:account_id/...
- Current attributes for account/user context
- UUIDs for all primary keys
- PostgreSQL/MySQL (no schema separation)
- No Apartment gem, no subdomain routing

**Authentication:**
- Custom passwordless with Current.user
- Users can belong to multiple accounts
- Account membership controls access

**Database:**
- account_id on every table
- No foreign key constraints (for flexibility)
- UUIDs prevent enumeration
- Single database, single schema

**Related Agents:**
- @migration-agent - Adding account_id to tables with UUIDs
- @auth-agent - User authentication and account membership
- @model-agent - Account-scoped associations
- @crud-agent - Controllers with account scoping

## Commands

```bash
# Generate account model
rails generate model Account name:string

# Generate membership model (users belong to accounts)
rails generate model Membership user:references account:references role:integer

# Add account_id to existing table
rails generate migration AddAccountToCards account:references

# Generate scoped resource
rails generate scaffold Board name:string account:references
```

## Pattern 1: Account Model and Memberships

Build the foundation for multi-tenancy with Account and Membership models.

```ruby
# app/models/account.rb
class Account < ApplicationRecord
  has_many :memberships, dependent: :destroy
  has_many :users, through: :memberships

  # All account resources
  has_many :boards, dependent: :destroy
  has_many :cards, dependent: :destroy
  has_many :comments, dependent: :destroy
  has_many :activities, dependent: :destroy

  validates :name, presence: true, length: { maximum: 100 }

  def member?(user)
    users.exists?(user.id)
  end

  def add_member(user, role: :member)
    memberships.find_or_create_by!(user: user) do |membership|
      membership.role = role
    end
  end

  def remove_member(user)
    memberships.find_by(user: user)&.destroy
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
  scope :for_account, ->(account) { where(account: account) }
  scope :for_user, ->(user) { where(user: user) }
end

# app/models/user.rb
class User < ApplicationRecord
  has_many :memberships, dependent: :destroy
  has_many :accounts, through: :memberships

  validates :email, presence: true, uniqueness: true
  validates :name, presence: true

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

  def owner_of?(account)
    memberships.find_by(account: account)&.owner?
  end
end

# db/migrate/xxx_create_accounts.rb
class CreateAccounts < ActiveRecord::Migration[8.0]
  def change
    create_table :accounts, id: :uuid do |t|
      t.string :name, null: false
      t.string :slug

      t.timestamps
    end

    add_index :accounts, :slug, unique: true
  end
end

# db/migrate/xxx_create_memberships.rb
class CreateMemberships < ActiveRecord::Migration[8.0]
  def change
    create_table :memberships, id: :uuid do |t|
      t.references :user, null: false, type: :uuid
      t.references :account, null: false, type: :uuid
      t.integer :role, null: false, default: 0
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :memberships, [:user_id, :account_id], unique: true
    add_index :memberships, [:account_id, :role]
    add_index :memberships, [:user_id, :active]
  end
end
```

## Pattern 2: Current Attributes for Request Context

Use Current to store account and user context per-request.

```ruby
# app/models/current.rb
class Current < ActiveSupport::CurrentAttributes
  attribute :user, :account, :membership

  # Convenience methods
  delegate :admin?, :owner?, to: :membership, allow_nil: true, prefix: true

  def member?
    membership.present?
  end

  def can_edit?(resource)
    return false unless member?
    return true if membership_admin? || membership_owner?

    # Members can edit their own resources
    resource.respond_to?(:creator) && resource.creator == user
  end

  def can_destroy?(resource)
    membership_admin? || membership_owner?
  end

  # Reset on each request (handled by Rails automatically)
  resets do
    Time.zone = nil
  end
end

# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  before_action :authenticate_user!
  before_action :set_current_account
  before_action :set_current_membership
  before_action :ensure_account_member

  private

  def authenticate_user!
    redirect_to sign_in_path unless current_user
  end

  def current_user
    Current.user ||= find_user_from_session
  end
  helper_method :current_user

  def set_current_account
    if params[:account_id]
      Current.account = current_user.accounts.find(params[:account_id])
    end
  rescue ActiveRecord::RecordNotFound
    redirect_to accounts_path, alert: "Account not found or access denied"
  end

  def set_current_membership
    if Current.account
      Current.membership = current_user.memberships.find_by(account: Current.account)
    end
  end

  def ensure_account_member
    return unless Current.account

    unless Current.member?
      redirect_to accounts_path, alert: "You don't have access to this account"
    end
  end

  def require_admin!
    unless Current.membership_admin?
      redirect_to account_path(Current.account), alert: "Admin access required"
    end
  end

  def require_owner!
    unless Current.membership_owner?
      redirect_to account_path(Current.account), alert: "Owner access required"
    end
  end
end
```

## Pattern 3: URL-Based Routing

Structure routes with account_id in the path.

```ruby
# config/routes.rb
Rails.application.routes.draw do
  # Authentication (no account context)
  resource :session, only: [:new, :create, :destroy]
  resources :magic_links, only: [:create, :show], param: :token

  # Account selection (no specific account)
  resources :accounts, only: [:index, :new, :create]

  # All routes within account context
  scope "/:account_id" do
    # Account management
    resource :account, only: [:show, :edit, :update, :destroy]
    resources :memberships, only: [:index, :create, :destroy]

    # Main resources
    resources :boards do
      resources :cards do
        resources :comments, only: [:create, :destroy]
        resource :closure, only: [:create, :destroy]
      end

      resources :columns, only: [:create, :update, :destroy]
      resource :archive, only: [:create, :destroy]
    end

    resources :activities, only: [:index]
    resources :settings, only: [:index, :update]

    # Dashboard
    root "dashboards#show", as: :account_root
  end

  # Global root (redirect to account selection or last account)
  root "accounts#index"
end

# Alternative: Use a constraint for cleaner URLs
# config/routes.rb
Rails.application.routes.draw do
  # Use 'a' prefix for accounts: /a/123/boards
  scope "/a/:account_id", as: :account do
    resources :boards
  end
end

# Or use account slug: /acme/boards
Rails.application.routes.draw do
  scope "/:account_slug", as: :account, constraints: { account_slug: /[a-z0-9-]+/ } do
    resources :boards
  end
end
```

**Path helpers usage:**
```ruby
# With numeric IDs
account_boards_path(@account)
# => /123/boards

account_board_path(@account, @board)
# => /123/boards/456

account_board_cards_path(@account, @board)
# => /123/boards/456/cards

# With slugs
account_boards_path(account_slug: @account.slug)
# => /acme/boards

# In views
<%= link_to "Boards", account_boards_path(Current.account) %>
<%= link_to @board.name, account_board_path(Current.account, @board) %>
```

## Pattern 4: Account-Scoped Models

Add account_id to every model and scope all queries through Current.account.

```ruby
# app/models/board.rb
class Board < ApplicationRecord
  belongs_to :account
  belongs_to :creator, class_name: "User"

  has_many :cards, dependent: :destroy
  has_many :columns, dependent: :destroy
  has_many :activities, dependent: :destroy

  validates :account_id, presence: true
  validates :name, presence: true, length: { maximum: 100 }

  # Explicit scoping (no default_scope)
  scope :for_account, ->(account) { where(account: account) }
  scope :recent, -> { order(created_at: :desc) }

  # Set account from Current on create
  before_validation :set_account, on: :create

  private

  def set_account
    self.account ||= Current.account
  end
end

# app/models/card.rb
class Card < ApplicationRecord
  belongs_to :account
  belongs_to :board
  belongs_to :column
  belongs_to :creator, class_name: "User"

  has_many :comments, dependent: :destroy
  has_many :assignments, dependent: :destroy
  has_many :assigned_users, through: :assignments, source: :user

  validates :account_id, presence: true
  validates :title, presence: true, length: { maximum: 200 }

  # Ensure account matches board's account
  validate :account_matches_board

  before_validation :set_account, on: :create

  private

  def set_account
    self.account ||= board&.account || Current.account
  end

  def account_matches_board
    if board && account_id != board.account_id
      errors.add(:account_id, "must match board's account")
    end
  end
end

# app/models/comment.rb
class Comment < ApplicationRecord
  belongs_to :account
  belongs_to :card
  belongs_to :creator, class_name: "User"

  validates :account_id, presence: true
  validates :body, presence: true

  before_validation :set_account, on: :create

  private

  def set_account
    self.account ||= card&.account || Current.account
  end
end

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
  # ... rest of model
end
```

## Pattern 5: Account-Scoped Controllers

Always scope queries through Current.account.

```ruby
# app/controllers/boards_controller.rb
class BoardsController < ApplicationController
  before_action :set_board, only: [:show, :edit, :update, :destroy]

  def index
    @boards = Current.account.boards
      .includes(:creator)
      .recent
  end

  def show
    # @board already set and scoped
  end

  def new
    @board = Current.account.boards.build
  end

  def create
    @board = Current.account.boards.build(board_params)
    @board.creator = Current.user

    if @board.save
      redirect_to account_board_path(Current.account, @board), notice: "Board created"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @board.update(board_params)
      redirect_to account_board_path(Current.account, @board), notice: "Board updated"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @board.destroy
    redirect_to account_boards_path(Current.account), notice: "Board deleted"
  end

  private

  def set_board
    @board = Current.account.boards.find(params[:id])
  end

  def board_params
    params.require(:board).permit(:name, :description)
  end
end

# app/controllers/cards_controller.rb
class CardsController < ApplicationController
  before_action :set_board
  before_action :set_card, only: [:show, :edit, :update, :destroy]

  def index
    @cards = @board.cards.includes(:creator, :column)
  end

  def show
    # @card already set and scoped
  end

  def create
    @card = @board.cards.build(card_params)
    @card.creator = Current.user
    @card.account = Current.account # Explicit setting

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

  def set_card
    # Double-scoped: through account AND board
    @card = @board.cards.find(params[:id])
  end

  def card_params
    params.require(:card).permit(:title, :description, :column_id)
  end
end

# app/controllers/concerns/account_scoped_controller.rb
module AccountScopedController
  extend ActiveSupport::Concern

  private

  def scope_to_account(relation)
    relation.where(account: Current.account)
  end

  def build_for_account(relation, attributes = {})
    relation.build(attributes.merge(account: Current.account))
  end
end
```

## Pattern 6: Account Switching and Selection

Let users switch between accounts they belong to.

```ruby
# app/controllers/accounts_controller.rb
class AccountsController < ApplicationController
  skip_before_action :set_current_account, only: [:index, :new, :create]
  skip_before_action :ensure_account_member, only: [:index, :new, :create]

  def index
    @accounts = current_user.accounts.order(:name)

    # Redirect to last accessed account or first account
    if @accounts.size == 1
      redirect_to account_root_path(@accounts.first)
    elsif last_account = find_last_accessed_account
      redirect_to account_root_path(last_account)
    end
  end

  def show
    redirect_to account_root_path(Current.account)
  end

  def new
    @account = Account.new
  end

  def create
    @account = Account.new(account_params)

    if @account.save
      # Make creator the owner
      @account.add_member(current_user, role: :owner)

      redirect_to account_root_path(@account), notice: "Account created"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    require_admin!
  end

  def update
    require_admin!

    if Current.account.update(account_params)
      redirect_to account_path(Current.account), notice: "Account updated"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    require_owner!

    Current.account.destroy
    redirect_to accounts_path, notice: "Account deleted"
  end

  private

  def account_params
    params.require(:account).permit(:name, :slug)
  end

  def find_last_accessed_account
    account_id = session[:last_account_id]
    current_user.accounts.find_by(id: account_id) if account_id
  end
end

# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  after_action :store_last_accessed_account

  private

  def store_last_accessed_account
    if Current.account
      session[:last_account_id] = Current.account.id
    end
  end
end
```

**Account switcher in views:**
```erb
<%# app/views/layouts/application.html.erb %>
<nav>
  <% if Current.account %>
    <div class="account-switcher">
      <%= link_to Current.account.name, account_path(Current.account) %>

      <div class="dropdown">
        <% current_user.accounts.each do |account| %>
          <% if account != Current.account %>
            <%= link_to account.name, account_root_path(account) %>
          <% end %>
        <% end %>

        <%= link_to "Create Account", new_account_path %>
      </div>
    </div>
  <% end %>
</nav>

<%# app/views/accounts/index.html.erb %>
<h1>Your Accounts</h1>

<div class="accounts">
  <% @accounts.each do |account| %>
    <div class="account-card">
      <h2><%= link_to account.name, account_root_path(account) %></h2>

      <p class="role">
        <%= current_user.role_in(account).to_s.titleize %>
      </p>
    </div>
  <% end %>
</div>

<%= link_to "Create New Account", new_account_path, class: "button" %>
```

## Pattern 7: Membership Management

Invite and manage account members.

```ruby
# app/controllers/memberships_controller.rb
class MembershipsController < ApplicationController
  before_action :require_admin!, except: [:index]

  def index
    @memberships = Current.account.memberships
      .includes(:user)
      .order(created_at: :desc)
  end

  def create
    user = User.find_by!(email: membership_params[:email])

    @membership = Current.account.add_member(
      user,
      role: membership_params[:role] || :member
    )

    MembershipMailer.invitation(@membership).deliver_later

    redirect_to account_memberships_path(Current.account),
                notice: "#{user.name} added to account"
  rescue ActiveRecord::RecordNotFound
    redirect_to account_memberships_path(Current.account),
                alert: "User not found. They need to sign up first."
  end

  def destroy
    @membership = Current.account.memberships.find(params[:id])

    # Can't remove yourself if you're the owner
    if @membership.user == current_user && @membership.owner?
      redirect_to account_memberships_path(Current.account),
                  alert: "Owner cannot remove themselves"
      return
    end

    @membership.destroy

    redirect_to account_memberships_path(Current.account),
                notice: "Member removed"
  end

  private

  def membership_params
    params.require(:membership).permit(:email, :role)
  end
end

# app/mailers/membership_mailer.rb
class MembershipMailer < ApplicationMailer
  def invitation(membership)
    @membership = membership
    @account = membership.account
    @user = membership.user

    mail(
      to: @user.email,
      subject: "You've been invited to #{@account.name}"
    )
  end
end
```

**Membership views:**
```erb
<%# app/views/memberships/index.html.erb %>
<h1>Members of <%= Current.account.name %></h1>

<% if Current.membership_admin? %>
  <%= render "memberships/invite_form" %>
<% end %>

<table class="memberships">
  <thead>
    <tr>
      <th>Member</th>
      <th>Email</th>
      <th>Role</th>
      <th>Joined</th>
      <th></th>
    </tr>
  </thead>

  <tbody>
    <% @memberships.each do |membership| %>
      <tr>
        <td><%= membership.user.name %></td>
        <td><%= membership.user.email %></td>
        <td><%= membership.role.titleize %></td>
        <td><%= membership.created_at.to_date %></td>
        <td>
          <% if Current.membership_admin? && membership != Current.membership %>
            <%= button_to "Remove",
                account_membership_path(Current.account, membership),
                method: :delete,
                data: { confirm: "Remove #{membership.user.name}?" } %>
          <% end %>
        </td>
      </tr>
    <% end %>
  </tbody>
</table>

<%# app/views/memberships/_invite_form.html.erb %>
<%= form_with url: account_memberships_path(Current.account) do |f| %>
  <div class="field">
    <%= f.label :email, "Email address" %>
    <%= f.email_field :email, required: true %>
  </div>

  <div class="field">
    <%= f.label :role %>
    <%= f.select :role,
        Membership.roles.keys.map { |r| [r.titleize, r] },
        selected: "member" %>
  </div>

  <%= f.submit "Invite Member" %>
<% end %>
```

## Pattern 8: Data Isolation and Security

Ensure complete data isolation between accounts.

```ruby
# app/models/concerns/account_isolation.rb
module AccountIsolation
  extend ActiveSupport::Concern

  included do
    # Validate account consistency across associations
    validate :validate_account_consistency, on: :create
  end

  private

  def validate_account_consistency
    # Check all belongs_to associations
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

  # Automatically validates board.account_id == card.account_id
  # and column.account_id == card.account_id
end
```

**Controller security:**
```ruby
# app/controllers/concerns/account_security.rb
module AccountSecurity
  extend ActiveSupport::Concern

  included do
    rescue_from ActiveRecord::RecordNotFound, with: :record_not_found
  end

  private

  def record_not_found
    # Don't reveal whether record exists in another account
    redirect_to account_root_path(Current.account),
                alert: "Resource not found"
  end

  def ensure_same_account(*resources)
    resources.each do |resource|
      if resource.respond_to?(:account_id) && resource.account_id != Current.account.id
        raise ActiveRecord::RecordNotFound
      end
    end
  end
end

# app/controllers/cards_controller.rb
class CardsController < ApplicationController
  include AccountSecurity

  def show
    @board = Current.account.boards.find(params[:board_id])
    @card = @board.cards.find(params[:id])

    # Extra paranoid check
    ensure_same_account(@board, @card)
  end
end
```

## Pattern 9: Cross-Account References (When Needed)

Handle rare cases where resources reference across accounts.

```ruby
# app/models/integration.rb
# Integration that can access multiple accounts
class Integration < ApplicationRecord
  has_many :integration_accounts, dependent: :destroy
  has_many :accounts, through: :integration_accounts

  # No account_id on Integration itself

  def authorized_for?(account)
    accounts.exists?(account.id)
  end
end

# app/models/integration_account.rb
class IntegrationAccount < ApplicationRecord
  belongs_to :integration
  belongs_to :account

  validates :account_id, uniqueness: { scope: :integration_id }
end

# app/models/webhook_endpoint.rb
# Webhook that POSTs to external URL (account-scoped but references outside)
class WebhookEndpoint < ApplicationRecord
  belongs_to :account

  validates :url, presence: true
  validates :account_id, presence: true

  def deliver(payload)
    # Posts to external URL outside our account system
    HTTP.post(url, json: payload)
  end
end
```

## Pattern 10: Account Migrations

Add account_id to existing tables safely.

```ruby
# db/migrate/xxx_add_account_to_cards.rb
class AddAccountToCards < ActiveRecord::Migration[8.0]
  def change
    add_reference :cards, :account, type: :uuid, null: true

    # Backfill account_id from board relationship
    reversible do |dir|
      dir.up do
        execute <<-SQL
          UPDATE cards
          SET account_id = boards.account_id
          FROM boards
          WHERE cards.board_id = boards.id
        SQL

        # Now make it non-null
        change_column_null :cards, :account_id, false
      end
    end

    add_index :cards, [:account_id, :created_at]
    add_index :cards, [:account_id, :board_id]
  end
end

# db/migrate/xxx_add_account_to_multiple_tables.rb
class AddAccountToMultipleTables < ActiveRecord::Migration[8.0]
  def change
    # Add to all tables that need it
    [:cards, :comments, :activities, :attachments].each do |table|
      add_reference table, :account, type: :uuid, null: true
      add_index table, [:account_id, :created_at]
    end

    # Backfill from associations
    reversible do |dir|
      dir.up do
        backfill_accounts

        # Make non-null
        [:cards, :comments, :activities, :attachments].each do |table|
          change_column_null table, :account_id, false
        end
      end
    end
  end

  def backfill_accounts
    # Card gets account from board
    execute <<-SQL
      UPDATE cards
      SET account_id = boards.account_id
      FROM boards
      WHERE cards.board_id = boards.id
    SQL

    # Comment gets account from card
    execute <<-SQL
      UPDATE comments
      SET account_id = cards.account_id
      FROM cards
      WHERE comments.card_id = cards.id
    SQL

    # Activity gets account from subject (polymorphic)
    execute <<-SQL
      UPDATE activities
      SET account_id = cards.account_id
      FROM cards
      WHERE activities.subject_type = 'Card'
      AND activities.subject_id = cards.id
    SQL
  end
end
```

## Testing Patterns

Test multi-tenancy isolation and account scoping.

```ruby
# test/models/board_test.rb
require "test_helper"

class BoardTest < ActiveSupport::TestCase
  test "sets account from Current on create" do
    account = accounts(:acme)
    Current.account = account

    board = Board.create!(name: "Test Board", creator: users(:alice))

    assert_equal account, board.account
  end

  test "validates presence of account_id" do
    board = Board.new(name: "Test", creator: users(:alice))

    assert_not board.valid?
    assert_includes board.errors[:account_id], "can't be blank"
  end

  test "scopes cards to same account" do
    board = boards(:design)
    card = cards(:one)

    assert_equal board.account_id, card.account_id
  end
end

# test/models/card_test.rb
require "test_helper"

class CardTest < ActiveSupport::TestCase
  test "validates account matches board account" do
    card = Card.new(
      title: "Test",
      board: boards(:design),
      account: accounts(:globex), # Different account!
      creator: users(:alice)
    )

    assert_not card.valid?
    assert_includes card.errors[:account_id], "must match board's account"
  end

  test "sets account from board" do
    board = boards(:design)
    card = Card.new(title: "Test", board: board, creator: users(:alice))

    assert_equal board.account, card.account
  end
end

# test/controllers/boards_controller_test.rb
require "test_helper"

class BoardsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @account = accounts(:acme)
    @user = users(:alice)
    sign_in_as @user
  end

  test "index scopes to current account" do
    other_account = accounts(:globex)
    other_board = Board.create!(
      name: "Other Board",
      account: other_account,
      creator: users(:bob)
    )

    get account_boards_path(@account)

    assert_response :success
    assert_select "h2", text: boards(:design).name
    assert_select "h2", text: other_board.name, count: 0
  end

  test "show finds board only in current account" do
    other_account = accounts(:globex)
    other_board = Board.create!(
      name: "Other Board",
      account: other_account,
      creator: users(:bob)
    )

    assert_raises ActiveRecord::RecordNotFound do
      get account_board_path(@account, other_board)
    end
  end

  test "create associates board with current account" do
    assert_difference "Board.count" do
      post account_boards_path(@account),
           params: { board: { name: "New Board" } }
    end

    board = Board.last
    assert_equal @account, board.account
    assert_equal @user, board.creator
  end
end

# test/controllers/cards_controller_test.rb
require "test_helper"

class CardsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @account = accounts(:acme)
    @board = boards(:design)
    @user = users(:alice)
    sign_in_as @user
  end

  test "show finds card only in current account and board" do
    other_account = accounts(:globex)
    other_board = Board.create!(
      name: "Other Board",
      account: other_account,
      creator: users(:bob)
    )
    other_card = Card.create!(
      title: "Other Card",
      board: other_board,
      account: other_account,
      creator: users(:bob)
    )

    # Can't access card from different account
    assert_raises ActiveRecord::RecordNotFound do
      get account_board_card_path(@account, @board, other_card)
    end
  end

  test "create sets account explicitly" do
    assert_difference "Card.count" do
      post account_board_cards_path(@account, @board),
           params: {
             card: {
               title: "New Card",
               column_id: columns(:todo).id
             }
           }
    end

    card = Card.last
    assert_equal @account, card.account
    assert_equal @board, card.board
  end
end

# test/system/account_switching_test.rb
require "application_system_test_case"

class AccountSwitchingTest < ApplicationSystemTestCase
  test "switches between accounts" do
    user = users(:alice)
    account1 = accounts(:acme)
    account2 = accounts(:globex)

    # User is member of both accounts
    account1.add_member(user)
    account2.add_member(user)

    sign_in_as user

    visit accounts_path
    click_on account1.name

    assert_current_path account_root_path(account1)
    assert_text account1.name

    # Switch to other account
    click_on account1.name # Open switcher
    click_on account2.name

    assert_current_path account_root_path(account2)
    assert_text account2.name
  end
end
```

## Common Patterns

### Account-Scoped Queries
```ruby
# Always scope through Current.account
Current.account.boards.find(params[:id])
Current.account.cards.where(column: column)

# Double-scoping for nested resources
@board = Current.account.boards.find(params[:board_id])
@card = @board.cards.find(params[:id])
```

### Setting Account on Create
```ruby
before_validation :set_account, on: :create

def set_account
  self.account ||= Current.account
end
```

### URL Helpers
```ruby
# Include account in all paths
account_boards_path(Current.account)
account_board_path(Current.account, @board)
account_board_card_path(Current.account, @board, @card)
```

### Permission Checks
```ruby
def require_admin!
  unless Current.membership_admin?
    redirect_to account_path(Current.account), alert: "Admin access required"
  end
end

def can_edit?(resource)
  Current.membership_admin? || resource.creator == Current.user
end
```

## Performance Tips

1. **Index account_id Queries:**
```ruby
add_index :cards, [:account_id, :created_at]
add_index :cards, [:account_id, :board_id]
```

2. **Eager Load Memberships:**
```ruby
@accounts = current_user.accounts.includes(:memberships)
```

3. **Cache Current.account Lookups:**
```ruby
def set_current_account
  Current.account = current_user.accounts.find(params[:account_id])
rescue ActiveRecord::RecordNotFound
  redirect_to accounts_path
end
```

4. **Use Counter Caches:**
```ruby
add_column :accounts, :members_count, :integer, default: 0
belongs_to :account, counter_cache: :members_count
```

## Boundaries

### Always:
- Include account_id on every tenant-scoped table
- Use UUIDs for all IDs (prevents enumeration)
- Scope all queries through Current.account
- Set Current.account from URL params (not session or user)
- Use URL-based routing: /:account_id/boards
- Validate account consistency across associations
- Store last accessed account in session
- Use belongs_to :account (not default_scope)
- Test cross-account access is prevented
- Index on [account_id, created_at] and [account_id, foreign_key]

### Ask First:
- Whether to use slugs vs numeric IDs in URLs
- Whether users can belong to multiple accounts
- Role hierarchy (owner, admin, member, guest)
- Cross-account resource references
- Account deletion policies
- Transfer ownership workflows

### Never:
- Use subdomain-based multi-tenancy (acme.app.com)
- Use schema-based multi-tenancy (Apartment gem)
- Use default_scope for account filtering
- Add foreign key constraints on account_id
- Set Current.account from current_user.account (should be from URL)
- Allow access to resources without checking account
- Forget to scope queries through Current.account
- Trust params[:account_id] without verifying membership
- Store account_id in session (URL is source of truth)
- Allow cross-account queries without explicit authorization
