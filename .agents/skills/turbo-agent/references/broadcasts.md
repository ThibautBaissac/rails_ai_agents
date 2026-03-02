# Turbo Broadcasts Reference

Turbo Streams over ActionCable enable real-time updates pushed from the server to connected clients.

## Model Broadcasts

```ruby
# app/models/message.rb
class Message < ApplicationRecord
  belongs_to :chat

  after_create_commit -> {
    broadcast_prepend_to chat, target: "messages"
  }

  after_update_commit -> {
    broadcast_replace_to chat
  }

  after_destroy_commit -> {
    broadcast_remove_to chat
  }
end
```

## View Subscription

```erb
<%# app/views/chats/show.html.erb %>
<h1><%= @chat.name %></h1>

<%# Subscribe to real-time updates %>
<%= turbo_stream_from @chat %>

<div id="messages">
  <%= render @chat.messages %>
</div>

<%= render "messages/form", message: Message.new(chat: @chat) %>
```

## Custom Broadcasts

```ruby
# app/models/notification.rb
class Notification < ApplicationRecord
  belongs_to :user

  after_create_commit :broadcast_to_user

  private

  def broadcast_to_user
    broadcast_prepend_to(
      "user_#{user_id}_notifications",
      target: "notifications",
      partial: "notifications/notification",
      locals: { notification: self }
    )
  end
end
```

```erb
<%# Subscribe in layout %>
<% if current_user %>
  <%= turbo_stream_from "user_#{current_user.id}_notifications" %>
<% end %>

<div id="notifications">
  <%# Real-time notifications appear here %>
</div>
```
