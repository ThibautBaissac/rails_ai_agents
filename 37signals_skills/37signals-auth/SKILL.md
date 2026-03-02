---
name: 37signals-auth
description: >-
  Implements custom passwordless authentication without Devise. Use when setting
  up authentication, login flows, session management, password resets, or when
  user mentions auth, login, passwordless, or sessions.
license: MIT
compatibility: Ruby 3.3+, Rails 8.2+
metadata:
  author: 37signals
  version: "1.0"
  source: 37signals-patterns
---

You are an expert Rails authentication architect specializing in building auth from scratch.

## Your role
- You build custom authentication systems without Devise or other auth gems
- You implement passwordless magic link authentication
- You keep auth simple: ~150 lines of code total
- Your output: Clean session management, magic links, and Current attributes setup

## Core philosophy

**Auth is simple. Don't use Devise.** A basic auth system is ~150 lines of code. You get:
- Full control and understanding
- No bloat or unused features
- Easier to modify and extend
- No gem version conflicts

### What Devise gives you (that you don't need):
- ❌ Password complexity validation
- ❌ Password recovery flows
- ❌ Confirmable emails
- ❌ Lockable accounts
- ❌ Trackable statistics
- ❌ Omniauthable integrations (unless you need them)
- ❌ 50+ database columns

### What you actually need:
- ✅ Identity model (email + optional password hash)
- ✅ Session model (token-based)
- ✅ Magic link model (passwordless login)
- ✅ Authentication concern (~100 lines)
- ✅ Current attributes (request context)

## Project knowledge

**Tech Stack:** Rails 8.2 (edge), BCrypt for passwords (optional), has_secure_token
**Pattern:** Passwordless by default, password optional for APIs
**Session storage:** Database (not cookies), token-based

## Commands you can use

- **Generate models:** `bin/rails generate model Identity email_address:string password_digest:string`
- **Test auth:** `bin/rails test test/controllers/sessions_controller_test.rb`
- **Console test:** `bin/rails console` then `Identity.authenticate_by(email_address: "test@example.com")`
- **Send magic link:** Test in development with letter_opener gem

## Authentication system components

### Component 1: Identity model

```ruby
# Migration
class CreateIdentities < ActiveRecord::Migration[8.2]
  def change
    create_table :identities, id: :uuid do |t|
      t.string :email_address, null: false
      t.string :password_digest  # Optional, for API auth

      t.timestamps
    end

    add_index :identities, :email_address, unique: true
  end
end

# app/models/identity.rb
class Identity < ApplicationRecord
  has_secure_password validations: false  # Optional password support

  has_many :sessions, dependent: :destroy
  has_many :magic_links, dependent: :destroy
  has_one :user, dependent: :destroy

  validates :email_address, presence: true, uniqueness: { case_sensitive: false }
  validates :email_address, format: { with: URI::MailTo::EMAIL_REGEXP }

  normalizes :email_address, with: -> { _1.strip.downcase }

  def send_magic_link(purpose: "sign_in")
    magic_link = magic_links.create!(purpose: purpose)
    MagicLinkMailer.sign_in_instructions(magic_link).deliver_later
    magic_link
  end

  def verified?
    user.present?
  end
end
```

### Component 2: Session model

```ruby
# Migration
class CreateSessions < ActiveRecord::Migration[8.2]
  def change
    create_table :sessions, id: :uuid do |t|
      t.references :identity, null: false, type: :uuid
      t.string :user_agent
      t.string :ip_address

      t.timestamps
    end

    add_index :sessions, :identity_id
  end
end

# app/models/session.rb
class Session < ApplicationRecord
  belongs_to :identity

  has_secure_token length: 36

  before_create :set_request_details

  def active?
    created_at > 30.days.ago
  end

  private

  def set_request_details
    self.user_agent = Current.user_agent
    self.ip_address = Current.ip_address
  end
end
```

### Component 3: Magic link model

```ruby
# Migration
class CreateMagicLinks < ActiveRecord::Migration[8.2]
  def change
    create_table :magic_links, id: :uuid do |t|
      t.references :identity, null: false, type: :uuid
      t.string :code, null: false
      t.string :purpose, default: "sign_in"
      t.datetime :expires_at, null: false
      t.datetime :used_at

      t.timestamps
    end

    add_index :magic_links, :code, unique: true
    add_index :magic_links, [:identity_id, :purpose]
  end
end

# app/models/magic_link.rb
class MagicLink < ApplicationRecord
  CODE_LENGTH = 6

  belongs_to :identity

  before_create :set_code
  before_create :set_expiration

  scope :unused, -> { where(used_at: nil) }
  scope :active, -> { unused.where("expires_at > ?", Time.current) }

  def self.authenticate(code)
    active.find_by(code: code.upcase)&.tap do |magic_link|
      magic_link.update!(used_at: Time.current)
    end
  end

  def expired?
    expires_at < Time.current
  end

  def used?
    used_at.present?
  end

  def valid_for_use?
    !expired? && !used?
  end

  private

  def set_code
    self.code = SecureRandom.alphanumeric(CODE_LENGTH).upcase
  end

  def set_expiration
    self.expires_at = 15.minutes.from_now
  end
end
```

### Component 4: User model (optional, for app-specific data)

```ruby
# Migration
class CreateUsers < ActiveRecord::Migration[8.2]
  def change
    create_table :users, id: :uuid do |t|
      t.references :identity, null: false, type: :uuid
      t.references :account, null: true, type: :uuid
      t.string :full_name, null: false
      t.string :timezone, default: "UTC"

      t.timestamps
    end

    add_index :users, :identity_id, unique: true
  end
end

# app/models/user.rb
class User < ApplicationRecord
  belongs_to :identity
  belongs_to :account, optional: true

  validates :full_name, presence: true

  delegate :email_address, to: :identity

  def can_administer_card?(card)
    account.admin?(self) || card.creator == self
  end
end
```

### Component 5: Authentication concern

```ruby
# app/controllers/concerns/authentication.rb
module Authentication
  extend ActiveSupport::Concern

  included do
    before_action :require_authentication
    helper_method :authenticated?, :current_identity, :current_user, :current_session
  end

  class_methods do
    def allow_unauthenticated_access(**options)
      skip_before_action :require_authentication, **options
    end
  end

  private

  def require_authentication
    resume_session || request_authentication
  end

  def resume_session
    if session_token = cookies.signed[:session_token]
      if session_record = Session.find_by(token: session_token)
        @current_session = session_record
        @current_identity = session_record.identity
        @current_user = @current_identity.user

        Current.session = @current_session
        Current.identity = @current_identity
        Current.user = @current_user

        return true
      end
    end

    false
  end

  def request_authentication
    session[:return_to] = request.url
    redirect_to new_session_path
  end

  def authenticated?
    current_identity.present?
  end

  def current_identity
    @current_identity
  end

  def current_user
    @current_user
  end

  def current_session
    @current_session
  end

  def start_new_session_for(identity)
    session_record = identity.sessions.create!
    cookies.signed.permanent[:session_token] = {
      value: session_record.token,
      httponly: true,
      same_site: :lax
    }

    @current_session = session_record
    @current_identity = identity
    @current_user = identity.user
  end

  def terminate_session
    current_session&.destroy
    cookies.delete(:session_token)

    @current_session = nil
    @current_identity = nil
    @current_user = nil
  end

  # Optional: API token authentication
  def authenticate_by_bearer_token
    if token = request.authorization&.match(/^Bearer (.+)$/)&.[](1)
      if session_record = Session.find_by(token: token)
        @current_session = session_record
        @current_identity = session_record.identity
        @current_user = session_record.identity.user
        return true
      end
    end

    false
  end
end
```

### Component 6: Current attributes

```ruby
# app/models/current.rb
class Current < ActiveSupport::CurrentAttributes
  attribute :session, :identity, :user, :account
  attribute :user_agent, :ip_address

  def account=(account)
    super
    Time.zone = account&.timezone
  end

  resets do
    Time.zone = "UTC"
  end
end
```

### Component 7: Sessions controller

```ruby
# app/controllers/sessions_controller.rb
class SessionsController < ApplicationController
  allow_unauthenticated_access only: [:new, :create]

  def new
    # Render sign in form
  end

  def create
    if identity = Identity.find_by(email_address: params[:email_address])
      identity.send_magic_link
      redirect_to new_session_path, notice: "Check your email for a sign-in link"
    else
      redirect_to new_session_path, alert: "No account found with that email"
    end
  end

  def destroy
    terminate_session
    redirect_to root_path
  end
end

# app/controllers/sessions/magic_links_controller.rb
class Sessions::MagicLinksController < ApplicationController
  allow_unauthenticated_access

  def show
    if magic_link = MagicLink.authenticate(params[:code])
      start_new_session_for(magic_link.identity)
      redirect_to session.delete(:return_to) || root_path, notice: "Signed in successfully"
    else
      redirect_to new_session_path, alert: "Invalid or expired link"
    end
  end
end

# app/controllers/sessions/passwords_controller.rb (optional, for password auth)
class Sessions::PasswordsController < ApplicationController
  allow_unauthenticated_access

  def create
    if identity = Identity.authenticate_by(
      email_address: params[:email_address],
      password: params[:password]
    )
      start_new_session_for(identity)
      redirect_to session.delete(:return_to) || root_path
    else
      redirect_to new_session_path, alert: "Invalid email or password"
    end
  end
end
```

### Component 8: Magic link mailer

```ruby
# app/mailers/magic_link_mailer.rb
class MagicLinkMailer < ApplicationMailer
  def sign_in_instructions(magic_link)
    @magic_link = magic_link
    @identity = magic_link.identity
    @url = session_magic_link_url(code: magic_link.code)

    mail to: @identity.email_address, subject: "Sign in to #{app_name}"
  end
end
```

```erb
<%# app/views/magic_link_mailer/sign_in_instructions.html.erb %>
<h1>Sign in to <%= app_name %></h1>

<p>Click the link below to sign in:</p>

<p><%= link_to "Sign in now", @url %></p>

<p>Or enter this code: <strong><%= @magic_link.code %></strong></p>

<p>This link expires in 15 minutes.</p>

<p>If you didn't request this, you can safely ignore this email.</p>
```

## Routes configuration

```ruby
# config/routes.rb
Rails.application.routes.draw do
  resource :session, only: [:new, :create, :destroy]

  namespace :sessions do
    resource :magic_link, only: [:show], param: :code
    resource :password, only: [:create]
  end

  # Optional: Registration/signup
  resource :signup, only: [:new, :create]

  # Root requires auth
  root "boards#index"
end
```

## Signup flow (optional)

```ruby
# app/models/signup.rb
class Signup
  include ActiveModel::Model

  attr_accessor :email_address, :full_name, :password

  validates :email_address, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :full_name, presence: true

  def save
    return false unless valid?

    ActiveRecord::Base.transaction do
      create_identity
      create_user
      send_verification_email
    end

    true
  rescue ActiveRecord::RecordInvalid
    false
  end

  def identity
    @identity
  end

  private

  def create_identity
    @identity = Identity.create!(
      email_address: email_address,
      password: password
    )
  end

  def create_user
    @user = @identity.create_user!(
      full_name: full_name
    )
  end

  def send_verification_email
    @identity.send_magic_link(purpose: "verify_email")
  end
end

# app/controllers/signups_controller.rb
class SignupsController < ApplicationController
  allow_unauthenticated_access

  def new
    @signup = Signup.new
  end

  def create
    @signup = Signup.new(signup_params)

    if @signup.save
      redirect_to new_session_path, notice: "Account created! Check your email to verify."
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def signup_params
    params.require(:signup).permit(:email_address, :full_name, :password)
  end
end
```

## View examples

```erb
<%# app/views/sessions/new.html.erb %>
<h1>Sign In</h1>

<%= form_with url: session_path do |f| %>
  <div>
    <%= f.label :email_address, "Email" %>
    <%= f.email_field :email_address, required: true, autofocus: true %>
  </div>

  <%= f.submit "Send magic link" %>
<% end %>

<p>Or <%= link_to "create an account", new_signup_path %></p>
```

```erb
<%# app/views/layouts/application.html.erb %>
<header>
  <% if authenticated? %>
    <span>Signed in as <%= current_user.full_name %></span>
    <%= button_to "Sign out", session_path, method: :delete %>
  <% else %>
    <%= link_to "Sign in", new_session_path %>
  <% end %>
</header>
```

## Testing authentication

```ruby
# test/models/identity_test.rb
class IdentityTest < ActiveSupport::TestCase
  test "normalizes email address to lowercase" do
    identity = Identity.create!(email_address: "TEST@EXAMPLE.COM")

    assert_equal "test@example.com", identity.email_address
  end

  test "validates email format" do
    identity = Identity.new(email_address: "invalid")

    assert_not identity.valid?
    assert_includes identity.errors[:email_address], "is invalid"
  end

  test "sends magic link" do
    identity = identities(:david)

    assert_difference -> { identity.magic_links.count }, 1 do
      assert_enqueued_emails 1 do
        identity.send_magic_link
      end
    end
  end
end

# test/models/session_test.rb
class SessionTest < ActiveSupport::TestCase
  test "generates secure token on create" do
    session = Session.create!(identity: identities(:david))

    assert_present session.token
    assert_equal 36, session.token.length
  end

  test "is active within 30 days" do
    session = Session.create!(identity: identities(:david))

    assert session.active?

    session.update!(created_at: 31.days.ago)

    assert_not session.active?
  end
end

# test/models/magic_link_test.rb
class MagicLinkTest < ActiveSupport::TestCase
  test "generates 6-character code" do
    magic_link = MagicLink.create!(identity: identities(:david))

    assert_equal 6, magic_link.code.length
    assert_match /\A[A-Z0-9]+\z/, magic_link.code
  end

  test "expires after 15 minutes" do
    magic_link = MagicLink.create!(identity: identities(:david))

    assert magic_link.valid_for_use?

    travel 16.minutes do
      assert magic_link.expired?
      assert_not magic_link.valid_for_use?
    end
  end

  test "authenticates with valid code" do
    magic_link = MagicLink.create!(identity: identities(:david))

    authenticated = MagicLink.authenticate(magic_link.code)

    assert_equal magic_link, authenticated
    assert authenticated.used?
  end

  test "doesn't authenticate used codes" do
    magic_link = MagicLink.create!(identity: identities(:david))
    MagicLink.authenticate(magic_link.code)

    assert_nil MagicLink.authenticate(magic_link.code)
  end
end

# test/controllers/sessions_controller_test.rb
class SessionsControllerTest < ActionDispatch::IntegrationTest
  test "create sends magic link" do
    identity = identities(:david)

    assert_enqueued_emails 1 do
      post session_path, params: { email_address: identity.email_address }
    end

    assert_redirected_to new_session_path
    assert_equal "Check your email for a sign-in link", flash[:notice]
  end

  test "destroy terminates session" do
    sign_in_as identities(:david)

    delete session_path

    assert_redirected_to root_path
    assert_nil cookies[:session_token]
  end
end

# test/controllers/sessions/magic_links_controller_test.rb
class Sessions::MagicLinksControllerTest < ActionDispatch::IntegrationTest
  test "authenticates with valid magic link" do
    magic_link = magic_links(:david_sign_in)

    get session_magic_link_path(code: magic_link.code)

    assert_redirected_to root_path
    assert_equal "Signed in successfully", flash[:notice]
    assert_present cookies[:session_token]
  end

  test "rejects expired magic link" do
    magic_link = magic_links(:david_expired)

    get session_magic_link_path(code: magic_link.code)

    assert_redirected_to new_session_path
    assert_equal "Invalid or expired link", flash[:alert]
  end
end
```

## Test helpers

```ruby
# test/test_helper.rb
class ActionDispatch::IntegrationTest
  def sign_in_as(identity)
    session_record = identity.sessions.create!
    cookies.signed[:session_token] = session_record.token
  end

  def sign_out
    cookies.delete(:session_token)
  end
end
```

## Security considerations

### 1. Session tokens
```ruby
# Use signed cookies
cookies.signed.permanent[:session_token] = {
  value: session_record.token,
  httponly: true,      # Prevent JavaScript access
  same_site: :lax,     # CSRF protection
  secure: Rails.env.production?  # HTTPS only in production
}
```

### 2. Magic link expiration
```ruby
# Short expiration (15 minutes)
def set_expiration
  self.expires_at = 15.minutes.from_now
end

# One-time use
def self.authenticate(code)
  active.find_by(code: code)&.tap do |magic_link|
    magic_link.update!(used_at: Time.current)
  end
end
```

### 3. Rate limiting (optional)
```ruby
# app/controllers/sessions_controller.rb
class SessionsController < ApplicationController
  rate_limit to: 5, within: 1.minute, only: :create

  def create
    # Send magic link...
  end
end
```

### 4. Session cleanup job
```ruby
# app/jobs/session_cleanup_job.rb
class SessionCleanupJob < ApplicationJob
  def perform
    Session.where("created_at < ?", 30.days.ago).delete_all
    MagicLink.where("expires_at < ?", 1.day.ago).delete_all
  end
end

# config/recurring.yml
production:
  cleanup_old_sessions:
    command: "SessionCleanupJob.perform_later"
    schedule: every day at 3am
```

## Optional: Password authentication

If you need password auth (for APIs, etc.):

```ruby
# app/models/identity.rb
class Identity < ApplicationRecord
  has_secure_password validations: false

  validates :password, length: { minimum: 8 }, if: :password_digest_changed?

  def self.authenticate_by(email_address:, password:)
    find_by(email_address: email_address)&.authenticate(password)
  end
end

# app/controllers/sessions/passwords_controller.rb
class Sessions::PasswordsController < ApplicationController
  allow_unauthenticated_access

  def create
    if identity = Identity.authenticate_by(
      email_address: params[:email_address],
      password: params[:password]
    )
      start_new_session_for(identity)
      redirect_to root_path
    else
      redirect_to new_session_path, alert: "Invalid credentials"
    end
  end
end
```

## Multi-account support

```ruby
# app/models/account_membership.rb
class AccountMembership < ApplicationRecord
  belongs_to :account
  belongs_to :user

  enum :role, { member: "member", admin: "admin" }
end

# app/controllers/concerns/account_scoped.rb
module AccountScoped
  extend ActiveSupport::Concern

  included do
    before_action :set_current_account
  end

  private

  def set_current_account
    if account_id = params[:account_id] || session[:account_id]
      @current_account = current_user.accounts.find(account_id)
      Current.account = @current_account
      session[:account_id] = @current_account.id
    else
      redirect_to account_selection_path
    end
  end
end
```

## Boundaries

- ✅ **Always do:** Use signed cookies for session tokens, set httponly and same_site flags, expire magic links (15 min), mark magic links as used, normalize email addresses, validate email format, use has_secure_token for sessions, clean up old sessions/magic links
- ⚠️ **Ask first:** Before adding password authentication (prefer passwordless), before adding OAuth providers, before implementing 2FA, before adding session tracking (IP, user agent, etc.)
- 🚫 **Never do:** Use Devise (unless project is already using it), store session tokens in plain cookies, reuse magic links, skip email validation, forget CSRF protection, store passwords in plain text, use short session tokens, skip rate limiting for login attempts
