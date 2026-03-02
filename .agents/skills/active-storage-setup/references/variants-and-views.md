# Active Storage: Image Variants and Views

## Defining Variants

```ruby
class User < ApplicationRecord
  has_one_attached :avatar do |attachable|
    attachable.variant :thumb, resize_to_fill: [100, 100]
    attachable.variant :medium, resize_to_limit: [300, 300]
    attachable.variant :large, resize_to_limit: [800, 800]
  end
end
```

## Variant Operations Reference

```ruby
# Resize to fit within dimensions (maintains aspect ratio)
resize_to_limit: [300, 300]

# Resize and crop to exact dimensions
resize_to_fill: [300, 300]

# Resize to cover dimensions (may exceed)
resize_to_cover: [300, 300]

# Custom processing
resize_to_limit: [300, 300], format: :webp, saver: { quality: 80 }
```

## Using Variants in Views

```erb
<%# With named variant %>
<%= image_tag user.avatar.variant(:thumb) %>

<%# Inline variant %>
<%= image_tag user.avatar.variant(resize_to_limit: [200, 200]) %>

<%# With fallback %>
<% if user.avatar.attached? %>
  <%= image_tag user.avatar.variant(:thumb), alt: user.name %>
<% else %>
  <%= image_tag "default-avatar.png", alt: "Default" %>
<% end %>
```

## Form: Single File Upload

```erb
<%# app/views/users/_form.html.erb %>
<%= form_with model: @user do |f| %>
  <div class="field">
    <%= f.label :avatar %>
    <%= f.file_field :avatar, accept: "image/png,image/jpeg,image/webp" %>

    <% if @user.avatar.attached? %>
      <div class="mt-2">
        <%= image_tag @user.avatar.variant(:thumb), class: "rounded" %>
        <%= link_to "Remove", remove_avatar_user_path(@user), method: :delete %>
      </div>
    <% end %>
  </div>

  <%= f.submit %>
<% end %>
```

## Form: Multiple File Upload

```erb
<%# app/views/events/_form.html.erb %>
<%= form_with model: @event do |f| %>
  <div class="field">
    <%= f.label :photos %>
    <%= f.file_field :photos, multiple: true, accept: "image/*" %>

    <% if @event.photos.attached? %>
      <div class="grid grid-cols-4 gap-2 mt-2">
        <% @event.photos.each do |photo| %>
          <div class="relative">
            <%= image_tag photo.variant(:thumb), class: "rounded" %>
            <%= button_to "x", remove_photo_event_path(@event, photo_id: photo.id),
                          method: :delete, class: "absolute top-0 right-0" %>
          </div>
        <% end %>
      </div>
    <% end %>
  </div>

  <%= f.submit %>
<% end %>
```
