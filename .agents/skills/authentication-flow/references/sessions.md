# Session Management Reference

## Session Model

```ruby
# app/models/session.rb
class Session < ApplicationRecord
  belongs_to :user

  before_create :generate_token
  before_create :set_metadata

  scope :active, -> { where('created_at > ?', 30.days.ago) }
  scope :expired, -> { where('created_at <= ?', 30.days.ago) }

  def expired?
    created_at <= 30.days.ago
  end

  private

  def generate_token
    self.token = SecureRandom.urlsafe_base64(32)
  end

  def set_metadata
    self.ip_address = Current.ip_address
    self.user_agent = Current.user_agent
  end
end
```

## Session Table Schema

```ruby
# db/migrate/xxx_create_sessions.rb
class CreateSessions < ActiveRecord::Migration[8.0]
  def change
    create_table :sessions do |t|
      t.references :user, null: false, foreign_key: true
      t.string :token, null: false
      t.string :ip_address
      t.string :user_agent
      t.timestamps
    end

    add_index :sessions, :token, unique: true
  end
end
```

## Cookie Security

### Secure Cookie Settings

```ruby
def start_new_session_for(user)
  session = user.sessions.create!

  cookies.signed.permanent[:session_token] = {
    value: session.token,
    httponly: true,      # JavaScript can't access
    secure: Rails.env.production?,  # HTTPS only in production
    same_site: :lax      # CSRF protection
  }

  Current.session = session
end
```

### Cookie Options

| Option | Purpose | Value |
|--------|---------|-------|
| `httponly` | Prevent XSS access | `true` |
| `secure` | HTTPS only | `true` in production |
| `same_site` | CSRF protection | `:lax` or `:strict` |
| `expires` | Cookie lifetime | `2.weeks.from_now` |
| `domain` | Cookie scope | `.example.com` for subdomains |

## Session Lifecycle

### Starting Session

```ruby
def start_new_session_for(user)
  # Terminate existing sessions if desired
  # user.sessions.destroy_all

  session = user.sessions.create!
  cookies.signed.permanent[:session_token] = {
    value: session.token,
    httponly: true
  }
  Current.session = session
end
```

### Resuming Session

```ruby
def resume_session
  return unless (token = cookies.signed[:session_token])
  return unless (session = Session.find_by_token(token))
  return if session.expired?

  # Update last seen
  session.touch(:last_seen_at)
  Current.session = session
end
```

### Terminating Session

```ruby
def terminate_session
  Current.session&.destroy
  cookies.delete(:session_token)
  reset_session  # Clear Rails session too
end
```

## Multiple Device Sessions

### Viewing Active Sessions

```ruby
# app/controllers/sessions_controller.rb
def index
  @sessions = Current.user.sessions.active.order(created_at: :desc)
  @current_session = Current.session
end
```

```erb
<%# app/views/sessions/index.html.erb %>
<h2>Active Sessions</h2>

<% @sessions.each do |session| %>
  <div class="session <%= 'current' if session == @current_session %>">
    <p><%= session.ip_address %></p>
    <p><%= session.user_agent %></p>
    <p>Started: <%= time_ago_in_words(session.created_at) %> ago</p>

    <% unless session == @current_session %>
      <%= button_to "Revoke", session_path(session), method: :delete %>
    <% end %>
  </div>
<% end %>

<%= button_to "Sign out all other devices",
    revoke_all_sessions_path, method: :post %>
```

### Revoking Other Sessions

```ruby
# app/controllers/sessions_controller.rb
def revoke_all
  Current.user.sessions.where.not(id: Current.session.id).destroy_all
  redirect_to sessions_path, notice: "All other sessions terminated"
end
```

## Session Cleanup

### Scheduled Cleanup Job

```ruby
# app/jobs/cleanup_expired_sessions_job.rb
class CleanupExpiredSessionsJob < ApplicationJob
  queue_as :low

  def perform
    Session.expired.delete_all
  end
end

# config/recurring.yml
cleanup_sessions:
  class: CleanupExpiredSessionsJob
  schedule: every day at 3am
```

## Security Considerations

1. **Token Rotation**: Regenerate token after password change
2. **IP Binding**: Optional - bind session to IP address
3. **User Agent Tracking**: Detect suspicious changes
4. **Concurrent Session Limits**: Limit active sessions per user
5. **Session Timeout**: Expire inactive sessions

```ruby
# Rotate token on sensitive actions
def rotate_session_token
  new_session = Current.user.sessions.create!
  Current.session.destroy
  cookies.signed.permanent[:session_token] = new_session.token
  Current.session = new_session
end
```
