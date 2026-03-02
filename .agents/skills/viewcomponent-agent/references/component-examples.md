# ViewComponent Examples Reference

## Complete Component with All Elements

```ruby
# app/components/profile_card_component.rb
class ProfileCardComponent < ViewComponent::Base
  renders_one :avatar
  renders_one :badge
  renders_many :actions, ->(text:, url:, **options) do
    link_to text, url, class: action_classes, **options
  end

  strip_trailing_whitespace

  def initialize(profile:, variant: :default, show_details: false, **html_attributes)
    @profile = profile
    @variant = variant
    @show_details = show_details
    @html_attributes = html_attributes
  end

  def before_render
    @formatted_name = @profile.full_name.titleize
  end

  def render?
    @profile.present? && @profile.active?
  end

  private

  def card_classes
    base = "profile-card"
    variants = {
      default: "profile-card--default",
      compact: "profile-card--compact",
      detailed: "profile-card--detailed"
    }

    "#{base} #{variants[@variant]}"
  end

  def action_classes
    "profile-card__action"
  end

  def html_attributes
    default_attrs = { data: { controller: "profile-card" } }
    default_attrs.merge(@html_attributes)
      .map { |k, v| "#{k}='#{v}'" }
      .join(" ")
      .html_safe
  end
end
```

```erb
<%# app/components/profile_card_component.html.erb %>
<div class="<%= card_classes %>" <%= html_attributes %>>
  <div class="profile-card__header">
    <% if avatar? %>
      <%= avatar %>
    <% else %>
      <div class="profile-card__avatar-placeholder">
        <%= @profile.initials %>
      </div>
    <% end %>

    <div class="profile-card__info">
      <h3 class="profile-card__name"><%= @formatted_name %></h3>
      <% if @show_details %>
        <p class="profile-card__details"><%= @profile.email %></p>
      <% end %>
    </div>

    <% if badge? %>
      <div class="profile-card__badge">
        <%= badge %>
      </div>
    <% end %>
  </div>

  <% if actions? %>
    <div class="profile-card__actions">
      <% actions.each do |action| %>
        <%= action %>
      <% end %>
    </div>
  <% end %>
</div>
```

## Collection Rendering

```ruby
# app/components/item_card_component.rb
class ItemCardComponent < ViewComponent::Base
  with_collection_parameter :item

  def initialize(item:, item_counter: nil, item_iteration: nil)
    @item = item
    @counter = item_counter
    @iteration = item_iteration
  end

  def featured?
    @iteration&.first?
  end

  def card_classes
    classes = ["item-card"]
    classes << "item-card--featured" if featured?
    classes.join(" ")
  end
end
```

```erb
<%# app/views/items/index.html.erb %>
<div class="items-grid">
  <%= render(ItemCardComponent.with_collection(@items)) %>
</div>
```

## Polymorphic Slots

```ruby
# app/components/list_item_component.rb
class ListItemComponent < ViewComponent::Base
  renders_one :visual, types: {
    icon: IconComponent,
    avatar: ->(src:, alt:, **options) do
      AvatarComponent.new(src: src, alt: alt, size: :small, **options)
    end,
    image: ImageComponent
  }

  renders_one :content
  renders_many :actions, "ActionComponent"

  def initialize(title:, **html_attributes)
    @title = title
    @html_attributes = html_attributes
  end

  class ActionComponent < ViewComponent::Base
    def initialize(label:, url:, **html_attributes)
      @label = label
      @url = url
      @html_attributes = html_attributes
    end
  end
end
```

```erb
<%# Usage %>
<%= render(ListItemComponent.new(title: "John Doe")) do |item| %>
  <% item.with_visual_avatar(src: "/avatar.jpg", alt: "John") %>
  <% item.with_content do %>
    <p>Software Engineer</p>
  <% end %>
  <% item.with_action(label: "View", url: "#") %>
  <% item.with_action(label: "Edit", url: "#") %>
<% end %>
```

## Stimulus Integration

```ruby
# app/components/dropdown_component.rb
class DropdownComponent < ViewComponent::Base
  renders_one :trigger
  renders_many :items, "ItemComponent"

  def initialize(position: :bottom, **html_attributes)
    @position = position
    @html_attributes = html_attributes
  end

  def dropdown_data
    {
      controller: "dropdown",
      dropdown_position_value: @position,
      action: "click@window->dropdown#close"
    }
  end

  class ItemComponent < ViewComponent::Base
    def initialize(text:, url: nil, method: :get, **html_attributes)
      @text = text
      @url = url
      @method = method
      @html_attributes = html_attributes
    end
  end
end
```

```erb
<%# app/components/dropdown_component.html.erb %>
<div data-<%= dropdown_data.map { |k, v| "#{k}='#{v}'" }.join(" ") %> class="dropdown">
  <div data-action="click->dropdown#toggle">
    <%= trigger %>
  </div>

  <div data-dropdown-target="menu" class="dropdown-menu hidden">
    <% items.each do |item| %>
      <%= item %>
    <% end %>
  </div>
</div>
```

## i18n Translations

```ruby
# app/components/notification_component.rb
class NotificationComponent < ViewComponent::Base
  def initialize(type: :info)
    @type = type
  end

  def title
    t(".title.#{@type}")
  end

  def icon
    t(".icon.#{@type}")
  end
end
```

```yaml
# app/components/notification_component.yml
en:
  title:
    info: "Information"
    warning: "Warning"
    error: "Error"
    success: "Success"
  icon:
    info: "ℹ️"
    warning: "⚠️"
    error: "❌"
    success: "✅"

fr:
  title:
    info: "Information"
    warning: "Attention"
    error: "Erreur"
    success: "Succès"
```

## Anti-Patterns to Avoid

### Business Logic in Components

```ruby
# BAD
class OrderComponent < ViewComponent::Base
  def initialize(order:)
    @order = order
    @total = calculate_total_with_tax_and_discount  # Do NOT compute here
    @order.update!(processed: true)                 # NEVER side effects!
  end
end

# GOOD
class OrderComponent < ViewComponent::Base
  def initialize(order:, total:)
    @order = order
    @total = total  # Receives already calculated data
  end
end
```

### Overly Generic Components

```ruby
# BAD - Too abstract
class GenericComponent < ViewComponent::Base
  def initialize(type:, data:, options: {})
    # Too flexible = difficult to maintain
  end
end

# GOOD - Specific and clear
class ProfileHeaderComponent < ViewComponent::Base
  def initialize(profile:, show_actions: false)
    @profile = profile
    @show_actions = show_actions
  end
end
```

### Hidden Dependencies

```ruby
# BAD - Depends on global variables
class NavigationComponent < ViewComponent::Base
  def initialize
    @user = Current.user  # Hidden coupling
  end
end

# GOOD - Explicit dependencies
class NavigationComponent < ViewComponent::Base
  def initialize(user:)
    @user = user
  end
end
```
