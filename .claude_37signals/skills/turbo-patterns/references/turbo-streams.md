# Turbo Streams Reference

## All seven stream actions with examples

### 1. append -- Add to end of target

```erb
<%= turbo_stream.append "cards", partial: "cards/card", locals: { card: @card } %>
```

### 2. prepend -- Add to beginning of target

```erb
<%= turbo_stream.prepend "cards", partial: "cards/card", locals: { card: @card } %>
```

### 3. replace -- Replace entire target element

```erb
<%= turbo_stream.replace @card, partial: "cards/card", locals: { card: @card } %>
```

### 4. update -- Replace target's inner content only

```erb
<%= turbo_stream.update @card, partial: "cards/card_content", locals: { card: @card } %>
```

### 5. remove -- Delete target from DOM

```erb
<%= turbo_stream.remove @card %>
```

### 6. before -- Insert before target

```erb
<%= turbo_stream.before @card, partial: "cards/new_card_form" %>
```

### 7. after -- Insert after target

```erb
<%= turbo_stream.after @card, partial: "cards/comment", locals: { comment: @comment } %>
```

### Bonus: morph -- Smart replacement with DOM diffing

```erb
<%= turbo_stream.morph @card, partial: "cards/card", locals: { card: @card } %>
```

## Multiple stream actions in one response

```erb
<%# app/views/cards/comments/create.turbo_stream.erb %>

<%# 1. Prepend new comment %>
<%= turbo_stream.prepend "comments", partial: "cards/comments/comment", locals: { comment: @comment } %>

<%# 2. Clear the form %>
<%= turbo_stream.update dom_id(@card, :new_comment), partial: "cards/comments/form", locals: { card: @card } %>

<%# 3. Update count %>
<%= turbo_stream.update dom_id(@card, :comment_count) do %>
  <%= pluralize(@card.comments.count, "comment") %>
<% end %>

<%# 4. Show flash %>
<%= turbo_stream.prepend "flash" do %>
  <div class="flash flash--notice">Comment added</div>
<% end %>
```

## Conditional stream rendering

```erb
<%# app/views/cards/update.turbo_stream.erb %>

<%# Always update the card %>
<%= turbo_stream.replace @card, partial: "cards/card", locals: { card: @card } %>

<%# Only update sidebar if status changed %>
<% if @card.saved_change_to_status? %>
  <%= turbo_stream.update "sidebar_stats" do %>
    <%= render "boards/stats", board: @card.board %>
  <% end %>
<% end %>
```

## Targeting multiple elements

```erb
<%# Update all cards in a column %>
<%= turbo_stream.update dom_id(@column, :cards) do %>
  <%= render @column.cards.positioned %>
<% end %>

<%# Update multiple individual cards %>
<% @cards.each do |card| %>
  <%= turbo_stream.replace card, partial: "cards/card", locals: { card: card } %>
<% end %>
```

## Inline rendering with block

```erb
<%# Render content inline instead of from partial %>
<%= turbo_stream.update "card_count" do %>
  <%= @board.cards.count %>
<% end %>

<%# Remove with animation %>
<%= turbo_stream.replace @item do %>
  <div class="fade-out" data-controller="auto-remove" data-auto-remove-delay-value="300">
    <%= render "items/item", item: @item %>
  </div>
<% end %>
```

## Controller rendering arrays

```ruby
def create
  @comment = @card.comments.create!(comment_params)

  respond_to do |format|
    format.turbo_stream do
      render turbo_stream: [
        turbo_stream.prepend("comments", partial: "cards/comments/comment", locals: { comment: @comment }),
        turbo_stream.update("comment_count") { @card.comments.count.to_s }
      ]
    end
    format.html { redirect_to @card, notice: "Comment added" }
  end
end
```

## Common patterns catalog

```erb
<%# 1. Create and prepend %>
<%= turbo_stream.prepend "items", partial: "items/item", locals: { item: @item } %>

<%# 2. Update and show flash %>
<%= turbo_stream.replace @item, partial: "items/item", locals: { item: @item } %>
<%= turbo_stream.prepend "flash", partial: "shared/flash", locals: { type: :notice, message: "Updated" } %>

<%# 3. Replace card and update counts %>
<%= turbo_stream.replace @card %>
<%= turbo_stream.update "card_count" do %><%= @board.cards.count %><% end %>

<%# 4. Clear form after submit %>
<%= turbo_stream.prepend "comments", partial: "comments/comment" %>
<%= turbo_stream.replace "comment_form", partial: "comments/form", locals: { card: @card, comment: Comment.new } %>

<%# 5. Destroy response %>
<%= turbo_stream.remove @comment %>
<%= turbo_stream.update dom_id(@card, :comment_count) do %>
  <%= pluralize(@card.comments.count, "comment") %>
<% end %>
```

## Turbo Stream view helpers

```ruby
# app/helpers/turbo_helper.rb
module TurboHelper
  def turbo_delete_button(name, path, **options)
    button_to name, path, **options.merge(
      method: :delete,
      form: { data: { turbo_confirm: "Are you sure?" } }
    )
  end

  def turbo_auto_submit_form(**options, &block)
    form_with **options.merge(
      data: {
        controller: "auto-submit",
        action: "change->auto-submit#submit"
      }
    ), &block
  end
end
```
