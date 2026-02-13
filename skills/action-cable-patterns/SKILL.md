---
name: action-cable-patterns
description: Implements real-time features with Action Cable and WebSockets. Use when adding live updates, chat features, notifications, real-time dashboards, or when user mentions Action Cable, WebSockets, channels, or real-time.
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# Action Cable Patterns for Rails 8

## Overview

Action Cable integrates WebSockets with Rails:
- Real-time updates without polling
- Server-to-client push notifications
- Chat and messaging features
- Live dashboards and feeds
- Collaborative editing

**⚠️ IMPORTANT - Broadcasting Philosophy:**

This skill shows the **standard Rails/Action Cable pattern** using `after_create_commit` callbacks for broadcasting.

However, **37signals philosophy** (see `37signals_agents/`) recommends:
- ❌ NO callbacks for broadcasting - it's a side effect
- ✅ Broadcast explicitly from controllers after successful save
- Helper methods in models, called from controllers

Choose based on your project's philosophy:
- Standard Rails agents: Use controller-based broadcasting
- 37signals agents: Use controller-based broadcasting
- General Rails pattern: Can use callbacks (shown in examples below)

## Quick Start

Action Cable is included in Rails by default. Configure it:

```ruby
# config/cable.yml
development:
  adapter: async

test:
  adapter: test

production:
  adapter: solid_cable  # Rails 8 default
  # OR
  adapter: redis
  url: <%= ENV.fetch("REDIS_URL") %>
```

## Project Structure

```
app/
├── channels/
│   ├── application_cable/
│   │   ├── connection.rb      # Authentication
│   │   └── channel.rb         # Base channel
│   ├── notifications_channel.rb
│   ├── events_channel.rb
│   └── chat_channel.rb
├── javascript/
│   └── channels/
│       ├── consumer.js
│       ├── notifications_channel.js
│       └── events_channel.js
spec/channels/
├── notifications_channel_spec.rb
└── events_channel_spec.rb
```

## Connection Authentication

```ruby
# app/channels/application_cable/connection.rb
module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      self.current_user = find_verified_user
    end

    private

    def find_verified_user
      # Using Rails 8 authentication
      if session_token = cookies.signed[:session_token]
        if session = Session.find_by(token: session_token)
          session.user
        else
          reject_unauthorized_connection
        end
      else
        reject_unauthorized_connection
      end
    end
  end
end
```

## Channel Patterns

### Pattern 1: Notifications Channel

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

### Pattern 2: Resource Updates Channel

```ruby
# app/channels/events_channel.rb
class EventsChannel < ApplicationCable::Channel
  def subscribed
    @event = Event.find(params[:event_id])

    # Authorization check
    if authorized?
      stream_for @event
    else
      reject
    end
  end

  def unsubscribed
    # Cleanup
  end

  # Broadcast update to all subscribers
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

### Pattern 3: Chat Channel

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

### Pattern 4: Dashboard Live Updates

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

## Testing Channels

### Channel Spec

```ruby
# spec/channels/notifications_channel_spec.rb
require "rails_helper"

RSpec.describe NotificationsChannel, type: :channel do
  let(:user) { create(:user) }

  before do
    stub_connection(current_user: user)
  end

  describe "#subscribed" do
    it "successfully subscribes" do
      subscribe
      expect(subscription).to be_confirmed
    end

    it "streams for the current user" do
      subscribe
      expect(subscription).to have_stream_for(user)
    end
  end

  describe ".notify" do
    let(:notification) { create(:notification, user: user) }

    it "broadcasts to the user" do
      expect {
        described_class.notify(user, notification)
      }.to have_broadcasted_to(user).with(hash_including(type: "notification"))
    end
  end
end
```

### Channel with Authorization

```ruby
# spec/channels/events_channel_spec.rb
require "rails_helper"

RSpec.describe EventsChannel, type: :channel do
  let(:user) { create(:user) }
  let(:event) { create(:event, account: user.account) }
  let(:other_event) { create(:event) }

  before do
    stub_connection(current_user: user)
  end

  describe "#subscribed" do
    context "with authorized event" do
      it "subscribes successfully" do
        subscribe(event_id: event.id)
        expect(subscription).to be_confirmed
        expect(subscription).to have_stream_for(event)
      end
    end

    context "with unauthorized event" do
      it "rejects subscription" do
        subscribe(event_id: other_event.id)
        expect(subscription).to be_rejected
      end
    end
  end
end
```

### Integration Test

```ruby
# spec/system/chat_spec.rb
require "rails_helper"

RSpec.describe "Chat", type: :system, js: true do
  let(:user) { create(:user) }
  let(:room) { create(:chat_room, users: [user]) }

  before { sign_in user }

  it "sends and receives messages in real-time" do
    visit chat_room_path(room)

    fill_in "message", with: "Hello, world!"
    click_button "Send"

    expect(page).to have_content("Hello, world!")
  end
end
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

## Checklist

- [ ] Connection authentication configured
- [ ] Channel authorization implemented
- [ ] Client-side subscription set up
- [ ] Broadcasting from services/models
- [ ] Channel specs written
- [ ] Error handling in place
- [ ] Reconnection logic on client
- [ ] Performance limits configured
