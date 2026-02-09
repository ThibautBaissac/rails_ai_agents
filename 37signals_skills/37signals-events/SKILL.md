---
name: 37signals-events
description: Build event tracking, activity feeds, and webhooks with domain event models. Triggers on events, event sourcing, activity feed, webhooks, tracking, audit trail, notifications.
allowed-tools: Read, Write, Edit, Bash
---

# 37signals Events Skill

## Overview

Build event tracking, activity feeds, and webhook systems using domain event models (CardMoved, CommentAdded), not generic event tables. State as records, not booleans.

## Core Philosophy

- **Domain event models**: CardMoved, CommentAdded, MemberInvited (not generic Event rows)
- **Polymorphic activities**: Activity points to actual domain records
- **Database-backed webhooks**: Solid Queue for delivery, no Redis/Kafka
- **State as records**: TrackingEvent with type, not tracking_started_at boolean

## Key Patterns

### Pattern 1: Domain Event Records

```ruby
# app/models/card_moved.rb
class CardMoved < ApplicationRecord
  belongs_to :card
  belongs_to :from_column, class_name: "Column"
  belongs_to :to_column, class_name: "Column"
  belongs_to :creator
  belongs_to :account

  has_one :activity, as: :subject, dependent: :destroy

  after_create_commit :create_activity
  after_create_commit :broadcast_update_later
  after_create_commit :deliver_webhooks_later

  def description
    "#{creator.name} moved #{card.title} from #{from_column.name} to #{to_column.name}"
  end

  private

  def create_activity
    Activity.create!(subject: self, account: account, creator: creator, board: card.board)
  end

  def broadcast_update_later
    card.broadcast_replace_later
  end

  def deliver_webhooks_later
    WebhookDeliveryJob.perform_later("card.moved", self)
  end
end
```

### Pattern 2: Activity Feed with Polymorphic Associations

```ruby
# app/models/activity.rb
class Activity < ApplicationRecord
  belongs_to :subject, polymorphic: true  # CardMoved, CommentAdded, etc.
  belongs_to :account
  belongs_to :creator, class_name: "User", optional: true
  belongs_to :board, optional: true

  scope :recent, -> { order(created_at: :desc).limit(50) }
  scope :for_board, ->(board) { where(board: board) }
  scope :with_subjects, -> { includes(:subject, :creator, :board) }

  def icon
    case subject
    when CardMoved then "arrow-right"
    when CommentAdded then "message-square"
    when MemberInvited then "user-plus"
    else "activity"
    end
  end

  def description
    subject.description
  end
end
```

### Pattern 3: Webhook System

```ruby
# app/models/webhook_endpoint.rb
class WebhookEndpoint < ApplicationRecord
  belongs_to :account
  has_many :webhook_deliveries, dependent: :destroy

  serialize :events, coder: JSON

  scope :active, -> { where(active: true) }
  scope :for_event, ->(event_type) { active.where("events @> ?", [event_type].to_json) }

  def subscribed_to?(event_type)
    events.include?(event_type) || events.include?("*")
  end
end

# app/models/webhook_delivery.rb
class WebhookDelivery < ApplicationRecord
  belongs_to :webhook_endpoint
  belongs_to :event, polymorphic: true
  belongs_to :account

  enum :status, { pending: 0, delivered: 1, failed: 2 }

  def deliver
    response = HTTP.timeout(10).post(webhook_endpoint.url, json: payload, headers: headers)

    if response.status.success?
      delivered!
      update!(response_code: response.code, delivered_at: Time.current)
    else
      failed!
      update!(response_code: response.code, error_message: "HTTP #{response.code}")
    end
  rescue => error
    failed!
    update!(error_message: error.message)
  end

  def payload
    { id: id, event: event_type, created_at: created_at.iso8601, data: event.as_json }
  end

  def headers
    {
      "Content-Type" => "application/json",
      "X-Webhook-Signature" => OpenSSL::HMAC.hexdigest("SHA256", webhook_endpoint.secret, payload.to_json)
    }
  end
end

# app/jobs/webhook_delivery_job.rb
class WebhookDeliveryJob < ApplicationJob
  queue_as :webhooks
  retry_on StandardError, wait: :polynomially_longer, attempts: 5

  def perform(event_type, event)
    WebhookEndpoint.for_event(event_type).each do |endpoint|
      delivery = WebhookDelivery.create!(
        webhook_endpoint: endpoint,
        event: event,
        event_type: event_type,
        account: event.account
      )
      delivery.deliver
    end
  end
end
```

### Pattern 4: Client-Side Tracking

```ruby
# app/models/tracking_event.rb
class TrackingEvent < ApplicationRecord
  belongs_to :trackable, polymorphic: true, optional: true
  belongs_to :account
  belongs_to :user, optional: true

  enum :event_type, { page_view: 0, link_click: 1, form_submit: 2 }

  def self.track(event_type, attributes = {})
    create!(event_type: event_type, account: Current.account, user: Current.user, **attributes)
  end
end
```

```javascript
// app/javascript/controllers/tracking_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { eventType: String, trackableType: String, trackableId: String }

  track(event) {
    fetch("/tracking_events", {
      method: "POST",
      headers: { "Content-Type": "application/json", "X-CSRF-Token": this.csrfToken },
      body: JSON.stringify({
        tracking_event: {
          event_type: this.eventTypeValue,
          trackable_type: this.trackableTypeValue,
          trackable_id: this.trackableIdValue,
          url: window.location.href
        }
      })
    })
  }
}
```

### Pattern 5: Audit Trail

```ruby
# app/models/card_updated.rb
class CardUpdated < ApplicationRecord
  belongs_to :card
  belongs_to :updater, class_name: "User"
  belongs_to :account

  serialize :changes, coder: JSON

  def description
    changed_attributes.map { |attr| "#{attr}: #{old_value(attr)} → #{new_value(attr)}" }.join(", ")
  end

  def old_value(attribute)
    changes.dig(attribute, 0)
  end

  def new_value(attribute)
    changes.dig(attribute, 1)
  end
end

# In model
class Card < ApplicationRecord
  after_update :record_update_event

  private

  def record_update_event
    return unless saved_changes.any?
    CardUpdated.create!(card: self, updater: Current.user, account: account, changes: saved_changes)
  end
end
```

## Activity Feed View

```erb
<div id="activities">
  <%= turbo_stream_from @scope, "activities" %>

  <% @activities.each do |activity| %>
    <div id="<%= dom_id(activity) %>" class="activity">
      <%= icon activity.icon %>
      <p><%= activity.description %></p>
      <span><%= time_ago_in_words(activity.created_at) %> ago</span>
    </div>
  <% end %>
</div>
```

## Quick Reference

```ruby
# Create domain event
CardMoved.create!(card: @card, from_column: old, to_column: new, creator: Current.user, account: Current.account)

# Query activities
Activity.for_board(@board).with_subjects.recent

# Webhook delivery
WebhookDeliveryJob.perform_later("card.moved", event)

# Track client event
TrackingEvent.track(:page_view, trackable: @board)
```

## Commands

```bash
rails generate model CardMoved card:references from_column:references to_column:references creator:references
rails generate model Activity subject:references{polymorphic} account:references creator:references
rails generate model WebhookEndpoint url:string account:references events:text
rails generate model WebhookDelivery webhook_endpoint:references event:references{polymorphic}
```

## Boundaries

### Always
- Create domain-specific event models (CardMoved, not Event with type string)
- Use polymorphic associations for activities
- Scope all events to account_id
- Use UUIDs for event IDs
- Use background jobs for webhook delivery
- Include signature authentication for webhooks
- Index by account_id and created_at

### Never
- Generic event tables with type strings and JSON blobs
- Boolean tracking fields (use event records)
- Synchronous webhook delivery
- External message queues (use Solid Queue)
- Webhooks without authentication
