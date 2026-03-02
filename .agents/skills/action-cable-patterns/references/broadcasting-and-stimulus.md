# Broadcasting and Stimulus Integration

## Broadcasting from Services

```ruby
# app/services/events/update_service.rb
module Events
  class UpdateService
    def call(event, params)
      event.update!(params)

      # Broadcast to all viewers
      EventsChannel.broadcast_update(event)

      # Update dashboard stats
      DashboardChannel.broadcast_stats(event.account)

      success(event)
    end
  end
end
```

## Broadcasting from Models

```ruby
# app/models/comment.rb
class Comment < ApplicationRecord
  belongs_to :event
  belongs_to :user

  after_create_commit :broadcast_to_channel

  private

  def broadcast_to_channel
    EventsChannel.broadcast_comment(event, self)
  end
end
```

## Integration with Turbo Streams

```ruby
# app/models/comment.rb
class Comment < ApplicationRecord
  after_create_commit -> {
    broadcast_append_to(
      [event, "comments"],
      target: "comments",
      partial: "comments/comment"
    )
  }

  after_destroy_commit -> {
    broadcast_remove_to([event, "comments"])
  }
end
```

```erb
<%# app/views/events/show.html.erb %>
<%= turbo_stream_from @event, "comments" %>

<div id="comments">
  <%= render @event.comments %>
</div>
```

## Stimulus Controller for Channels

```javascript
// app/javascript/controllers/chat_controller.js
import { Controller } from "@hotwired/stimulus"
import consumer from "../channels/consumer"

export default class extends Controller {
  static targets = ["messages", "input", "typingIndicator"]
  static values = { roomId: Number }

  connect() {
    this.channel = consumer.subscriptions.create(
      { channel: "ChatChannel", room_id: this.roomIdValue },
      {
        received: this.received.bind(this),
        connected: this.connected.bind(this),
        disconnected: this.disconnected.bind(this)
      }
    )
  }

  disconnect() {
    this.channel?.unsubscribe()
  }

  connected() {
    this.element.classList.remove("disconnected")
  }

  disconnected() {
    this.element.classList.add("disconnected")
  }

  received(data) {
    if (data.type === "message") {
      this.messagesTarget.insertAdjacentHTML("beforeend", data.html)
      this.scrollToBottom()
    }
  }

  send(event) {
    event.preventDefault()
    const body = this.inputTarget.value.trim()

    if (body) {
      this.channel.perform("speak", { body })
      this.inputTarget.value = ""
    }
  }

  typing() {
    this.channel.perform("typing")
  }

  scrollToBottom() {
    this.messagesTarget.scrollTop = this.messagesTarget.scrollHeight
  }
}
```

## Performance Considerations

### Connection Limits

```ruby
# config/initializers/action_cable.rb
Rails.application.config.action_cable.max_connections_per_server = 1000
```

### Selective Broadcasting

```ruby
# Only broadcast to connected users
def self.broadcast_if_subscribed(user, data)
  return unless ActionCable.server.connections.any? { |c| c.current_user == user }
  broadcast_to(user, data)
end
```

### Debouncing Broadcasts

```ruby
# app/services/broadcast_service.rb
class BroadcastService
  def self.debounced_broadcast(key, data, wait: 1.second)
    Rails.cache.fetch("broadcast:#{key}", expires_in: wait) do
      yield
      true
    end
  end
end
```
