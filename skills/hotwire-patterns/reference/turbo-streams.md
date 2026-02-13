# Turbo Streams Reference

## Concept

Turbo Streams deliver page changes as a set of actions to be performed on specific DOM elements. They can append, prepend, replace, update, remove, before, or after.

## Stream Actions

| Action | Purpose | Example |
|--------|---------|---------|
| `append` | Add to end of container | Add new item to list |
| `prepend` | Add to start of container | Add newest item first |
| `replace` | Replace entire element | Update a record |
| `update` | Replace inner HTML only | Update content, keep element |
| `remove` | Delete element | Remove deleted record |
| `before` | Insert before element | Insert above |
| `after` | Insert after element | Insert below |

## Basic Usage

### Controller Response

```ruby
# app/controllers/posts_controller.rb
def create
  @post = Post.new(post_params)

  respond_to do |format|
    if @post.save
      format.turbo_stream  # renders create.turbo_stream.erb
      format.html { redirect_to @post }
    else
      format.turbo_stream { render turbo_stream: turbo_stream.replace("post_form", partial: "form", locals: { post: @post }) }
      format.html { render :new }
    end
  end
end
```

### Turbo Stream Template

```erb
<%# app/views/posts/create.turbo_stream.erb %>

<%# Add new post to list %>
<%= turbo_stream.prepend "posts", @post %>

<%# Clear the form %>
<%= turbo_stream.replace "post_form", partial: "posts/form", locals: { post: Post.new } %>

<%# Update flash message %>
<%= turbo_stream.update "flash", partial: "shared/flash" %>

<%# Update counter %>
<%= turbo_stream.update "posts_count", html: "#{Post.count} posts" %>
```

## Stream Helpers

### Basic Helpers

```erb
<%# Append partial to container %>
<%= turbo_stream.append "posts", partial: "posts/post", locals: { post: @post } %>

<%# Append renderable (auto-finds partial) %>
<%= turbo_stream.append "posts", @post %>

<%# Prepend to container %>
<%= turbo_stream.prepend "posts", @post %>

<%# Replace element entirely %>
<%= turbo_stream.replace dom_id(@post), @post %>

<%# Update inner HTML %>
<%= turbo_stream.update dom_id(@post), @post %>

<%# Remove element %>
<%= turbo_stream.remove dom_id(@post) %>

<%# Insert before element %>
<%= turbo_stream.before dom_id(@other_post), @post %>

<%# Insert after element %>
<%= turbo_stream.after dom_id(@other_post), @post %>
```

### Inline Content

```erb
<%# With HTML string %>
<%= turbo_stream.update "counter", html: "<strong>5</strong> items" %>

<%# With text %>
<%= turbo_stream.update "status", text: "Processing complete" %>

<%# With block %>
<%= turbo_stream.update "notification" do %>
  <div class="alert alert-success">
    Post created successfully!
  </div>
<% end %>
```

## Real-time with ActionCable

### Broadcast from Model

**⚠️ NOTE:** This is the standard Rails/Turbo pattern, but violates 37signals philosophy.

**37signals approach:** Broadcast explicitly from controller, not from model callbacks.

```ruby
# Standard Rails/Turbo pattern (NOT 37signals):
# app/models/post.rb
class Post < ApplicationRecord
  after_create_commit { broadcast_prepend_to "posts" }
  after_update_commit { broadcast_replace_to "posts" }
  after_destroy_commit { broadcast_remove_to "posts" }
end

# 37signals pattern - Helper methods, called from controller:
class Post < ApplicationRecord
  def broadcast_creation
    broadcast_prepend_to "posts"
  end

  def broadcast_update
    broadcast_replace_to "posts"
  end

  def broadcast_removal
    broadcast_remove_to "posts"
  end
end

# Controller explicitly broadcasts:
# class PostsController
#   def create
#     @post = Post.new(post_params)
#     if @post.save
#       @post.broadcast_creation  # ✅ Explicit
#       redirect_to @post
#     end
#   end
# end
```

### Subscribe in View

```erb
<%# Subscribe to stream %>
<%= turbo_stream_from "posts" %>

<%# Container that receives updates %>
<div id="posts">
  <%= render @posts %>
</div>
```

### Broadcast from Controller/Job

```ruby
# Broadcast to all subscribers
Turbo::StreamsChannel.broadcast_prepend_to(
  "posts",
  target: "posts",
  partial: "posts/post",
  locals: { post: @post }
)

# Or use helper
broadcast_prepend_to "posts", target: "posts", partial: "posts/post", locals: { post: @post }
```

## Multiple Streams Response

```erb
<%# app/views/comments/create.turbo_stream.erb %>

<%# Add comment to list %>
<%= turbo_stream.append "comments", @comment %>

<%# Update comment count %>
<%= turbo_stream.update "comment_count" do %>
  <%= pluralize(@post.comments.count, "comment") %>
<% end %>

<%# Clear form %>
<%= turbo_stream.replace "new_comment" do %>
  <%= render "comments/form", comment: Comment.new(post: @post) %>
<% end %>

<%# Show flash %>
<%= turbo_stream.prepend "flashes" do %>
  <div class="flash flash-success">Comment added!</div>
<% end %>
```

## Testing Turbo Streams

```ruby
# spec/requests/posts_spec.rb
RSpec.describe "Posts", type: :request do
  describe "POST /posts" do
    it "returns turbo stream on success" do
      post posts_path,
           params: { post: { title: "Test" } },
           headers: { "Accept" => "text/vnd.turbo-stream.html" }

      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(response.body).to include('turbo-stream action="prepend"')
    end
  end
end
```

## Common Patterns

### Flash Messages

```erb
<%# Layout %>
<div id="flashes">
  <%= render "shared/flash" %>
</div>

<%# In turbo_stream response %>
<%= turbo_stream.update "flashes", partial: "shared/flash" %>
```

### Form Errors

```erb
<%# On validation failure %>
<%= turbo_stream.replace "post_form" do %>
  <%= render "form", post: @post %>
<% end %>
```

### Live Counter

```erb
<%# Initial render %>
<span id="online_count"><%= @online_count %></span>

<%# Broadcast update %>
<%= turbo_stream.update "online_count", html: @new_count.to_s %>
```
