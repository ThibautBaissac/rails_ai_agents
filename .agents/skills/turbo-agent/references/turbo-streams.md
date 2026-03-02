# Turbo Streams Reference

## Stream Actions Reference

| Action | Description | Usage |
|--------|-------------|-------|
| `append` | Add to end of target | Add new item to list |
| `prepend` | Add to beginning of target | New message at top |
| `replace` | Replace entire target | Update a resource |
| `update` | Replace target's content (not element) | Update inner HTML |
| `remove` | Remove target element | Delete from list |
| `before` | Insert before target | Insert above |
| `after` | Insert after target | Insert below |
| `morph` | Morph target content (Turbo 8) | Smooth updates |
| `refresh` | Trigger page refresh (Turbo 8) | Full page morph |

## Controller with Turbo Streams

```ruby
# app/controllers/resources_controller.rb
class ResourcesController < ApplicationController
  def create
    @resource = Resource.new(resource_params)
    authorize @resource

    respond_to do |format|
      if @resource.save
        format.turbo_stream  # Renders create.turbo_stream.erb
        format.html { redirect_to @resource, notice: "Created!" }
      else
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            "resource_form",
            partial: "form",
            locals: { resource: @resource }
          )
        end
        format.html { render :new, status: :unprocessable_entity }
      end
    end
  end

  def update
    @resource = Resource.find(params[:id])
    authorize @resource

    respond_to do |format|
      if @resource.update(resource_params)
        format.turbo_stream
        format.html { redirect_to @resource, notice: "Updated!" }
      else
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            dom_id(@resource),
            partial: "form",
            locals: { resource: @resource }
          )
        end
        format.html { render :edit, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @resource = Resource.find(params[:id])
    authorize @resource
    @resource.destroy!

    respond_to do |format|
      format.turbo_stream  # Renders destroy.turbo_stream.erb
      format.html { redirect_to resources_path, notice: "Deleted!" }
    end
  end
end
```

## Turbo Stream Templates

```erb
<%# app/views/resources/create.turbo_stream.erb %>
<%= turbo_stream.prepend "resources" do %>
  <%= render @resource %>
<% end %>

<%= turbo_stream.replace "resource_form" do %>
  <%= render "form", resource: Resource.new %>
<% end %>

<%= turbo_stream.prepend "flash" do %>
  <%= render "shared/flash", message: "Resource created!", type: :success %>
<% end %>
```

```erb
<%# app/views/resources/update.turbo_stream.erb %>
<%= turbo_stream.replace dom_id(@resource) do %>
  <%= render @resource %>
<% end %>

<%= turbo_stream.prepend "flash" do %>
  <%= render "shared/flash", message: "Resource updated!", type: :success %>
<% end %>
```

```erb
<%# app/views/resources/destroy.turbo_stream.erb %>
<%= turbo_stream.remove dom_id(@resource) %>

<%= turbo_stream.prepend "flash" do %>
  <%= render "shared/flash", message: "Resource deleted!", type: :info %>
<% end %>
```

## Multiple Streams in One Response

```erb
<%# app/views/resources/create.turbo_stream.erb %>
<%= turbo_stream.prepend "resources", @resource %>
<%= turbo_stream.update "resources_count", Resource.count %>
<%= turbo_stream.replace "new_resource_form", partial: "form", locals: { resource: Resource.new } %>
<%= turbo_stream.remove "empty_state" %>
```

## Inline Turbo Streams (Controller)

```ruby
def toggle_favorite
  @resource = Resource.find(params[:id])
  @resource.toggle_favorite!(current_user)

  render turbo_stream: [
    turbo_stream.replace(
      dom_id(@resource, :favorite_button),
      partial: "favorite_button",
      locals: { resource: @resource }
    ),
    turbo_stream.update(
      "favorites_count",
      current_user.favorites.count
    )
  ]
end
```

## Turbo Streams with Morph (Turbo 8)

```erb
<%# Morph preserves focus and scroll position %>
<%= turbo_stream.morph dom_id(@resource) do %>
  <%= render @resource %>
<% end %>

<%# Refresh the entire page with morphing %>
<%= turbo_stream.refresh %>
```

## Flash Messages with Turbo

```erb
<%# app/views/layouts/application.html.erb %>
<body>
  <div id="flash">
    <%= render "shared/flash_messages" %>
  </div>
  <%= yield %>
</body>
```

```erb
<%# app/views/shared/_flash_messages.html.erb %>
<% flash.each do |type, message| %>
  <%= render "shared/flash", type: type, message: message %>
<% end %>
```

```erb
<%# app/views/shared/_flash.html.erb %>
<div class="flash flash-<%= type %>"
     data-controller="flash"
     data-flash-delay-value="5000">
  <%= message %>
  <button data-action="flash#dismiss">×</button>
</div>
```

```erb
<%# Include flash in stream responses %>
<%= turbo_stream.update "flash" do %>
  <%= render "shared/flash", type: :success, message: "Saved!" %>
<% end %>
```

## Common Patterns

### Empty State Handling

```erb
<%# app/views/resources/index.html.erb %>
<div id="resources">
  <% if @resources.any? %>
    <%= render @resources %>
  <% else %>
    <div id="empty_state">
      <p>No resources yet. Create your first one!</p>
    </div>
  <% end %>
</div>
```

```erb
<%# app/views/resources/create.turbo_stream.erb %>
<%= turbo_stream.remove "empty_state" %>
<%= turbo_stream.prepend "resources", @resource %>
```

### Infinite Scroll

```erb
<%# app/views/resources/index.html.erb %>
<div id="resources">
  <%= render @resources %>
</div>

<%= turbo_frame_tag "pagination",
                    src: resources_path(page: @next_page),
                    loading: :lazy do %>
  <div class="loading">Loading more...</div>
<% end %>
```

```erb
<%# Returned for frame request %>
<%= turbo_frame_tag "pagination",
                    src: (@next_page ? resources_path(page: @next_page) : nil),
                    loading: :lazy do %>
  <% if @next_page %>
    <div class="loading">Loading more...</div>
  <% end %>
<% end %>
```

### Optimistic UI Updates

```javascript
// app/javascript/controllers/optimistic_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["item"]

  delete(event) {
    // Immediately hide (optimistic)
    this.itemTarget.classList.add("opacity-50", "pointer-events-none")
    // Let Turbo handle the actual deletion
  }
}
```
