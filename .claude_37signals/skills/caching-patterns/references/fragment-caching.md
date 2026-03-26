# Fragment Caching Reference

## Russian Doll Caching

Nested fragment caches where inner caches are wrapped by outer caches.
When an inner record changes, `touch: true` cascades `updated_at` changes
upward, invalidating all containing cache fragments.

### Model Setup

```ruby
class Board < ApplicationRecord
  has_many :columns, dependent: :destroy
  has_many :cards, dependent: :destroy
end

class Column < ApplicationRecord
  belongs_to :board, touch: true
  has_many :cards, dependent: :destroy
end

class Card < ApplicationRecord
  belongs_to :board, touch: true
  belongs_to :column, touch: true
  has_many :comments, dependent: :destroy
end

class Comment < ApplicationRecord
  belongs_to :card, touch: true
  # Updating comment -> touches card -> touches board
  # All three cache fragments invalidated automatically
end
```

### View Nesting

```erb
<%# app/views/boards/show.html.erb %>
<% cache @board do %>
  <h1><%= @board.name %></h1>
  <p><%= @board.description %></p>

  <div class="columns">
    <% @board.columns.each do |column| %>
      <% cache column do %>
        <h2><%= column.name %></h2>
        <% column.cards.each do |card| %>
          <% cache card do %>
            <%= render card %>
          <% end %>
        <% end %>
      <% end %>
    <% end %>
  </div>
<% end %>

<%# app/views/cards/_card.html.erb %>
<% cache card do %>
  <div class="card" id="<%= dom_id(card) %>">
    <h3><%= card.title %></h3>
    <p><%= card.description %></p>
    <div class="comments">
      <% card.comments.each do |comment| %>
        <% cache comment do %>
          <%= render comment %>
        <% end %>
      <% end %>
    </div>
  </div>
<% end %>
```

### How Cache Keys Work

Rails generates cache keys like:
```
views/boards/123-20250117120000000000/...
views/cards/456-20250117120100000000/...
views/comments/789-20250117120100000000/...
```

When `comment.update!` fires:
1. `comment.updated_at` changes -- comment cache key changes
2. `card.updated_at` changes (via `touch: true`) -- card cache key changes
3. `board.updated_at` changes (via `touch: true`) -- board cache key changes
4. All three old cache fragments are stale and will be regenerated

## Collection Caching

Use `cache_collection` to batch-read cache entries for a collection of records.
Rails issues a single `read_multi` call to the cache store instead of N
individual reads.

```erb
<%# Preferred: cache_collection with partial %>
<div class="boards">
  <% cache_collection @boards, partial: "boards/board" %>
</div>

<%# Manual equivalent (less efficient) %>
<div class="boards">
  <% @boards.each do |board| %>
    <% cache board do %>
      <%= render "boards/board", board: board %>
    <% end %>
  <% end %>
</div>
```

## Cache Helper Options

```erb
<%# Simple cache %>
<% cache @board do %>...<% end %>

<%# With expiration %>
<% cache @board, expires_in: 15.minutes do %>...<% end %>

<%# Custom cache key %>
<% cache ["board", @board, Current.user] do %>...<% end %>

<%# Skip digest (use when template changes should NOT bust cache) %>
<% cache @board, skip_digest: true do %>...<% end %>

<%# Conditional caching %>
<% cache_if @enable_caching, board do %>...<% end %>
<% cache_unless Current.user.admin?, @board do %>...<% end %>

<%# Multi-key with locale and user context %>
<% cache ["dashboard", Current.account, Current.user,
          @boards.maximum(:updated_at), I18n.locale] do %>
  <%= render "boards_summary", boards: @boards %>
<% end %>
```

## Turbo Frame Caching

Cache content inside Turbo Frames:

```erb
<%= turbo_frame_tag "board_header" do %>
  <% cache [@board, "header"] do %>
    <h1><%= @board.name %></h1>
  <% end %>
<% end %>

<%= turbo_frame_tag "board_cards" do %>
  <% cache [@board, "cards"] do %>
    <% cache_collection @board.cards, partial: "cards/card" %>
  <% end %>
<% end %>

<%# Don't cache real-time activity %>
<%= turbo_frame_tag "board_activity" do %>
  <%= render @board.activities.recent %>
<% end %>
```

Lazy-loaded cached frames:

```erb
<%= turbo_frame_tag "board_statistics",
    src: board_statistics_path(@board) do %>
  <p>Loading statistics...</p>
<% end %>

<%# In the statistics view %>
<%= turbo_frame_tag "board_statistics" do %>
  <% cache [@board, "statistics"], expires_in: 15.minutes do %>
    <%= render "boards/statistics", board: @board %>
  <% end %>
<% end %>
```

## Jbuilder Fragment Caching

Cache fragments inside JSON views:

```ruby
# app/views/boards/show.json.jbuilder
json.cache! @board do
  json.extract! @board, :id, :name, :description
end

# Cache collection
json.boards do
  json.array! @boards, cache: true do |board|
    json.extract! board, :id, :name
  end
end
```
