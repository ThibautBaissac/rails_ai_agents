# Turbo Drive Reference

## Turbo Drive Configuration (Layout)

```erb
<%# app/views/layouts/application.html.erb %>
<!DOCTYPE html>
<html>
  <head>
    <meta name="turbo-refresh-method" content="morph">
    <meta name="turbo-refresh-scroll" content="preserve">
    <%= turbo_refreshes_with method: :morph, scroll: :preserve %>
    <%= yield :head %>
  </head>
  <body>
    <%= yield %>
  </body>
</html>
```

## Page Refresh with Morphing

```ruby
# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  before_action :set_turbo_refresh_method

  private

  def set_turbo_refresh_method
    turbo_refreshes_with method: :morph, scroll: :preserve
  end
end
```

## Disabling Turbo Drive

```erb
<%# Disable for a specific link %>
<%= link_to "External", external_url, data: { turbo: false } %>

<%# Disable for a form %>
<%= form_with model: @resource, data: { turbo: false } do |f| %>
  <%# Full page reload on submit %>
<% end %>

<%# Disable for a section %>
<div data-turbo="false">
  <%# All links/forms here bypass Turbo %>
</div>
```

## Progress Bar

```css
/* app/assets/stylesheets/turbo.css */
.turbo-progress-bar {
  height: 3px;
  background-color: #3b82f6; /* Tailwind blue-500 */
}
```

```javascript
// Customize progress bar delay (default: 500ms)
Turbo.setProgressBarDelay(200)
```

## Prefetching Links

```erb
<%# Prefetch on hover (Turbo 8 default) %>
<%= link_to "Resource", resource_path(@resource) %>

<%# Disable prefetch for specific links %>
<%= link_to "Heavy Page", heavy_path, data: { turbo_prefetch: false } %>

<%# Prefetch immediately (eager) %>
<%= link_to "Important", important_path, data: { turbo_prefetch: "eager" } %>
```

## View Transitions (Turbo 8)

```erb
<%# app/views/layouts/application.html.erb %>
<head>
  <meta name="view-transition" content="same-origin">
</head>
```

```css
/* app/assets/stylesheets/transitions.css */

::view-transition-old(root),
::view-transition-new(root) {
  animation-duration: 0.3s;
}

.resource-card {
  view-transition-name: resource-card;
}

::view-transition-old(resource-card) {
  animation: fade-out 0.2s ease-out;
}

::view-transition-new(resource-card) {
  animation: fade-in 0.2s ease-in;
}

@keyframes fade-out {
  from { opacity: 1; }
  to { opacity: 0; }
}

@keyframes fade-in {
  from { opacity: 0; }
  to { opacity: 1; }
}
```

```erb
<%= link_to "Skip Transition",
            resource_path,
            data: { turbo_view_transition: false } %>
```

## Permanent Elements

```erb
<%# Elements with data-turbo-permanent persist across navigations %>
<audio id="player" data-turbo-permanent>
  <source src="<%= @track.url %>">
</audio>

<video id="video-player" data-turbo-permanent>
  <%# ... %>
</video>

<nav id="sidebar" data-turbo-permanent data-controller="sidebar">
  <%# Sidebar content %>
</nav>
```
