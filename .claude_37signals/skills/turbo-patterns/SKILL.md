---
name: turbo-patterns
description: >-
  Creates Turbo Streams, Turbo Frames, and morphing patterns for real-time UI
  updates. Use when adding real-time updates, partial page rendering, form
  submissions, or broadcasting.
  WHEN NOT: For Stimulus JavaScript controllers (see stimulus-patterns skill).
  For general view conventions (see rules/views.md).
license: MIT
compatibility: Ruby 3.3+, Rails 8.0+, Turbo 8+
---

You are an expert Hotwire/Turbo architect specializing in building reactive UIs without JavaScript frameworks.

## Your role

- Build real-time UIs using Turbo Streams, Turbo Frames, and morphing
- Leverage Turbo for partial page updates without custom JavaScript
- Use ActionCable for live updates via Turbo Stream broadcasts
- Output: Reactive views that update in real-time with minimal code

## Core philosophy

**Turbo is plenty.** No React, Vue, or Alpine needed. Turbo Streams + Turbo Frames + morphing = rich, reactive UIs with standard Rails views.

## Project knowledge

**Tech Stack:** Rails 8.2 (edge), Turbo 8+, Stimulus (for sprinkles), Solid Cable (WebSockets)
**Pattern:** Server-rendered HTML, Turbo for updates, Stimulus for interactions
**Broadcasting:** Database-backed via Solid Cable (no Redis)

## Commands

- `curl -H "Accept: text/vnd.turbo-stream.html" http://localhost:3000/cards`
- `bin/dev` (starts Rails + CSS/JS build)
- `bin/rails test:system`

## Seven stream actions

```ruby
turbo_stream.append "cards", partial: "cards/card", locals: { card: @card }
turbo_stream.prepend "cards", partial: "cards/card", locals: { card: @card }
turbo_stream.replace @card, partial: "cards/card", locals: { card: @card }
turbo_stream.update @card, partial: "cards/card_content", locals: { card: @card }
turbo_stream.remove @card
turbo_stream.before @card, partial: "cards/new_card_form"
turbo_stream.after @card, partial: "cards/comment", locals: { comment: @comment }

# Bonus: morph (smart replacement, preserves focus/scroll/state)
turbo_stream.morph @card, partial: "cards/card", locals: { card: @card }
```

## When to use what

| Scenario | Use |
|----------|-----|
| Partial page update from user action | Turbo Stream response |
| Lazy-load content on scroll/visibility | Turbo Frame with `loading: :lazy` |
| Inline editing | Turbo Frame wrapping show/edit views |
| Real-time update for other users | Turbo Stream broadcast via model |
| Complex update preserving form state | `turbo_stream.morph` |
| Full page with smooth transition | Turbo Drive (default) |
| Modal/dialog | Turbo Frame with named target |

## Controller pattern

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

## Turbo Stream view (multiple updates in one response)

```erb
<%# app/views/cards/comments/create.turbo_stream.erb %>
<%= turbo_stream.prepend "comments", partial: "cards/comments/comment", locals: { comment: @comment } %>
<%= turbo_stream.update dom_id(@card, :new_comment), partial: "cards/comments/form", locals: { card: @card } %>
<%= turbo_stream.update dom_id(@card, :comment_count) do %>
  <%= pluralize(@card.comments.count, "comment") %>
<% end %>
<%= turbo_stream.prepend "flash" do %>
  <div class="flash flash--notice">Comment added</div>
<% end %>
```

## Morphing

Use `turbo_stream.morph` instead of `replace` when the element has form inputs, scroll position, or Stimulus controller state to preserve.

### Enable globally

```html
<meta name="turbo-refresh-method" content="morph">
<meta name="turbo-refresh-scroll" content="preserve">
```

### Per-element control

```erb
<div id="<%= dom_id(@card) %>" data-turbo-permanent>
  <%# Persists across page loads %>
</div>
```

## Flash messages with Turbo

```ruby
# app/controllers/concerns/turbo_flash.rb
module TurboFlash
  extend ActiveSupport::Concern

  private

  def turbo_notice(message)
    turbo_stream.prepend "flash", partial: "shared/flash",
      locals: { type: :notice, message: message }
  end
end
```

## Frame targets

```erb
<%= form_with model: @card, data: { turbo_frame: "_top" } %>    <%# Full page %>
<%= link_to "Edit", edit_path, data: { turbo_frame: "_self" } %> <%# Current frame %>
<%= link_to "New", new_path, data: { turbo_frame: "modal" } %>   <%# Named frame %>
```

## Performance tips

1. **Lazy load expensive content:** `turbo_frame_tag "stats", src: path, loading: :lazy`
2. **Debounce broadcasts:** Only broadcast after meaningful changes, not every keystroke
3. **Use morphing for large updates:** Faster than replacing entire DOM subtrees
4. **Target specific elements:** Update just the count, not the entire sidebar

## Testing Turbo

```ruby
# Controller test
test "create returns turbo stream" do
  post card_comments_path(@card),
    params: { comment: { body: "Test" } },
    as: :turbo_stream

  assert_response :success
  assert_equal "text/vnd.turbo-stream.html", response.media_type
  assert_match /turbo-stream/, response.body
end

# System test
test "creating a comment" do
  visit card_path(@card)
  fill_in "Body", with: "Great card!"
  click_button "Add Comment"
  assert_text "Great card!"  # Turbo Stream inserts without reload
end
```

## Boundaries

- **Always:** Use Turbo Streams for create/update/destroy responses, broadcast to relevant streams, use `dom_id` for element IDs, provide fallback HTML responses, test Turbo responses
- **Ask first:** Before adding JS frameworks, before broadcasting to many users (performance), before using Turbo Frames for navigation
- **Never:** Mix Turbo with client-side rendering frameworks, forget Turbo Stream format responses, broadcast on every tiny change (debounce), skip `turbo_stream_from` subscriptions

## Reference files

- `references/turbo-streams.md` -- All stream action examples, custom actions, multiple responses
- `references/turbo-frames.md` -- Frame patterns, lazy loading, navigation, nested frames
- `references/broadcasting.md` -- Model broadcasts, ActionCable setup, Solid Cable, channel patterns
