---
name: 37signals-auth
description: Build custom passwordless authentication from scratch without Devise. Magic links, sessions, Current attributes. Triggers on authentication, login, sign in, magic link, passwordless, session management.
allowed-tools: Read, Write, Edit, Bash
---

# 37signals Auth Skill

## Overview

Build custom authentication systems without Devise or other auth gems. Passwordless magic link authentication is the default. ~150 lines of code total for full auth.

## Core Philosophy

- **No Devise**: Auth is simple, don't use a framework
- **Passwordless by default**: Magic links are simpler and more secure
- **Database sessions**: Not cookie-based, use token records
- **Current attributes**: Request context via Current.user, Current.account

## Architecture

1. **Identity** - email + optional password hash
2. **Session** - token-based, stored in database
3. **MagicLink** - one-time use, expires in 15 minutes
4. **User** - app-specific data linked to Identity
5. **Authentication concern** - controller module for auth

## Key Patterns

### Pattern 1: Identity Model

```ruby
class Identity < ApplicationRecord
  has_secure_password validations: false  # Optional password

  has_many :sessions, dependent: :destroy
  has_many :magic_links, dependent: :destroy
  has_one :user, dependent: :destroy

  validates :email_address, presence: true, uniqueness: { case_sensitive: false }
  normalizes :email_address, with: -> { _1.strip.downcase }

  def send_magic_link(purpose: "sign_in")
    magic_link = magic_links.create!(purpose: purpose)
    MagicLinkMailer.sign_in_instructions(magic_link).deliver_later
    magic_link
  end
end
```

### Pattern 2: Session Model

```ruby
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

### Pattern 3: Magic Link Model

```ruby
class MagicLink < ApplicationRecord
  CODE_LENGTH = 6

  belongs_to :identity

  before_create :set_code, :set_expiration

  scope :active, -> { where(used_at: nil).where("expires_at > ?", Time.current) }

  def self.authenticate(code)
    active.find_by(code: code.upcase)&.tap { |ml| ml.update!(used_at: Time.current) }
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

### Pattern 4: Authentication Concern

```ruby
module Authentication
  extend ActiveSupport::Concern

  included do
    before_action :require_authentication
    helper_method :authenticated?, :current_user
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
    if token = cookies.signed[:session_token]
      if session_record = Session.find_by(token: token)
        Current.session = session_record
        Current.identity = session_record.identity
        Current.user = session_record.identity.user
        true
      end
    end
  end

  def request_authentication
    session[:return_to] = request.url
    redirect_to new_session_path
  end

  def start_new_session_for(identity)
    session_record = identity.sessions.create!
    cookies.signed.permanent[:session_token] = {
      value: session_record.token,
      httponly: true,
      same_site: :lax
    }
  end

  def terminate_session
    Current.session&.destroy
    cookies.delete(:session_token)
  end
end
```

### Pattern 5: Current Attributes

```ruby
class Current < ActiveSupport::CurrentAttributes
  attribute :session, :identity, :user, :account
  attribute :user_agent, :ip_address

  def account=(account)
    super
    Time.zone = account&.timezone
  end
end
```

### Pattern 6: Sessions Controller

```ruby
class SessionsController < ApplicationController
  allow_unauthenticated_access only: [:new, :create]

  def new
  end

  def create
    if identity = Identity.find_by(email_address: params[:email_address])
      identity.send_magic_link
      redirect_to new_session_path, notice: "Check your email for a sign-in link"
    else
      redirect_to new_session_path, alert: "No account found"
    end
  end

  def destroy
    terminate_session
    redirect_to root_path
  end
end

class Sessions::MagicLinksController < ApplicationController
  allow_unauthenticated_access

  def show
    if magic_link = MagicLink.authenticate(params[:code])
      start_new_session_for(magic_link.identity)
      redirect_to session.delete(:return_to) || root_path
    else
      redirect_to new_session_path, alert: "Invalid or expired link"
    end
  end
end
```

## Routes

```ruby
resource :session, only: [:new, :create, :destroy]

namespace :sessions do
  resource :magic_link, only: [:show], param: :code
  resource :password, only: [:create]  # Optional
end

resource :signup, only: [:new, :create]
```

## Security Considerations

```ruby
# Signed cookies with security flags
cookies.signed.permanent[:session_token] = {
  value: session_record.token,
  httponly: true,      # Prevent JavaScript access
  same_site: :lax,     # CSRF protection
  secure: Rails.env.production?
}

# Short magic link expiration
self.expires_at = 15.minutes.from_now

# One-time use magic links
active.find_by(code: code)&.tap { |ml| ml.update!(used_at: Time.current) }

# Rate limiting (Rails 8)
rate_limit to: 5, within: 1.minute, only: :create
```

## Test Helpers

```ruby
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

## Commands

```bash
rails generate model Identity email_address:string password_digest:string
rails generate model Session identity:references token:string user_agent:string ip_address:string
rails generate model MagicLink identity:references code:string purpose:string expires_at:datetime used_at:datetime
```

## Boundaries

### Always
- Use signed cookies for session tokens
- Set httponly and same_site flags
- Expire magic links in 15 minutes
- Mark magic links as used after authentication
- Normalize email addresses
- Use has_secure_token for sessions
- Clean up old sessions periodically

### Never
- Use Devise (unless already in project)
- Store session tokens in plain cookies
- Reuse magic links
- Skip email validation
- Forget CSRF protection
- Store passwords in plain text
