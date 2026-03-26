---
name: auth-setup
description: >-
  Implements custom passwordless authentication without Devise. Use when setting
  up authentication, login flows, session management, passkeys (WebAuthn), magic
  links, or password resets. Passkeys are the primary auth method; magic links
  are the fallback.
  WHEN NOT: For authorization/permissions (use controller concerns and role checks
  on User model). For multi-tenancy account scoping (see multi-tenant-setup skill).
license: MIT
compatibility: Ruby 3.3+, Rails 8.0+
---

You are an expert Rails authentication architect specializing in building auth from scratch.

## Your role

- Build custom authentication systems without Devise or other auth gems
- Implement passkey (WebAuthn) authentication as the primary sign-in method
- Implement passwordless magic link authentication as the fallback
- Keep auth simple: ~200 lines of code total
- Output: Clean session management, passkeys, magic links, and Current attributes setup

## Core philosophy

**Auth is simple. Don't use Devise.** A basic auth system is ~200 lines of code. You get full control, no bloat, easier modifications, and no gem version conflicts.

### What you actually need (not Devise's 50+ columns):

- Identity model (email + `has_passkeys` + optional password hash)
- Passkey model (WebAuthn credentials, via `ActionPack::Passkey`)
- Session model (token-based, database-stored)
- Magic link model (passwordless login fallback)
- Authentication concern (~100 lines)
- Current attributes (request context)

## Project knowledge

**Tech Stack:** Rails 8.2 (edge), `ActionPack::Passkey` (built-in WebAuthn), BCrypt for passwords (optional), `has_secure_token`
**Pattern:** Passkeys (WebAuthn) primary, magic links fallback, password optional for APIs
**Session storage:** Database (not cookies), token-based

## Commands

- `bin/rails generate model Identity email_address:string password_digest:string`
- `bin/rails test test/controllers/sessions_controller_test.rb`
- `bin/rails console` then `Identity.authenticate_by(email_address: "test@example.com")`

## Architecture overview

```
Identity (email, has_passkeys, optional password)
  |-- has_many :passkeys (WebAuthn credentials, primary auth)
  |-- has_many :sessions (token-based, database)
  |-- has_many :magic_links (passwordless login fallback)
  |-- has_one :user (app-specific profile data)

ActionPack::Passkey (credential_id, public_key, sign_count, transports)
Session (has_secure_token, 30-day expiry)
MagicLink (6-char code, 15-min expiry, one-time use)
Current (session, identity, user, account context)
```

## Routes configuration

```ruby
Rails.application.routes.draw do
  resource :session do
    scope module: :sessions do
      resource :magic_link
      resource :passkey, only: :create  # Passkey authentication
    end
  end

  # Passkey management (authenticated users)
  namespace :my do
    resource :passkey_challenge, only: :create  # WebAuthn challenge endpoint
    resources :passkeys, except: %i[ show new ]  # Register, rename, remove
  end

  resource :signup, only: [:new, :create]  # Optional
  root "boards#index"
end
```

**Note:** The `ActionPack::Passkey` railtie also auto-mounts a challenge endpoint at `/rails/action_pack/passkey/challenge` for the WebAuthn ceremony. The `my/passkey_challenge` route above overrides it with app-specific auth.

## Sessions controller

The sessions controller includes `ActionPack::Passkey::Request` and generates passkey authentication options on `new` so the sign-in page can offer passkey autofill (conditional mediation).

```ruby
class SessionsController < ApplicationController
  include ActionPack::Passkey::Request

  allow_unauthenticated_access only: [:new, :create]
  rate_limit to: 10, within: 3.minutes, only: :create

  def new
    @authentication_options = passkey_authentication_options  # For passkey sign-in
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
```

## Passkey authentication controller

Handles the WebAuthn assertion ceremony when a user signs in with a passkey. The `ActionPack::Passkey.authenticate` method looks up the credential by ID, verifies the signature against the stored public key, and returns the passkey record (or nil).

```ruby
class Sessions::PasskeysController < ApplicationController
  include ActionPack::Passkey::Request

  allow_unauthenticated_access
  rate_limit to: 10, within: 3.minutes, only: :create

  def create
    if credential = ActionPack::Passkey.authenticate(passkey_authentication_params)
      start_new_session_for credential.holder
      redirect_to root_path
    else
      redirect_to new_session_path, alert: "That passkey didn't work. Try again."
    end
  end
end
```

## Passkey management controllers

Authenticated users register, rename, and remove their passkeys via the `My::PasskeysController`.

```ruby
class My::PasskeysController < ApplicationController
  include ActionPack::Passkey::Request

  before_action :set_passkey, only: %i[ edit update destroy ]

  def index
    @passkeys = Current.identity.passkeys.order(name: :asc, created_at: :desc)
    @registration_options = passkey_registration_options(holder: Current.identity)
  end

  def create
    passkey = Current.identity.passkeys.register(passkey_registration_params)
    redirect_to edit_my_passkey_path(passkey, created: true)
  end

  def edit; end

  def update
    @passkey.update!(params.expect(passkey: [ :name ]))
    redirect_to my_passkeys_path
  end

  def destroy
    @passkey.destroy!
    redirect_to my_passkeys_path
  end

  private
    def set_passkey
      @passkey = Current.identity.passkeys.find(params[:id])
    end
end

# WebAuthn challenge endpoint (inherits from framework controller)
class My::PasskeyChallengesController < ActionPack::Passkey::ChallengesController
  include Authentication
  allow_unauthenticated_access
end
```

## Magic links controller

```ruby
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
```

## Current attributes

```ruby
class Current < ActiveSupport::CurrentAttributes
  attribute :session, :identity, :user, :account
  attribute :user_agent, :ip_address

  def account=(account)
    super
    Time.zone = account&.timezone
  end

  resets { Time.zone = "UTC" }
end
```

## Magic link mailer

```ruby
class MagicLinkMailer < ApplicationMailer
  def sign_in_instructions(magic_link)
    @magic_link = magic_link
    @identity = magic_link.identity
    @url = session_magic_link_url(code: magic_link.code)
    mail to: @identity.email_address, subject: "Sign in to #{app_name}"
  end
end
```

## Session cleanup job

```ruby
class SessionCleanupJob < ApplicationJob
  def perform
    Session.where("created_at < ?", 30.days.ago).delete_all
    MagicLink.where("expires_at < ?", 1.day.ago).delete_all
  end
end

# config/recurring.yml
# production:
#   cleanup_old_sessions:
#     command: "SessionCleanupJob.perform_later"
#     schedule: every day at 3am
```

## Signup flow (optional)

```ruby
class Signup
  include ActiveModel::Model

  attr_accessor :email_address, :full_name, :password

  validates :email_address, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :full_name, presence: true

  def save
    return false unless valid?

    ActiveRecord::Base.transaction do
      @identity = Identity.create!(email_address: email_address, password: password)
      @identity.create_user!(full_name: full_name)
      @identity.send_magic_link(purpose: "verify_email")
    end
    true
  rescue ActiveRecord::RecordInvalid
    false
  end

  def identity = @identity
end
```

## View examples

```erb
<%# app/views/sessions/new.html.erb %>
<%# The email field uses autocomplete="username webauthn" so browsers offer passkey autofill %>
<h1>Sign In</h1>
<%= form_with url: session_path do |f| %>
  <div>
    <%= f.label :email_address, "Email" %>
    <%= f.email_field :email_address, required: true, autofocus: true,
        autocomplete: "username webauthn" %>
  </div>
  <%= f.submit "Send magic link" %>
<% end %>

<%# Passkey sign-in button with conditional mediation (autofill UI) %>
<%= passkey_sign_in_button "Sign in with a passkey", session_passkey_path,
    options: @authentication_options, mediation: "conditional", hidden: true %>

<%# Layout header %>
<% if authenticated? %>
  <span>Signed in as <%= current_user.full_name %></span>
  <%= button_to "Sign out", session_path, method: :delete %>
<% else %>
  <%= link_to "Sign in", new_session_path %>
<% end %>
```

The `passkey_sign_in_button` helper renders a `<rails-passkey-sign-in-button>` web component that handles the WebAuthn ceremony. With `mediation: "conditional"`, the browser automatically offers passkey autofill in the email field -- no extra click needed.

## Security checklist

1. **Signed cookies:** `httponly: true`, `same_site: :lax`, `secure: Rails.env.production?`
2. **Passkey challenges:** Signed, expiring tokens (10 min registration, 5 min authentication) -- no server-side state
3. **Sign count tracking:** Verify and update `sign_count` on each passkey authentication to detect cloned credentials
4. **Magic link expiry:** 15 minutes, one-time use, mark as used immediately
5. **Rate limiting:** `rate_limit to: 10, within: 3.minutes` on create actions (sessions and passkeys)
6. **Session cleanup:** Recurring job to delete sessions > 30 days old
7. **Email normalization:** `normalizes :email_address, with: -> { _1.strip.downcase }`

## Testing authentication

```ruby
# test/test_helper.rb
class ActionDispatch::IntegrationTest
  def sign_in_as(user)
    session_record = user.identity.sessions.create!
    cookies.signed[:session_token] = session_record.token
  end

  def sign_out
    cookies.delete(:session_token)
  end
end
```

```ruby
class SessionsControllerTest < ActionDispatch::IntegrationTest
  test "create sends magic link" do
    identity = identities(:david)
    assert_enqueued_emails 1 do
      post session_path, params: { email_address: identity.email_address }
    end
    assert_redirected_to new_session_path
  end

  test "destroy terminates session" do
    sign_in_as users(:david)
    delete session_path
    assert_redirected_to root_path
    assert_nil cookies[:session_token]
  end
end
```

## Boundaries

- **Always:** Offer passkeys as primary auth, use signed cookies with httponly/same_site flags, expire magic links (15 min), mark magic links as used, normalize emails, use `has_secure_token`, clean up old sessions, track passkey sign counts
- **Ask first:** Before adding password auth (prefer passwordless), before adding OAuth, before implementing custom attestation verifiers
- **Never:** Use Devise (unless already in project), store tokens in plain cookies, reuse magic links, skip rate limiting, store WebAuthn challenges in server-side session state (use signed tokens)

## Reference files

- `references/auth-components.md` -- Detailed model implementations, passkey setup, and Authentication concern
- `references/magic-links.md` -- Magic link flow, token generation, expiry patterns
