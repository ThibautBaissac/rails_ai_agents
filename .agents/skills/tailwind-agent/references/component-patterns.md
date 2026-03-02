# Tailwind Component Patterns

## Button Variants

```erb
<%# Primary Button %>
<%= button_to "Create", create_path,
    class: "
      bg-blue-600 hover:bg-blue-700 active:bg-blue-800
      text-white font-semibold
      px-4 py-2 rounded-md
      focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2
      transition-colors duration-200
    " %>

<%# Secondary Button %>
<%= link_to "Cancel", back_path,
    class: "
      bg-gray-100 hover:bg-gray-200 active:bg-gray-300
      text-gray-700 font-semibold
      px-4 py-2 rounded-md border border-gray-300
      focus:outline-none focus:ring-2 focus:ring-gray-500 focus:ring-offset-2
      transition-colors duration-200
    " %>

<%# Danger Button %>
<%= button_to "Delete", delete_path, method: :delete,
    data: { turbo_confirm: "Are you sure?" },
    class: "
      bg-red-600 hover:bg-red-700 active:bg-red-800
      text-white font-semibold
      px-4 py-2 rounded-md
      focus:outline-none focus:ring-2 focus:ring-red-500 focus:ring-offset-2
      transition-colors duration-200
    " %>

<%# Icon Button %>
<button type="button"
        aria-label="Close"
        class="
          p-2 rounded-full
          text-gray-400 hover:text-gray-600 hover:bg-gray-100
          focus:outline-none focus:ring-2 focus:ring-gray-500
          transition-colors duration-200
        ">
  <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 20 20">
    <path d="M6.28 5.22a.75.75 0 00-1.06 1.06L8.94 10l-3.72 3.72a.75.75 0 101.06 1.06L10 11.06l3.72 3.72a.75.75 0 101.06-1.06L11.06 10l3.72-3.72a.75.75 0 00-1.06-1.06L10 8.94 6.28 5.22z" />
  </svg>
</button>
```

## Form Fields

```erb
<%# Text Input %>
<div class="space-y-1">
  <%= f.label :name, class: "block text-sm font-medium text-gray-700" %>
  <%= f.text_field :name,
      class: "
        w-full px-3 py-2 rounded-md
        border border-gray-300
        focus:border-blue-500 focus:ring-2 focus:ring-blue-500
        placeholder:text-gray-400
        transition-colors duration-200
      ",
      placeholder: "Enter name..." %>
</div>

<%# Select Dropdown %>
<div class="space-y-1">
  <%= f.label :status, class: "block text-sm font-medium text-gray-700" %>
  <%= f.select :status, ["Active", "Inactive"],
      { include_blank: "Select status" },
      class: "
        w-full px-3 py-2 rounded-md
        border border-gray-300
        focus:border-blue-500 focus:ring-2 focus:ring-blue-500
        transition-colors duration-200
      " %>
</div>

<%# Textarea %>
<div class="space-y-1">
  <%= f.label :description, class: "block text-sm font-medium text-gray-700" %>
  <%= f.text_area :description,
      rows: 4,
      class: "
        w-full px-3 py-2 rounded-md
        border border-gray-300
        focus:border-blue-500 focus:ring-2 focus:ring-blue-500
        placeholder:text-gray-400
        transition-colors duration-200
      ",
      placeholder: "Enter description..." %>
</div>

<%# Checkbox %>
<div class="flex items-center gap-2">
  <%= f.check_box :terms,
      class: "
        w-4 h-4 rounded
        text-blue-600 border-gray-300
        focus:ring-2 focus:ring-blue-500
      " %>
  <%= f.label :terms, "I agree to the terms and conditions",
      class: "text-sm text-gray-700" %>
</div>
```

## Cards

```erb
<%# Basic Card %>
<div class="bg-white rounded-lg shadow-md p-6">
  <h3 class="text-xl font-semibold text-gray-800 mb-2">Card Title</h3>
  <p class="text-gray-600">Card content goes here.</p>
</div>

<%# Card with Header and Footer %>
<div class="bg-white rounded-lg shadow-md overflow-hidden">
  <div class="bg-gray-50 px-6 py-4 border-b border-gray-200">
    <h3 class="text-lg font-semibold text-gray-800">Card Header</h3>
  </div>

  <div class="p-6">
    <p class="text-gray-600">Card body content.</p>
  </div>

  <div class="bg-gray-50 px-6 py-4 border-t border-gray-200 flex justify-end gap-3">
    <%= link_to "Cancel", "#", class: "text-gray-600 hover:text-gray-800" %>
    <%= link_to "Save", "#", class: "text-blue-600 hover:text-blue-800 font-semibold" %>
  </div>
</div>

<%# Hoverable Card (e.g., for lists) %>
<%= link_to item_path(@item), class: "block" do %>
  <div class="
    bg-white rounded-lg shadow-md p-6
    hover:shadow-xl hover:-translate-y-1
    transition-all duration-300
  ">
    <h3 class="text-xl font-semibold text-gray-800 mb-2"><%= @item.title %></h3>
    <p class="text-gray-600"><%= @item.description %></p>
  </div>
<% end %>
```

## Alerts and Notifications

```erb
<%# Success Alert %>
<div class="bg-green-50 border border-green-200 rounded-md p-4" role="alert">
  <div class="flex gap-3">
    <div class="flex-shrink-0">
      <svg class="w-5 h-5 text-green-600" fill="currentColor" viewBox="0 0 20 20">
        <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.857-9.809a.75.75 0 00-1.214-.882l-3.483 4.79-1.88-1.88a.75.75 0 10-1.06 1.061l2.5 2.5a.75.75 0 001.137-.089l4-5.5z" clip-rule="evenodd" />
      </svg>
    </div>
    <div>
      <h4 class="text-sm font-medium text-green-800">Success!</h4>
      <p class="text-sm text-green-700 mt-1">Your changes have been saved.</p>
    </div>
  </div>
</div>

<%# Error Alert %>
<div class="bg-red-50 border border-red-200 rounded-md p-4" role="alert">
  <div class="flex gap-3">
    <div class="flex-shrink-0">
      <svg class="w-5 h-5 text-red-600" fill="currentColor" viewBox="0 0 20 20">
        <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.28 7.22a.75.75 0 00-1.06 1.06L8.94 10l-1.72 1.72a.75.75 0 101.06 1.06L10 11.06l1.72 1.72a.75.75 0 101.06-1.06L11.06 10l1.72-1.72a.75.75 0 00-1.06-1.06L10 8.94 8.28 7.22z" clip-rule="evenodd" />
      </svg>
    </div>
    <div>
      <h4 class="text-sm font-medium text-red-800">Error</h4>
      <p class="text-sm text-red-700 mt-1">Something went wrong. Please try again.</p>
    </div>
  </div>
</div>

<%# Dismissible Alert with Stimulus %>
<div data-controller="dismissible"
     class="bg-blue-50 border border-blue-200 rounded-md p-4"
     role="alert">
  <div class="flex justify-between gap-3">
    <div class="flex gap-3">
      <div class="flex-shrink-0">
        <svg class="w-5 h-5 text-blue-600" fill="currentColor" viewBox="0 0 20 20">
          <path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a.75.75 0 000 1.5h.253a.25.25 0 01.244.304l-.459 2.066A1.75 1.75 0 0010.747 15H11a.75.75 0 000-1.5h-.253a.25.25 0 01-.244-.304l.459-2.066A1.75 1.75 0 009.253 9H9z" clip-rule="evenodd" />
        </svg>
      </div>
      <p class="text-sm text-blue-700">This is an informational message.</p>
    </div>
    <button data-action="dismissible#dismiss"
            aria-label="Dismiss"
            class="
              flex-shrink-0 text-blue-400 hover:text-blue-600
              focus:outline-none focus:ring-2 focus:ring-blue-500 rounded
            ">
      <span aria-hidden="true">&times;</span>
    </button>
  </div>
</div>
```

## Badges

```erb
<%# Status Badges %>
<span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800">
  Active
</span>

<span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-gray-100 text-gray-800">
  Inactive
</span>

<span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-red-100 text-red-800">
  Deleted
</span>

<span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-yellow-100 text-yellow-800">
  Pending
</span>
```

## Loading States

```erb
<%# Spinner %>
<div class="flex items-center justify-center p-4">
  <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
</div>

<%# Skeleton Loader %>
<div class="animate-pulse space-y-4">
  <div class="h-4 bg-gray-200 rounded w-3/4"></div>
  <div class="h-4 bg-gray-200 rounded w-1/2"></div>
  <div class="h-4 bg-gray-200 rounded w-5/6"></div>
</div>

<%# Button with Loading State (using Stimulus) %>
<button data-controller="loading"
        data-action="loading#submit"
        data-loading-text-value="Saving..."
        class="btn-primary">
  <span data-loading-target="text">Save</span>
  <svg data-loading-target="spinner"
       class="hidden animate-spin ml-2 h-4 w-4"
       fill="none"
       viewBox="0 0 24 24">
    <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
    <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
  </svg>
</button>
```

## Turbo Integration

```erb
<%# Turbo Frame with loading state %>
<turbo-frame id="comments"
             src="<%= comments_path %>"
             class="space-y-4"
             loading="lazy">
  <div class="flex items-center justify-center p-8">
    <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
  </div>
</turbo-frame>

<%# Turbo Stream target with transition %>
<div id="notifications"
     class="
       fixed top-4 right-4 z-50 w-80
       space-y-2 pointer-events-none
     ">
  <%# Turbo Streams will append here %>
</div>

<%# Permanent element (survives Turbo morphing) %>
<div id="shopping-cart"
     data-turbo-permanent
     class="fixed top-4 right-4 bg-white shadow-lg rounded-lg p-4">
  <%# Cart contents preserved during navigation %>
</div>
```

## Performance: Extract Repeated Patterns

```ruby
# ❌ BAD - Repeated classes everywhere
<%= link_to "Action", path, class: "bg-blue-600 hover:bg-blue-700 text-white font-semibold py-2 px-4 rounded-lg transition-colors" %>
<%= link_to "Another", path2, class: "bg-blue-600 hover:bg-blue-700 text-white font-semibold py-2 px-4 rounded-lg transition-colors" %>

# ✅ GOOD - Extract to ViewComponent
class ButtonComponent < ViewComponent::Base
  def initialize(text:, url:, variant: :primary)
    @text = text
    @url = url
    @variant = variant
  end

  def button_classes
    base = "font-semibold py-2 px-4 rounded-lg transition-colors"
    case @variant
    when :primary
      "#{base} bg-blue-600 hover:bg-blue-700 text-white"
    when :secondary
      "#{base} bg-gray-100 hover:bg-gray-200 text-gray-700"
    end
  end
end

# Usage
<%= render ButtonComponent.new(text: "Action", url: path) %>
<%= render ButtonComponent.new(text: "Cancel", url: path2, variant: :secondary) %>
```

## Custom Utilities (use sparingly)

```css
/* app/assets/tailwind/application.css */
@import "tailwindcss";

/* Only add custom utilities when absolutely necessary */
@utility btn-primary {
  @apply bg-blue-600 hover:bg-blue-700 text-white font-semibold py-2 px-4 rounded-md transition-colors;
}

@utility input-field {
  @apply w-full px-3 py-2 border border-gray-300 rounded-md focus:border-blue-500 focus:ring-2 focus:ring-blue-500;
}
```

## Real-World: Restaurant Card Component

```erb
<%# app/components/restaurant_card_component.html.erb %>
<div class="<%= card_classes %>">
  <%= link_to restaurant_path(@restaurant), class: "block" do %>
    <div class="mb-3">
      <h3 class="text-xl font-bold text-gray-900 mb-1">
        <%= @restaurant.name %>
      </h3>

      <div class="flex items-center gap-2 mb-2">
        <span class="<%= rating_color %> text-lg font-semibold">
          <%= rating_stars %>
        </span>
        <span class="text-gray-600 text-sm">
          <%= number_with_precision(@restaurant.rating, precision: 1) %>
        </span>
      </div>
    </div>

    <% if @restaurant.description.present? %>
      <p class="text-gray-600 text-sm mb-3 line-clamp-2">
        <%= truncate(@restaurant.description, length: 150) %>
      </p>
    <% end %>
  <% end %>
</div>
```

## Real-World: Index Page with Responsive Grid

```erb
<%# app/views/restaurants/index.html.erb %>
<div class="max-w-7xl mx-auto">
  <div class="flex justify-between items-center mb-8">
    <h1 class="text-4xl font-bold text-gray-900">Restaurants</h1>

    <% if user_signed_in? %>
      <%= link_to "Add Restaurant", new_restaurant_path,
          class: "bg-blue-600 hover:bg-blue-700 text-white font-semibold py-2 px-4 rounded-lg transition-colors" %>
    <% end %>
  </div>

  <% if @restaurants.any? %>
    <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
      <% @restaurants.each do |restaurant| %>
        <%= render RestaurantCardComponent.new(restaurant: restaurant) %>
      <% end %>
    </div>
  <% else %>
    <div class="text-center py-12">
      <p class="text-gray-500 text-lg mb-4">No restaurants found.</p>
    </div>
  <% end %>
</div>
```
