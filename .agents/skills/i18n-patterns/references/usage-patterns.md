# Usage Patterns

## In Views (Lazy Lookup)

```erb
<%# app/views/events/index.html.erb %>
<%# Lazy lookup: t(".title") resolves to "events.index.title" %>

<h1><%= t(".title") %></h1>

<%= link_to t(".new_event"), new_event_path %>

<% if @events.empty? %>
  <p><%= t(".no_events") %></p>
<% end %>

<%# With interpolation %>
<p><%= t(".welcome", name: current_user.name) %></p>

<%# With HTML (use _html suffix) %>
<p><%= t(".intro_html", link: link_to("here", help_path)) %></p>
```

## In Controllers

```ruby
class EventsController < ApplicationController
  def create
    @event = current_account.events.build(event_params)

    if @event.save
      redirect_to @event, notice: t(".success")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    @event.destroy
    redirect_to events_path, notice: t(".success")
  end
end
```

## In Models

```ruby
class Event < ApplicationRecord
  def status_text
    I18n.t("activerecord.attributes.event/statuses.#{status}")
  end

  # Human-readable model name
  # Event.model_name.human => "Event" or "Événement"
end
```

## In Presenters

```ruby
class EventPresenter < BasePresenter
  def status_badge
    tag.span(
      status_text,
      class: "badge #{status_class}"
    )
  end

  def formatted_date
    return not_specified if event_date.nil?
    I18n.l(event_date, format: :long)
  end

  private

  def status_text
    I18n.t("activerecord.attributes.event/statuses.#{status}")
  end

  def not_specified
    tag.span(I18n.t("common.messages.not_specified"), class: "text-muted")
  end
end
```

## In Components

```ruby
# app/components/event_card_component.rb
class EventCardComponent < ApplicationComponent
  def status_label
    I18n.t("components.event_card.status.#{@event.status}")
  end

  def days_until_text
    days = (@event.event_date - Date.current).to_i
    I18n.t("components.event_card.days_until", count: days)
  end
end
```

## Date/Time Formatting

```ruby
# In views or presenters
I18n.l(Date.current)                    # "January 15, 2024"
I18n.l(Date.current, format: :short)    # "Jan 15"
I18n.l(Date.current, format: :long)     # "Wednesday, January 15, 2024"

# Custom format
I18n.l(event.event_date, format: "%d/%m/%Y")  # "15/01/2024"
```

## Number/Currency Formatting

```ruby
# Number formatting
number_with_delimiter(1234567)          # "1,234,567"
number_to_currency(1234.50)             # "$1,234.50"

# With locale-specific formatting
number_to_currency(1234.50, locale: :fr)  # "1 234,50 €"

# Custom currency
number_to_currency(
  amount_cents / 100.0,
  unit: "EUR",
  format: "%n %u",
  separator: ",",
  delimiter: " "
)  # "1 234,50 EUR"
```

## Pluralization

```yaml
# config/locales/en.yml
en:
  events:
    count:
      zero: No events
      one: 1 event
      other: "%{count} events"

  notifications:
    unread:
      zero: No unread notifications
      one: You have 1 unread notification
      other: "You have %{count} unread notifications"
```

```ruby
# Usage
t("events.count", count: 0)   # "No events"
t("events.count", count: 1)   # "1 event"
t("events.count", count: 5)   # "5 events"
```

```yaml
# French pluralization
# config/locales/fr.yml
fr:
  events:
    count:
      zero: Aucun événement
      one: 1 événement
      other: "%{count} événements"
```

## Locale Switcher Component

```ruby
# app/components/locale_switcher_component.rb
class LocaleSwitcherComponent < ApplicationComponent
  def available_locales
    I18n.available_locales.map do |locale|
      {
        code: locale,
        name: I18n.t("locales.#{locale}"),
        current: locale == I18n.locale
      }
    end
  end
end
```
