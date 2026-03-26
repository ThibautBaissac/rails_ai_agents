# Activity Feeds Reference

## Architecture: Events ARE the Activity Feed

There is no separate `Activity` model. The `Event` model serves directly as
the activity feed. Events are grouped by day and rendered via partials that
dispatch on the event's `action` or `eventable_type`.

```
Board has_many :events
  -> EventsController loads events with preloading
    -> Events grouped by day (DayTimeline)
      -> Each event renders via _event.html.erb
        -> Dispatches to action-specific or eventable-specific partial
```

## Events Controller

The events controller is thin -- it loads a day timeline and serves it with
HTTP caching:

```ruby
# app/controllers/events_controller.rb
class EventsController < ApplicationController
  include DayTimelinesScoped

  def index
    fresh_when @day_timeline
  end
end
```

The `DayTimelinesScoped` concern handles loading events grouped by day,
applying filters (board, user, time window), and pagination.

## Event Preloading

Efficient loading of events with all their associations:

```ruby
# On the Event model
scope :preloaded, -> {
  includes(:creator, :board, {
    eventable: [
      :closure, :image_attachment,
      { rich_text_body: :embeds_attachments },
      { rich_text_description: :embeds_attachments },
      { card: [ :closure, :image_attachment ] }
    ]
  })
}
```

This single `preloaded` scope prevents N+1 queries when rendering the feed.
The eventable includes handle both Card events (where eventable IS the card)
and Comment events (where eventable has a `card` association).

## Rendering Events

Events dispatch to partials based on action or eventable type:

```erb
<%# app/views/events/_event.html.erb %>
<% cache event do %>
  <% if lookup_context.exists?("events/event/eventable/_#{event.action}") %>
    <%= render "events/event/eventable/#{event.action}", event: event %>
  <% else %>
    <%= render "events/event/eventable/#{event.eventable_type.demodulize.underscore}",
               event: event %>
  <% end %>
<% end %>
```

This pattern allows:
1. Action-specific partials for special rendering (e.g., `_card_published.html.erb`
   shows the full card with description and image).
2. A generic fallback by eventable type (e.g., `_card.html.erb` for most card
   actions, `_comment.html.erb` for comment events).

### Example Partials

```erb
<%# app/views/events/event/eventable/_card.html.erb %>
<div class="event">
  <div class="event__description">
    <%= event.description_for(Current.user).to_html %>
  </div>
  <time class="event__time" datetime="<%= event.created_at.iso8601 %>">
    <%= time_ago_in_words(event.created_at) %> ago
  </time>
</div>

<%# app/views/events/event/eventable/_card_published.html.erb %>
<div class="event event--published">
  <div class="event__description">
    <%= event.description_for(Current.user).to_html %>
  </div>
  <%# Show full card preview with description, image, etc. %>
  <div class="event__card-preview">
    <%= render "cards/preview", card: event.eventable %>
  </div>
</div>

<%# app/views/events/event/eventable/_comment.html.erb %>
<div class="event event--comment">
  <div class="event__description">
    <%= event.description_for(Current.user).to_html %>
  </div>
  <div class="event__comment-body">
    <%= event.eventable.body %>
  </div>
</div>
```

## Day Timeline

Events are grouped by day for display. The index view renders a day timeline
with pagination:

```erb
<%# app/views/events/index.html.erb %>
<%= tag.div id: "activity", class: "events",
    data: { controller: "pagination",
            pagination_paginate_on_intersection_value: true } do %>
  <%= day_timeline_pagination_frame_tag @day_timeline do %>
    <%= render "events/day", day_timeline: @day_timeline %>
    <%= day_timeline_pagination_link(@day_timeline, @filter) %>
  <% end %>
<% end %>

<%# app/views/events/_day.html.erb %>
<section class="events__day">
  <%= render "events/day_timeline/columns", day_timeline: day_timeline %>
  <%= render "events/empty_days", day_timeline: day_timeline %>
</section>
```

Pagination is intersection-based -- new days load as the user scrolls down.

## Event Descriptions

The `Event::Description` class generates context-aware text for the feed:

```ruby
class Event::Description
  def initialize(event, user)
    @event = event
    @user = user
  end

  def to_html
    # Returns HTML with "You" for current user, creator name for others
    # "You closed \"Card title\""
    # "Alice closed \"Card title\""
  end

  def to_plain_text
    # Plain text for webhooks, emails, Slack
    # "Alice closed \"Card title\""
  end
end
```

The description varies by action:

| Action | Description |
|--------|-------------|
| `card_published` | "Alice added \"Card title\"" |
| `card_closed` | "Alice moved \"Card title\" to \"Done\"" |
| `card_reopened` | "Alice reopened \"Card title\"" |
| `card_postponed` | "Alice moved \"Card title\" to \"Not Now\"" |
| `card_auto_postponed` | "\"Card title\" moved to \"Not Now\" due to inactivity" |
| `card_assigned` | "Alice assigned Bob to \"Card title\"" (or "Alice will handle \"Card title\"") |
| `card_unassigned` | "Alice unassigned Bob from \"Card title\"" |
| `card_triaged` | "Alice moved \"Card title\" to \"In Progress\"" |
| `card_sent_back_to_triage` | "Alice moved \"Card title\" back to \"Maybe?\"" |
| `card_title_changed` | "Alice renamed \"New title\" (was: \"Old title\")" |
| `card_board_changed` | "Alice moved \"Card title\" to \"Design\"" |
| `comment_created` | "Alice commented on \"Card title\"" |

When `user == event.creator`, "You" replaces the creator name in HTML output.

## Filtering

The activity feed supports filtering by board, user, and time window:

```erb
<%# Rendered inline in the header %>
<%= render "events/index/filter", user_filtering: @user_filtering %>

<%# Board filter %>
<%= render "events/index/filter/board", ... %>

<%# User filter %>
<%= render "events/index/filter/user", ... %>
```

## Real-Time Updates via Turbo

New events broadcast to the activity feed via Turbo Streams. The card
broadcast concern handles this when events are created:

```ruby
# app/models/card/broadcastable.rb
module Card::Broadcastable
  def broadcast_card_later
    broadcast_replace_later
  end
end
```

Events on cards trigger broadcasts so the feed updates without page reload.

## Notifications from Events

The `Event` model includes `Notifiable`, which creates notifications for
relevant users after event creation:

```ruby
# app/models/concerns/notifiable.rb
module Notifiable
  extend ActiveSupport::Concern

  included do
    has_many :notifications, as: :source, dependent: :destroy
    after_create_commit :notify_recipients_later
  end

  def notify_recipients
    Notifier.for(self)&.notify
  end

  private
    def notify_recipients_later
      NotifyRecipientsJob.perform_later self
    end
end
```

The `Notifier.for(event)` factory determines who should be notified based on
the event type and the watchers/assignees of the card.

## Fragment Caching

Each event partial is cached:

```erb
<% cache event do %>
  <%# ... render event content ... %>
<% end %>
```

Since events are immutable (never updated after creation), the cache key
based on `event.updated_at` is stable. Cache invalidation only happens if
the event is destroyed.

## Testing Activity Feeds

```ruby
test "events index shows events grouped by day" do
  get events_path
  assert_response :success
end

test "events are scoped to accessible boards" do
  sign_in users(:alice)
  get events_path

  # Only sees events from boards alice has access to
  assert_select ".event", count: expected_visible_events_count
end

test "event description shows 'You' for current user" do
  event = events(:card_closed_by_alice)
  desc = event.description_for(users(:alice))

  assert_match "You", desc.to_html
end

test "event description shows creator name for other users" do
  event = events(:card_closed_by_alice)
  desc = event.description_for(users(:bob))

  assert_match "Alice", desc.to_html
end

test "preloaded scope prevents N+1 queries" do
  events = Event.preloaded.chronologically.limit(20)

  assert_queries_count(3) do  # events + creators + eventables
    events.each { |e| e.description_for(nil) }
  end
end
```
