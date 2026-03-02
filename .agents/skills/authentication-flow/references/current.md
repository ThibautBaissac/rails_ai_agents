# Current Attributes Reference

## Concept

`Current` uses `ActiveSupport::CurrentAttributes` to provide request-local storage, making request-specific data available throughout the application without passing it explicitly.

## Basic Setup

```ruby
# app/models/current.rb
class Current < ActiveSupport::CurrentAttributes
  # Attributes stored per-request
  attribute :session
  attribute :user_agent
  attribute :ip_address
  attribute :request_id

  # Delegate to session for convenience
  delegate :user, to: :session, allow_nil: true

  # Resets automatically between requests
  resets { Time.zone = nil }
end
```

## Setting Current Attributes

### In ApplicationController

```ruby
# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  before_action :set_current_attributes

  private

  def set_current_attributes
    Current.user_agent = request.user_agent
    Current.ip_address = request.remote_ip
    Current.request_id = request.request_id
  end
end
```

### In Authentication

```ruby
# app/controllers/concerns/authentication.rb
def resume_session
  if token = cookies.signed[:session_token]
    if session = Session.find_by_token(token)
      Current.session = session  # Sets Current.session
    end
  end
end
```

## Accessing Current

### In Controllers

```ruby
class PostsController < ApplicationController
  def create
    @post = Current.user.posts.build(post_params)
    # ...
  end

  def index
    @posts = Current.user.posts
  end
end
```

### In Views

```erb
<% if Current.user %>
  Logged in as: <%= Current.user.email_address %>
  <%= link_to "Sign out", session_path, method: :delete %>
<% else %>
  <%= link_to "Sign in", new_session_path %>
<% end %>
```

### In Models (Use Sparingly)

```ruby
class Post < ApplicationRecord
  belongs_to :user

  before_create :set_author

  private

  def set_author
    self.user ||= Current.user
  end
end
```

**Warning**: Using `Current` in models couples them to the request context. This makes testing harder and breaks in background jobs. Prefer passing the user explicitly.

### In Mailers

```ruby
class NotificationMailer < ApplicationMailer
  def alert(user, message)
    @user = user
    @message = message
    @request_id = Current.request_id  # For logging correlation

    mail(to: user.email)
  end
end
```

### In Jobs (Careful!)

```ruby
class AuditLogJob < ApplicationJob
  def perform(action:, user_id:, ip_address:, request_id:)
    # Don't rely on Current - it's reset between requests
    # Pass values explicitly
    AuditLog.create!(
      action: action,
      user_id: user_id,
      ip_address: ip_address,
      request_id: request_id
    )
  end
end

# Enqueue with current values
AuditLogJob.perform_later(
  action: "created_post",
  user_id: Current.user.id,
  ip_address: Current.ip_address,
  request_id: Current.request_id
)
```

## Common Attributes

```ruby
class Current < ActiveSupport::CurrentAttributes
  # Authentication
  attribute :session
  delegate :user, to: :session, allow_nil: true

  # Request metadata
  attribute :request_id
  attribute :user_agent
  attribute :ip_address

  # Timezone (per-user)
  attribute :time_zone

  # Feature flags
  attribute :feature_flags

  # Request tracking
  attribute :request_start_time
end
```

## Callbacks

```ruby
class Current < ActiveSupport::CurrentAttributes
  attribute :session, :time_zone

  # Called when session is set
  after_reset do
    Time.zone = nil
  end

  # Apply user's timezone when session is set
  def session=(session)
    super
    self.time_zone = session&.user&.time_zone
    Time.zone = time_zone if time_zone
  end
end
```

## Testing

### Stub Current in Tests

```ruby
# spec/support/current_helpers.rb
module CurrentHelpers
  def with_current_user(user)
    session = user.sessions.create!
    Current.session = session
    yield
  ensure
    Current.reset
  end
end

RSpec.configure do |config|
  config.include CurrentHelpers
end
```

### In Specs

```ruby
RSpec.describe Post, type: :model do
  let(:user) { create(:user) }

  describe 'auto-assignment of author' do
    it 'sets author from Current.user' do
      with_current_user(user) do
        post = Post.create!(title: "Test")
        expect(post.user).to eq(user)
      end
    end
  end
end
```

### Request Specs

```ruby
RSpec.describe "Posts", type: :request do
  let(:user) { create(:user) }

  before { sign_in(user) }  # Sets Current.session

  it 'uses current user' do
    post posts_path, params: { post: { title: "Test" } }
    expect(Post.last.user).to eq(user)
  end
end
```

## Best Practices

1. **Controllers/Views**: Safe to use `Current.user` freely
2. **Models**: Pass user explicitly when possible
3. **Jobs**: Never rely on Current - pass values explicitly
4. **Mailers**: Can use for metadata, but pass main data explicitly
5. **Services**: Accept user as parameter, don't assume Current
6. **Tests**: Reset Current between examples
