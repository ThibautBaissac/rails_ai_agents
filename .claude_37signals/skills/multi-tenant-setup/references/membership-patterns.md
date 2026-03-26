# Membership Patterns Reference

## User/Account/Membership Triangle

Users connect to Accounts through Memberships. A user can belong to multiple
accounts, and each membership has a role.

```
User ----< Membership >---- Account
              |
            role: member | admin | owner
```

## Models

### Account

```ruby
class Account < ApplicationRecord
  has_many :memberships, dependent: :destroy
  has_many :users, through: :memberships

  # All account resources
  has_many :boards, dependent: :destroy
  has_many :cards, dependent: :destroy
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
```

### Membership

```ruby
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
```

### User

```ruby
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
```

## Migrations

```ruby
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

## Membership Management Controller

```ruby
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
```

## Board-Level Access

For resources that need per-board permissions beyond account roles:

```ruby
class BoardMembership < ApplicationRecord
  belongs_to :board
  belongs_to :user
  belongs_to :account

  enum :access_level, { viewer: 0, editor: 1, admin: 2 }

  validates :user_id, uniqueness: { scope: :board_id }
end

class Board < ApplicationRecord
  has_many :board_memberships, dependent: :destroy
  has_many :board_members, through: :board_memberships, source: :user

  def accessible_by?(user)
    board_members.exists?(user.id) || account.admin_of?(user)
  end

  def editable_by?(user)
    board_memberships.where(user: user, access_level: [:editor, :admin]).exists? ||
      account.admin_of?(user)
  end
end
```

## Account Switching

```ruby
class AccountsController < ApplicationController
  skip_before_action :set_current_account, only: [:index, :new, :create]
  skip_before_action :ensure_account_member, only: [:index, :new, :create]

  def index
    @accounts = current_user.accounts.order(:name)

    if @accounts.size == 1
      redirect_to account_root_path(@accounts.first)
    elsif last_account = find_last_accessed_account
      redirect_to account_root_path(last_account)
    end
  end

  def create
    @account = Account.new(account_params)

    if @account.save
      @account.add_member(current_user, role: :owner)
      redirect_to account_root_path(@account), notice: "Account created"
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def find_last_accessed_account
    account_id = session[:last_account_id]
    current_user.accounts.find_by(id: account_id) if account_id
  end
end

# Track last accessed account
class ApplicationController < ActionController::Base
  after_action :store_last_accessed_account

  private

  def store_last_accessed_account
    session[:last_account_id] = Current.account.id if Current.account
  end
end
```

## Membership Views

```erb
<%# app/views/memberships/index.html.erb %>
<h1>Members of <%= Current.account.name %></h1>

<% if Current.membership_admin? %>
  <%= render "memberships/invite_form" %>
<% end %>

<table>
  <thead>
    <tr>
      <th>Member</th><th>Email</th><th>Role</th><th>Joined</th><th></th>
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

## Testing Memberships

```ruby
test "user can belong to multiple accounts" do
  user = users(:alice)
  account1 = accounts(:acme)
  account2 = accounts(:globex)

  account1.add_member(user)
  account2.add_member(user)

  assert user.member_of?(account1)
  assert user.member_of?(account2)
end

test "owner cannot remove themselves" do
  sign_in_as users(:alice)

  delete account_membership_path(accounts(:acme), memberships(:alice_owner))
  assert_redirected_to account_memberships_path(accounts(:acme))
  assert_match "Owner cannot remove themselves", flash[:alert]
end

test "admin can remove members" do
  sign_in_as users(:alice)  # admin

  assert_difference "Membership.count", -1 do
    delete account_membership_path(accounts(:acme), memberships(:bob_member))
  end
end
```
