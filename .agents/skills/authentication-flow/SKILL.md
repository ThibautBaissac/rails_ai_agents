---
name: authentication-flow
description: >-
  Implements authentication using Rails 8 built-in generator. Use when setting
  up user authentication, login/logout, session management, password reset
  flows, or securing controllers.
license: MIT
compatibility: Ruby 3.3+, Rails 8.1+
metadata:
  author: ThibautBaissac
  version: "1.0"
---

# Rails 8 Authentication

## Overview

Rails 8 includes a built-in authentication generator that creates a complete, secure authentication system without external gems.

## Quick Start

```bash
# Generate authentication
bin/rails generate authentication

# Run migrations
bin/rails db:migrate
```

This creates:
- `User` model with `has_secure_password`
- `Session` model for secure sessions
- `Current` model for request-local storage
- Authentication concern for controllers
- Session and Password controllers
- Login/logout views

## Generated Structure

```
app/
├── models/
│   ├── user.rb              # User with has_secure_password
│   ├── session.rb           # Session tracking
│   └── current.rb           # Current.user accessor
├── controllers/
│   ├── sessions_controller.rb      # Login/logout
│   ├── passwords_controller.rb     # Password reset
│   └── concerns/
│       └── authentication.rb       # Auth helpers
└── views/
    ├── sessions/
    │   └── new.html.erb     # Login form
    └── passwords/
        ├── new.html.erb     # Forgot password
        └── edit.html.erb    # Reset password
```

## Core Components

### User Model

```ruby
# app/models/user.rb
class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy

  normalizes :email_address, with: -> { _1.strip.downcase }

  validates :email_address, presence: true, uniqueness: true,
            format: { with: URI::MailTo::EMAIL_REGEXP }
end
```

### Session Model

```ruby
# app/models/session.rb
class Session < ApplicationRecord
  belongs_to :user

  before_create { self.token = SecureRandom.urlsafe_base64(32) }

  def self.find_by_token(token)
    find_by(token: token) if token.present?
  end
end
```

### Current Model

```ruby
# app/models/current.rb
class Current < ActiveSupport::CurrentAttributes
  attribute :session
  delegate :user, to: :session, allow_nil: true
end
```

### Authentication Concern

```ruby
# app/controllers/concerns/authentication.rb
module Authentication
  extend ActiveSupport::Concern

  included do
    before_action :require_authentication
    helper_method :authenticated?
  end

  class_methods do
    def allow_unauthenticated_access(**options)
      skip_before_action :require_authentication, **options
    end
  end

  private

  def authenticated?
    Current.session.present?
  end

  def require_authentication
    resume_session || request_authentication
  end

  def resume_session
    if session_token = cookies.signed[:session_token]
      if session = Session.find_by_token(session_token)
        Current.session = session
      end
    end
  end

  def request_authentication
    redirect_to new_session_path
  end

  def start_new_session_for(user)
    session = user.sessions.create!
    cookies.signed.permanent[:session_token] = { value: session.token, httponly: true }
    Current.session = session
  end

  def terminate_session
    Current.session&.destroy
    cookies.delete(:session_token)
  end
end
```

## Usage Patterns

### Protecting Controllers

```ruby
class ApplicationController < ActionController::Base
  include Authentication

  # All actions require authentication by default
end

class PostsController < ApplicationController
  # All actions protected
end

class HomeController < ApplicationController
  # Allow public access to specific actions
  allow_unauthenticated_access only: [:index, :about]
end
```

### Accessing Current User

```ruby
# In controllers
Current.user
Current.user.email_address

# In views
<%= Current.user.email_address %>

# In models (use sparingly)
Current.user
```

### Login Flow

```ruby
# app/controllers/sessions_controller.rb
class SessionsController < ApplicationController
  allow_unauthenticated_access only: [:new, :create]

  def new
  end

  def create
    if user = User.authenticate_by(email_address: params[:email_address],
                                    password: params[:password])
      start_new_session_for(user)
      redirect_to root_path, notice: "Signed in successfully"
    else
      flash.now[:alert] = "Invalid email or password"
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    terminate_session
    redirect_to root_path, notice: "Signed out"
  end
end
```

## Testing Authentication

### Request Specs

```ruby
# spec/requests/sessions_spec.rb
RSpec.describe "Sessions", type: :request do
  let(:user) { create(:user, password: "password123") }

  describe "POST /session" do
    context "with valid credentials" do
      it "signs in the user" do
        post session_path, params: {
          email_address: user.email_address,
          password: "password123"
        }

        expect(response).to redirect_to(root_path)
        expect(cookies[:session_token]).to be_present
      end
    end

    context "with invalid credentials" do
      it "shows error" do
        post session_path, params: {
          email_address: user.email_address,
          password: "wrong"
        }

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe "DELETE /session" do
    it "signs out the user" do
      # First sign in
      post session_path, params: {
        email_address: user.email_address,
        password: "password123"
      }

      delete session_path

      expect(response).to redirect_to(root_path)
    end
  end
end
```

### Test Helper

```ruby
# spec/support/authentication_helpers.rb
module AuthenticationHelpers
  def sign_in(user)
    session = user.sessions.create!
    cookies[:session_token] = session.token
  end

  def sign_out
    cookies.delete(:session_token)
  end
end

RSpec.configure do |config|
  config.include AuthenticationHelpers, type: :request
  config.include AuthenticationHelpers, type: :system
end
```

### Protected Route Specs

```ruby
# spec/requests/posts_spec.rb
RSpec.describe "Posts", type: :request do
  let(:user) { create(:user) }

  describe "GET /posts" do
    context "when not authenticated" do
      it "redirects to login" do
        get posts_path
        expect(response).to redirect_to(new_session_path)
      end
    end

    context "when authenticated" do
      before { sign_in(user) }

      it "shows posts" do
        get posts_path
        expect(response).to have_http_status(:ok)
      end
    end
  end
end
```

## References

- See [sessions.md](references/sessions.md) for session management details
- See [current.md](references/current.md) for Current attributes patterns

## Common Customizations

### Remember Me

```ruby
def start_new_session_for(user, remember: false)
  session = user.sessions.create!
  cookie_options = { value: session.token, httponly: true }
  cookie_options[:expires] = 2.weeks.from_now if remember
  cookies.signed.permanent[:session_token] = cookie_options
  Current.session = session
end
```

### Multiple Sessions Tracking

```ruby
# In User model
def active_sessions
  sessions.where('created_at > ?', 30.days.ago)
end

def terminate_all_sessions_except(current_session)
  sessions.where.not(id: current_session.id).destroy_all
end
```

### Rate Limiting

```ruby
# app/controllers/sessions_controller.rb
rate_limit to: 10, within: 3.minutes, only: :create,
           with: -> { redirect_to new_session_path, alert: "Too many attempts" }
```
