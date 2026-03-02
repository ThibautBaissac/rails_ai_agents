# ViewComponent Patterns

## Pattern 1: Status Badge

```ruby
# app/components/badge_component.rb
class BadgeComponent < ApplicationComponent
  VARIANTS = {
    success: "bg-green-100 text-green-800",
    warning: "bg-yellow-100 text-yellow-800",
    error: "bg-red-100 text-red-800",
    info: "bg-blue-100 text-blue-800",
    neutral: "bg-slate-100 text-slate-800"
  }.freeze

  def initialize(text:, variant: :neutral)
    @text = text
    @variant = variant.to_sym
  end

  def call
    tag.span(
      @text,
      class: "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium #{variant_classes}"
    )
  end

  private

  def variant_classes
    VARIANTS.fetch(@variant, VARIANTS[:neutral])
  end
end
```

## Pattern 2: Component with Slots

```ruby
# app/components/card_component.rb
class CardComponent < ApplicationComponent
  renders_one :header
  renders_one :footer
  renders_many :actions

  def initialize(title: nil)
    @title = title
  end
end
```

```erb
<%# app/components/card_component.html.erb %>
<div class="bg-white rounded-lg shadow">
  <% if header? %>
    <div class="px-6 py-4 border-b"><%= header %></div>
  <% elsif @title %>
    <div class="px-6 py-4 border-b">
      <h3 class="text-lg font-semibold"><%= @title %></h3>
    </div>
  <% end %>

  <div class="p-6"><%= content %></div>

  <% if footer? || actions? %>
    <div class="px-6 py-4 border-t flex justify-end gap-2">
      <%= footer %>
      <% actions.each do |action| %>
        <%= action %>
      <% end %>
    </div>
  <% end %>
</div>
```

Usage:
```erb
<%= render CardComponent.new do |card| %>
  <% card.with_header do %>
    <h2>Custom Header</h2>
  <% end %>

  <p>Card content here</p>

  <% card.with_action do %>
    <%= link_to "Edit", edit_path, class: "btn" %>
  <% end %>
  <% card.with_action do %>
    <%= link_to "Delete", delete_path, class: "btn-danger" %>
  <% end %>
<% end %>
```

## Pattern 3: Collection Component (Table)

```ruby
# app/components/table_component.rb
class TableComponent < ApplicationComponent
  renders_one :header
  renders_many :rows

  def initialize(items: [], columns: [])
    @items = items
    @columns = columns
  end
end
```

```erb
<%# app/components/table_component.html.erb %>
<table class="min-w-full divide-y divide-slate-200">
  <thead class="bg-slate-50">
    <% if header? %>
      <%= header %>
    <% else %>
      <tr>
        <% @columns.each do |column| %>
          <th class="px-6 py-3 text-left text-xs font-medium text-slate-500 uppercase">
            <%= column[:label] %>
          </th>
        <% end %>
      </tr>
    <% end %>
  </thead>
  <tbody class="bg-white divide-y divide-slate-200">
    <% if rows? %>
      <% rows.each do |row| %>
        <%= row %>
      <% end %>
    <% else %>
      <% @items.each do |item| %>
        <tr>
          <% @columns.each do |column| %>
            <td class="px-6 py-4 whitespace-nowrap">
              <%= item.public_send(column[:key]) %>
            </td>
          <% end %>
        </tr>
      <% end %>
    <% end %>
  </tbody>
</table>
```

## Pattern 4: Modal Component

```ruby
# app/components/modal_component.rb
class ModalComponent < ApplicationComponent
  renders_one :trigger
  renders_one :title
  renders_one :footer

  def initialize(id:, size: :medium)
    @id = id
    @size = size
  end

  def size_classes
    case @size
    when :small then "max-w-md"
    when :medium then "max-w-lg"
    when :large then "max-w-2xl"
    when :full then "max-w-full mx-4"
    end
  end
end
```

## Pattern 5: Wrapping Models (Presenter-like)

```ruby
# app/components/event_card_component.rb
class EventCardComponent < ApplicationComponent
  with_collection_parameter :event

  def initialize(event:)
    @event = event
  end

  delegate :name, :event_date, :status, to: :@event

  def formatted_date
    return not_specified_span if event_date.nil?
    I18n.l(event_date, format: :long)
  end

  def status_badge
    render BadgeComponent.new(text: status.humanize, variant: status_variant)
  end

  private

  def status_variant
    case status.to_sym
    when :confirmed then :success
    when :cancelled then :error
    when :pending then :warning
    else :neutral
    end
  end
end
```

Usage with collection:
```erb
<%= render EventCardComponent.with_collection(@events) %>
```

## Helpers in Components

```ruby
class PriceComponent < ApplicationComponent
  def initialize(amount_cents:, currency: "EUR")
    @amount_cents = amount_cents
    @currency = currency
  end

  def call
    tag.span(formatted_price, class: "font-mono")
  end

  private

  def formatted_price
    number_to_currency(
      @amount_cents / 100.0,
      unit: @currency,
      format: "%n %u"
    )
  end
end
```
