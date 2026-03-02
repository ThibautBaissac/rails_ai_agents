# Turbo Frames Reference

## Basic Frame Structure

```erb
<%# app/views/resources/index.html.erb %>
<h1>Resources</h1>

<%= turbo_frame_tag "resources" do %>
  <% @resources.each do |resource| %>
    <%= render resource %>
  <% end %>

  <%= paginate @resources %>
<% end %>
```

## Frame Navigation

```erb
<%# Link navigates within the frame %>
<%= turbo_frame_tag "resource_#{@resource.id}" do %>
  <%= link_to @resource.name, edit_resource_path(@resource) %>
<% end %>

<%# edit.html.erb must have matching frame %>
<%= turbo_frame_tag "resource_#{@resource.id}" do %>
  <%= render "form", resource: @resource %>
<% end %>
```

## Breaking Out of Frames

```erb
<%# Break out to full page %>
<%= link_to "View All", resources_path, data: { turbo_frame: "_top" } %>

<%# Target a different frame %>
<%= link_to "Preview", preview_path, data: { turbo_frame: "preview_panel" } %>
```

## Lazy Loading Frames

```erb
<%= turbo_frame_tag "comments",
                    src: comments_path(@post),
                    loading: :lazy do %>
  <div class="animate-pulse">Loading comments...</div>
<% end %>
```

## Frame with Loading State

```erb
<%= turbo_frame_tag "search_results",
                    data: { turbo_frame_loading: "eager" } do %>
  <%= render @resources %>
<% end %>

<style>
  turbo-frame[busy] {
    opacity: 0.5;
    pointer-events: none;
  }
</style>
```

## Inline Editing with Frames

```erb
<%# app/views/resources/_resource.html.erb %>
<%= turbo_frame_tag dom_id(resource) do %>
  <div class="resource-card">
    <h3><%= resource.name %></h3>
    <p><%= resource.description %></p>
    <%= link_to "Edit", edit_resource_path(resource), class: "btn" %>
  </div>
<% end %>

<%# app/views/resources/edit.html.erb %>
<%= turbo_frame_tag dom_id(@resource) do %>
  <%= render "form", resource: @resource %>
<% end %>
```

## Frame Best Practices

```erb
<%# ✅ GOOD - Stable, predictable frame IDs %>
<%= turbo_frame_tag dom_id(@resource) %>
<%= turbo_frame_tag "resource_#{@resource.id}" %>
<%= turbo_frame_tag "comments_list" %>

<%# ❌ BAD - Dynamic/unpredictable IDs %>
<%= turbo_frame_tag "frame_#{rand(1000)}" %>
<%= turbo_frame_tag @resource.updated_at.to_i %>
```

## Form with Frame Target

```erb
<%= form_with model: @resource,
              data: { turbo_frame: "search_results" } do |f| %>
  <%= f.search_field :query %>
  <%= f.submit "Search" %>
<% end %>
```

## Integration with ViewComponents

```ruby
# app/components/editable_resource_component.rb
class EditableResourceComponent < ViewComponent::Base
  def initialize(resource:)
    @resource = resource
  end

  def frame_id
    helpers.dom_id(@resource)
  end
end
```

```erb
<%# app/components/editable_resource_component.html.erb %>
<%= turbo_frame_tag frame_id do %>
  <div class="resource-card">
    <h3><%= @resource.name %></h3>
    <%= link_to "Edit", helpers.edit_resource_path(@resource) %>
  </div>
<% end %>
```
