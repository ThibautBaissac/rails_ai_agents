# Turbo Frames Reference

## Lazy-loaded frame

```erb
<%# app/views/cards/show.html.erb %>
<div class="card">
  <h1><%= @card.title %></h1>

  <%# Comments load lazily when frame becomes visible %>
  <%= turbo_frame_tag dom_id(@card, :comments), src: card_comments_path(@card), loading: :lazy do %>
    <p>Loading comments...</p>
  <% end %>
</div>
```

```erb
<%# app/views/cards/comments/_list.html.erb %>
<%= turbo_frame_tag dom_id(@card, :comments) do %>
  <div class="comments">
    <%= render @comments %>
  </div>
<% end %>
```

The response must wrap content in a matching `turbo_frame_tag` with the same ID.

## Modal pattern

```erb
<%# app/views/cards/index.html.erb %>

<%# Empty frame that gets filled when link is clicked %>
<%= turbo_frame_tag "modal" %>

<%= link_to "New Card", new_card_path, data: { turbo_frame: "modal" } %>
```

```erb
<%# app/views/cards/new.html.erb %>
<%= turbo_frame_tag "modal" do %>
  <div class="modal">
    <div class="modal__content">
      <h2>New Card</h2>
      <%= form_with model: @card, data: { turbo_frame: "_top" } do |f| %>
        <%= f.text_field :title %>
        <%= f.text_area :body %>
        <%= f.submit "Create Card" %>
      <% end %>
      <%= link_to "Cancel", cards_path, data: { turbo_frame: "_top" } %>
    </div>
  </div>
<% end %>
```

Note: The form targets `_top` so successful submission navigates the full page.

## Inline editing

```erb
<%# app/views/cards/_card.html.erb (show mode) %>
<%= turbo_frame_tag card do %>
  <article class="card">
    <h2><%= link_to card.title, edit_card_path(card) %></h2>
    <p><%= card.body %></p>
  </article>
<% end %>
```

```erb
<%# app/views/cards/edit.html.erb (edit mode) %>
<%= turbo_frame_tag @card do %>
  <%= form_with model: @card do |f| %>
    <%= f.text_field :title %>
    <%= f.text_area :body %>
    <%= f.submit "Save" %>
    <%= link_to "Cancel", @card %>
  <% end %>
<% end %>
```

Clicking the title link replaces the frame with the edit form. Submitting or canceling replaces it back.

## Frame targets

```erb
<%# _top: Replace entire page (break out of frame) %>
<%= form_with model: @card, data: { turbo_frame: "_top" } %>
<%= link_to "Cancel", cards_path, data: { turbo_frame: "_top" } %>

<%# _self: Update current frame (default behavior) %>
<%= link_to "Edit", edit_card_path(@card), data: { turbo_frame: "_self" } %>

<%# Named frame: Target a specific frame elsewhere on page %>
<%= link_to "New", new_card_path, data: { turbo_frame: "modal" } %>
```

## Optimistic UI with frames

```erb
<%# Star toggle -- frame replaces itself on each click %>
<%= turbo_frame_tag dom_id(card, :star) do %>
  <%= button_to card_star_path(card),
      method: card.starred? ? :delete : :post,
      class: "star-button",
      data: { turbo_frame: dom_id(card, :star) } do %>
    <%= card.starred? ? "filled-star" : "empty-star" %>
  <% end %>
<% end %>
```

## Nested frames

Frames can be nested. Each frame independently loads and updates its content:

```erb
<%= turbo_frame_tag "board" do %>
  <h1>Board</h1>

  <%# Each column is its own frame %>
  <% @board.columns.each do |column| %>
    <%= turbo_frame_tag dom_id(column), src: column_path(column), loading: :lazy do %>
      <p>Loading column...</p>
    <% end %>
  <% end %>
<% end %>
```

## Key rules for frames

1. **Matching IDs:** The response must contain a frame with the same ID as the requesting frame
2. **Scoped navigation:** Links and forms inside a frame target that frame by default
3. **Break out with `_top`:** Use `data: { turbo_frame: "_top" }` to navigate the full page
4. **Lazy loading:** Add `src` and `loading: :lazy` to defer content loading
5. **Empty frames:** An empty `turbo_frame_tag "modal"` acts as a placeholder
