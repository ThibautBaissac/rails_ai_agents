# Action Cable Channel Patterns

## Pattern 1: Notifications Channel

```ruby
# app/channels/notifications_channel.rb
class NotificationsChannel < ApplicationCable::Channel
  def subscribed
    stream_for current_user
  end

  def unsubscribed
    # Cleanup when user disconnects
  end

  # Class method to broadcast
  def self.notify(user, notification)
    broadcast_to(user, {
      type: "notification",
      id: notification.id,
      title: notification.title,
      body: notification.body,
      created_at: notification.created_at.iso8601
    })
  end
end
```

```javascript
// app/javascript/channels/notifications_channel.js
import consumer from "./consumer"

consumer.subscriptions.create("NotificationsChannel", {
  connected() {
    console.log("Connected to notifications")
  },

  disconnected() {
    console.log("Disconnected from notifications")
  },

  received(data) {
    if (data.type === "notification") {
      this.showNotification(data)
    }
  },

  showNotification(notification) {
    // Show toast or update notification badge
    const event = new CustomEvent("notification:received", { detail: notification })
    window.dispatchEvent(event)
  }
})
```

## Pattern 2: Resource Updates Channel

```ruby
# app/channels/events_channel.rb
class EventsChannel < ApplicationCable::Channel
  def subscribed
    @event = Event.find(params[:event_id])

    if authorized?
      stream_for @event
    else
      reject
    end
  end

  def unsubscribed
    # Cleanup
  end

  def self.broadcast_update(event)
    broadcast_to(event, {
      type: "update",
      html: render_event(event)
    })
  end

  def self.broadcast_comment(event, comment)
    broadcast_to(event, {
      type: "new_comment",
      html: render_comment(comment)
    })
  end

  private

  def authorized?
    EventPolicy.new(current_user, @event).show?
  end

  def self.render_event(event)
    ApplicationController.renderer.render(
      partial: "events/event",
      locals: { event: event }
    )
  end

  def self.render_comment(comment)
    ApplicationController.renderer.render(
      partial: "comments/comment",
      locals: { comment: comment }
    )
  end
end
```

```javascript
// app/javascript/channels/events_channel.js
import consumer from "./consumer"

const eventId = document.querySelector("[data-event-id]")?.dataset.eventId

if (eventId) {
  consumer.subscriptions.create(
    { channel: "EventsChannel", event_id: eventId },
    {
      connected() {
        console.log(`Connected to event ${eventId}`)
      },

      received(data) {
        switch(data.type) {
          case "update":
            this.handleUpdate(data)
            break
          case "new_comment":
            this.handleNewComment(data)
            break
        }
      },

      handleUpdate(data) {
        const container = document.getElementById("event-details")
        if (container) {
          container.innerHTML = data.html
        }
      },

      handleNewComment(data) {
        const comments = document.getElementById("comments")
        if (comments) {
          comments.insertAdjacentHTML("beforeend", data.html)
        }
      }
    }
  )
}
```

## Pattern 3: Chat Channel

```ruby
# app/channels/chat_channel.rb
class ChatChannel < ApplicationCable::Channel
  def subscribed
    @room = ChatRoom.find(params[:room_id])

    if authorized?
      stream_for @room
      broadcast_presence(:join)
    else
      reject
    end
  end

  def unsubscribed
    broadcast_presence(:leave) if @room
  end

  def speak(data)
    message = @room.messages.create!(
      user: current_user,
      body: data["body"]
    )

    self.class.broadcast_message(@room, message)
  end

  def typing
    self.class.broadcast_to(@room, {
      type: "typing",
      user: current_user.name
    })
  end

  def self.broadcast_message(room, message)
    broadcast_to(room, {
      type: "message",
      html: render_message(message),
      message_id: message.id
    })
  end

  private

  def authorized?
    @room.users.include?(current_user)
  end

  def broadcast_presence(action)
    self.class.broadcast_to(@room, {
      type: "presence",
      action: action,
      user: current_user.name,
      timestamp: Time.current.iso8601
    })
  end

  def self.render_message(message)
    ApplicationController.renderer.render(
      partial: "messages/message",
      locals: { message: message }
    )
  end
end
```

```javascript
// app/javascript/channels/chat_channel.js
import consumer from "./consumer"

export function connectToChat(roomId) {
  return consumer.subscriptions.create(
    { channel: "ChatChannel", room_id: roomId },
    {
      connected() {
        console.log("Connected to chat")
      },

      disconnected() {
        console.log("Disconnected from chat")
      },

      received(data) {
        switch(data.type) {
          case "message":
            this.handleMessage(data)
            break
          case "typing":
            this.handleTyping(data)
            break
          case "presence":
            this.handlePresence(data)
            break
        }
      },

      speak(body) {
        this.perform("speak", { body: body })
      },

      typing() {
        this.perform("typing")
      },

      handleMessage(data) {
        const messages = document.getElementById("messages")
        messages.insertAdjacentHTML("beforeend", data.html)
        messages.scrollTop = messages.scrollHeight
      },

      handleTyping(data) {
        const indicator = document.getElementById("typing-indicator")
        indicator.textContent = `${data.user} is typing...`
        setTimeout(() => indicator.textContent = "", 2000)
      },

      handlePresence(data) {
        const status = document.getElementById("presence-status")
        status.textContent = `${data.user} ${data.action}ed`
      }
    }
  )
}
```

## Pattern 4: Dashboard Live Updates

```ruby
# app/channels/dashboard_channel.rb
class DashboardChannel < ApplicationCable::Channel
  def subscribed
    stream_for current_user.account
  end

  def self.broadcast_stats(account)
    stats = DashboardStatsQuery.new(account: account).call
    broadcast_to(account, {
      type: "stats_update",
      stats: stats
    })
  end

  def self.broadcast_activity(account, activity)
    broadcast_to(account, {
      type: "new_activity",
      html: render_activity(activity)
    })
  end

  private

  def self.render_activity(activity)
    ApplicationController.renderer.render(
      partial: "activities/activity",
      locals: { activity: activity }
    )
  end
end
```
