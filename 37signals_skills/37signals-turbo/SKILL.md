---
name: 37signals-turbo
description: Create Turbo Streams, Turbo Frames, and morphing for real-time UI updates. Triggers on Turbo, Turbo Stream, Turbo Frame, real-time, broadcast, live updates.
allowed-tools: Read, Write, Edit, Bash
---

# 37signals Turbo Skill

## Overview

Build reactive UIs with Turbo Streams, Turbo Frames, and morphing. No React/Vue needed. Turbo + server-rendered HTML = rich, reactive UIs.

## Core Philosophy

- **Turbo is plenty**: No client-side frameworks needed
- **Server is source of truth**: No client-side state management
- **Progressive enhancement**: Works without JavaScript
- **Real-time via broadcasts**: WebSockets for live updates

## Turbo Stream Actions

```ruby
# 7 built-in actions
turbo_stream.append "cards", partial: "cards/card", locals: { card: @card }
turbo_stream.prepend "cards", partial: "cards/card", locals: { card: @card }
turbo_stream.replace @card, partial: "cards/card", locals: { card: @card }
turbo_stream.update @card, partial: "cards/card_content", locals: { card: @card }
turbo_stream.remove @card
turbo_stream.before @card, partial: "cards/form"
turbo_stream.after @card, partial: "cards/comment"

# Morphing (preserves focus, scroll position)
turbo_stream.morph @card, partial: "cards/card", locals: { card: @card }
```

## Pattern 1: Controller Responses

```ruby
class Cards::CommentsController < ApplicationController
  def create
    @comment = @card.comments.create!(comment_params)

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to @card }
    end
  end

  def destroy
    @comment = @card.comments.find(params[:id])
    @comment.destroy!

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to @card }
    end
  end
end
```

```erb
<%# app/views/cards/comments/create.turbo_stream.erb %>
<%= turbo_stream.prepend "comments", @comment %>
<%= turbo_stream.update dom_id(@card, :comment_form), partial: "comments/form" %>
<%= turbo_stream.update dom_id(@card, :comment_count) do %>
  <%= pluralize(@card.comments.count, "comment") %>
<% end %>
```

```erb
<%# app/views/cards/comments/destroy.turbo_stream.erb %>
<%= turbo_stream.remove @comment %>
<%= turbo_stream.update dom_id(@card, :comment_count) do %>
  <%= pluralize(@card.comments.count, "comment") %>
<% end %>
```

## Pattern 2: Broadcasting (Real-Time)

```ruby
# app/models/card/broadcastable.rb
module Card::Broadcastable
  extend ActiveSupport::Concern

  included do
    after_create_commit :broadcast_creation
    after_update_commit :broadcast_update
    after_destroy_commit :broadcast_removal
  end

  private

  def broadcast_creation
    broadcast_prepend_to board, :cards, target: "cards"
  end

  def broadcast_update
    broadcast_replace_to board, target: self
  end

  def broadcast_removal
    broadcast_remove_to board, target: self
  end
end
```

```erb
<%# Subscribe to broadcasts %>
<%= turbo_stream_from @board, :cards %>

<div id="cards">
  <%= render @board.cards %>
</div>
```

## Pattern 3: Turbo Frames

### Lazy Loading

```erb
<%= turbo_frame_tag dom_id(@card, :comments),
    src: card_comments_path(@card),
    loading: :lazy do %>
  <p>Loading comments...</p>
<% end %>
```

### Modal in Frame

```erb
<%# Empty modal frame %>
<%= turbo_frame_tag "modal" %>

<%# Link loads into modal %>
<%= link_to "New Card", new_card_path, data: { turbo_frame: "modal" } %>
```

```erb
<%# app/views/cards/new.html.erb %>
<%= turbo_frame_tag "modal" do %>
  <div class="modal">
    <%= form_with model: @card, data: { turbo_frame: "_top" } do |f| %>
      <%= f.text_field :title %>
      <%= f.submit "Create" %>
    <% end %>
  </div>
<% end %>
```

### Inline Editing

```erb
<%# Show mode %>
<%= turbo_frame_tag card do %>
  <h2><%= link_to card.title, edit_card_path(card) %></h2>
<% end %>
```

```erb
<%# Edit mode (replaces frame) %>
<%= turbo_frame_tag @card do %>
  <%= form_with model: @card do |f| %>
    <%= f.text_field :title %>
    <%= f.submit "Save" %>
    <%= link_to "Cancel", @card %>
  <% end %>
<% end %>
```

## Pattern 4: Flash Messages

```erb
<%# In response %>
<%= turbo_stream.prepend "flash" do %>
  <div class="flash flash--notice" data-controller="auto-dismiss">
    <%= message %>
  </div>
<% end %>
```

## Pattern 5: Multiple Updates

```erb
<%# Update many elements at once %>
<%= turbo_stream.replace @card %>
<%= turbo_stream.update "card_count" do %><%= @board.cards.count %><% end %>
<%= turbo_stream.prepend "flash" do %>Notice<% end %>
```

## Pattern 6: Morphing

```html
<!-- Enable globally in layout -->
<meta name="turbo-refresh-method" content="morph">
<meta name="turbo-refresh-scroll" content="preserve">
```

```ruby
# Use for form-heavy updates
turbo_stream.morph dom_id(@card), partial: "cards/card"
```

## Frame Targets

```erb
<!-- Replace entire page -->
<%= form_with model: @card, data: { turbo_frame: "_top" } %>

<!-- Update current frame (default) -->
<%= link_to "Edit", edit_path, data: { turbo_frame: "_self" } %>

<!-- Target named frame -->
<%= link_to "New", new_path, data: { turbo_frame: "modal" } %>
```

## Testing

```ruby
test "create returns turbo stream" do
  post card_comments_path(@card),
    params: { comment: { body: "Test" } },
    as: :turbo_stream

  assert_response :success
  assert_equal "text/vnd.turbo-stream.html", response.media_type
  assert_match /turbo-stream/, response.body
end
```

```ruby
# System test
test "real-time comment appears" do
  visit card_path(@card)

  using_session(:other_user) do
    sign_in_as users(:jason)
    visit card_path(@card)
    fill_in "Body", with: "From another user"
    click_button "Add Comment"
  end

  assert_text "From another user"  # Appears via broadcast
end
```

## Boundaries

### Always
- Use Turbo Streams for create/update/destroy
- Broadcast changes to relevant streams
- Use `dom_id` for consistent element IDs
- Provide fallback HTML responses
- Use morphing for form-heavy updates
- Lazy load expensive content

### Never
- Mix Turbo with React/Vue
- Forget to subscribe to streams
- Use inline turbo-stream tags (use helpers)
- Broadcast on every tiny change
- Use Turbo for file uploads (use direct upload)
