---
name: hotwire-patterns
description: >-
  Implements Hotwire patterns with Turbo Frames, Turbo Streams, and Stimulus
  controllers. Use when building interactive UIs, real-time updates, form
  handling, partial page updates, or when user mentions Turbo, Stimulus,
  or Hotwire.
license: MIT
compatibility: Ruby 3.3+, Rails 8.1+, Hotwire (Turbo + Stimulus)
metadata:
  author: ThibautBaissac
  version: "1.0"
---

# Hotwire Patterns for Rails 8

## Overview

Hotwire = HTML Over The Wire - Build modern web apps without writing much JavaScript.

| Component | Purpose | Use Case |
|-----------|---------|----------|
| **Turbo Drive** | SPA-like navigation | Automatic, no code needed |
| **Turbo Frames** | Partial page updates | Inline editing, tabbed content |
| **Turbo Streams** | Real-time DOM updates | Live updates, flash messages |
| **Stimulus** | JavaScript sprinkles | Toggles, forms, interactions |

## Quick Start

### Turbo Frames (Scoped Navigation)

```erb
<%# app/views/posts/index.html.erb %>
<%= turbo_frame_tag "posts" do %>
  <%= render @posts %>
  <%= link_to "Load More", posts_path(page: 2) %>
<% end %>

<%# Clicking "Load More" only updates content inside this frame %>
```

### Turbo Streams (Real-time Updates)

```erb
<%# app/views/posts/create.turbo_stream.erb %>
<%= turbo_stream.prepend "posts", @post %>
<%= turbo_stream.update "flash", partial: "shared/flash" %>
```

### Stimulus Controller

```javascript
// app/javascript/controllers/toggle_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["content"]

  toggle() {
    this.contentTarget.classList.toggle("hidden")
  }
}
```

```erb
<div data-controller="toggle">
  <button data-action="toggle#toggle">Toggle</button>
  <div data-toggle-target="content">Hidden content</div>
</div>
```

## Workflow Checklist

```
Hotwire Implementation:
- [ ] Identify update scope (full page vs partial)
- [ ] Choose pattern (Frame vs Stream vs Stimulus)
- [ ] Implement server response
- [ ] Add client-side markup
- [ ] Test with and without JavaScript
- [ ] Write system spec
```

## When to Use Each Pattern

| Scenario | Pattern | Why |
|----------|---------|-----|
| Inline edit | Turbo Frame | Scoped replacement |
| Form submission | Turbo Stream | Multiple updates |
| Real-time feed | Turbo Stream + ActionCable | Push updates |
| Toggle visibility | Stimulus | No server needed |
| Form validation | Stimulus | Client-side feedback |
| Infinite scroll | Turbo Frame + lazy loading | Paginated content |
| Modal dialogs | Turbo Frame | Load on demand |
| Flash messages | Turbo Stream | Append/update |

## References

- See [turbo-frames.md](references/turbo-frames.md) for frame patterns
- See [turbo-streams.md](references/turbo-streams.md) for stream patterns
- See [stimulus.md](references/stimulus.md) for controller patterns

## Testing Hotwire

### System Specs

```ruby
# spec/system/posts_spec.rb
require 'rails_helper'

RSpec.describe "Posts", type: :system do
  before { driven_by(:selenium_chrome_headless) }

  it "updates post inline with Turbo Frame" do
    post = create(:post, title: "Original")

    visit posts_path
    within("#post_#{post.id}") do
      click_link "Edit"
      fill_in "Title", with: "Updated"
      click_button "Save"
    end

    expect(page).to have_content("Updated")
    expect(page).not_to have_content("Original")
  end

  it "adds comment with Turbo Stream" do
    post = create(:post)

    visit post_path(post)
    fill_in "Comment", with: "Great post!"
    click_button "Add Comment"

    within("#comments") do
      expect(page).to have_content("Great post!")
    end
  end
end
```

### Request Specs for Turbo Stream

```ruby
# spec/requests/posts_spec.rb
RSpec.describe "Posts", type: :request do
  describe "POST /posts" do
    let(:valid_params) { { post: { title: "Test" } } }

    it "returns turbo stream response" do
      post posts_path, params: valid_params,
           headers: { "Accept" => "text/vnd.turbo-stream.html" }

      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(response.body).to include("turbo-stream")
    end
  end
end
```

## Common Patterns

### Inline Editing with Frame

```erb
<%# _post.html.erb %>
<%= turbo_frame_tag dom_id(post) do %>
  <article>
    <h2><%= post.title %></h2>
    <%= link_to "Edit", edit_post_path(post) %>
  </article>
<% end %>

<%# edit.html.erb %>
<%= turbo_frame_tag dom_id(@post) do %>
  <%= form_with model: @post do |f| %>
    <%= f.text_field :title %>
    <%= f.submit "Save" %>
    <%= link_to "Cancel", @post %>
  <% end %>
<% end %>
```

### Flash Messages with Stream

```ruby
# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  after_action :flash_to_turbo_stream, if: -> { request.format.turbo_stream? }

  private

  def flash_to_turbo_stream
    flash.each do |type, message|
      flash.now[type] = message
    end
  end
end
```

### Lazy Loading Frame

```erb
<%= turbo_frame_tag "comments", src: post_comments_path(@post), loading: :lazy do %>
  <p>Loading comments...</p>
<% end %>
```

## Debugging Tips

1. **Frame not updating?** Check frame IDs match exactly
2. **Stream not working?** Verify `Accept` header includes turbo-stream
3. **Stimulus not firing?** Check controller name matches file name
4. **Events not working?** Use `data-action="event->controller#method"`
