# Undo/Redo Pattern with Commands

## Overview

The Command Pattern naturally supports undo/redo by maintaining a history stack and backing up state before execution.

## Architecture

```
┌─────────────────────────────────────┐
│         CommandInvoker              │
├─────────────────────────────────────┤
│ history: [cmd1, cmd2, cmd3, cmd4]  │
│ current_position: 2                 │  ← Points to last executed
├─────────────────────────────────────┤
│ execute(command)                    │
│ undo()                              │
│ redo()                              │
└─────────────────────────────────────┘
```

## State Management Strategies

### 1. Direct State Backup (Simple)

Store the entire object state before modification:

```ruby
class EditPostCommand < ApplicationCommand
  def initialize(post:, attributes:)
    @post = post
    @attributes = attributes
    @backup = nil
  end

  def call
    # Backup entire state
    @backup = @post.attributes.dup.freeze

    @post.update!(@attributes)
    Success(@post)
  end

  def undo
    return Failure("No backup") unless @backup

    @post.update!(@backup)
    Success(@post)
  end
end
```

**Pros**: Simple, works for small objects
**Cons**: Memory intensive for large objects

### 2. Memento Pattern (Recommended)

Encapsulate state backup in a separate Memento class:

```ruby
# app/mementos/post_memento.rb
class PostMemento
  def initialize(post)
    @state = {
      title: post.title,
      content: post.content,
      status: post.status,
      published_at: post.published_at
    }.freeze
  end

  def restore(post)
    post.update!(@state)
  end
end

# app/commands/posts/edit_command.rb
class EditPostCommand < ApplicationCommand
  def initialize(post:, attributes:)
    @post = post
    @attributes = attributes
    @memento = nil
  end

  def call
    @memento = PostMemento.new(@post)
    @post.update!(@attributes)
    Success(@post)
  end

  def undo
    return Failure("No memento") unless @memento

    @memento.restore(@post)
    Success(@post)
  end
end
```

**Pros**: Clean separation, selective state backup
**Cons**: Extra class per model type

### 3. Delta/Diff Backup (Memory Efficient)

Store only the changed attributes:

```ruby
class EditPostCommand < ApplicationCommand
  def initialize(post:, attributes:)
    @post = post
    @attributes = attributes
    @original_values = {}
  end

  def call
    # Backup only changed attributes
    @attributes.each_key do |key|
      @original_values[key] = @post.public_send(key)
    end

    @post.update!(@attributes)
    Success(@post)
  end

  def undo
    return Failure("No backup") if @original_values.empty?

    @post.update!(@original_values)
    Success(@post)
  end
end
```

**Pros**: Memory efficient
**Cons**: Only works for simple attribute changes

### 4. Inverse Command (Calculation-based)

Calculate the inverse operation instead of storing state:

```ruby
# app/commands/counters/increment_command.rb
class IncrementCommand < ApplicationCommand
  def initialize(counter:, amount:)
    @counter = counter
    @amount = amount
  end

  def call
    @counter.increment!(:value, @amount)
    Success(@counter)
  end

  def undo
    # Inverse operation: subtract instead of add
    @counter.decrement!(:value, @amount)
    Success(@counter)
  end
end
```

**Pros**: No state storage needed
**Cons**: Only works for mathematically reversible operations

## Command Invoker Implementation

### Basic Invoker

```ruby
# app/commands/command_invoker.rb
class CommandInvoker
  include Dry::Monads[:result]

  def initialize
    @history = []
    @current_position = -1
  end

  def execute(command)
    result = command.call

    if result.success?
      # Clear any redo history when new command executes
      @history = @history[0..@current_position]
      @history << command
      @current_position += 1
    end

    result
  end

  def undo
    return Failure("Nothing to undo") unless can_undo?

    command = @history[@current_position]
    result = command.undo

    if result.success?
      @current_position -= 1
    end

    result
  end

  def redo
    return Failure("Nothing to redo") unless can_redo?

    @current_position += 1
    command = @history[@current_position]

    result = command.call

    if result.failure?
      @current_position -= 1
    end

    result
  end

  def can_undo?
    @current_position >= 0
  end

  def can_redo?
    @current_position < @history.size - 1
  end

  def history_size
    @history.size
  end

  def clear_history
    @history.clear
    @current_position = -1
  end
end
```

### Persistent Invoker (Database-backed)

Store command history in database for long-term persistence:

```ruby
# app/models/command_history.rb
class CommandHistory < ApplicationRecord
  belongs_to :user
  serialize :command_data, JSON

  scope :executable, -> { where(executed: true).order(position: :asc) }
end

# app/commands/persistent_invoker.rb
class PersistentInvoker
  include Dry::Monads[:result]

  def initialize(user:)
    @user = user
  end

  def execute(command)
    result = command.call

    if result.success?
      # Clear redo history
      CommandHistory.where(user: @user, executed: false).destroy_all

      # Store command
      CommandHistory.create!(
        user: @user,
        command_type: command.class.name,
        command_data: command.to_h,
        executed: true,
        position: next_position
      )
    end

    result
  end

  def undo
    last_command = CommandHistory.executable
                                  .where(user: @user)
                                  .last

    return Failure("Nothing to undo") unless last_command

    command = reconstruct_command(last_command)
    result = command.undo

    if result.success?
      last_command.update!(executed: false)
    end

    result
  end

  def redo
    next_command = CommandHistory.where(user: @user, executed: false)
                                  .order(position: :asc)
                                  .first

    return Failure("Nothing to redo") unless next_command

    command = reconstruct_command(next_command)
    result = command.call

    if result.success?
      next_command.update!(executed: true)
    end

    result
  end

  private

  def next_position
    CommandHistory.where(user: @user).maximum(:position).to_i + 1
  end

  def reconstruct_command(history_record)
    command_class = history_record.command_type.constantize
    command_class.from_h(history_record.command_data)
  end
end

# Commands must implement serialization
module Serializable
  def to_h
    {
      post_id: @post.id,
      attributes: @attributes
    }
  end

  def self.from_h(data)
    post = Post.find(data['post_id'])
    new(post: post, attributes: data['attributes'])
  end
end

class EditPostCommand < ApplicationCommand
  include Serializable
  # ...
end
```

## UI Integration

### Controller with Undo/Redo

```ruby
class PostsController < ApplicationController
  def edit
    @post = Post.find(params[:id])
  end

  def update
    @post = Post.find(params[:id])

    command = Posts::EditCommand.new(
      post: @post,
      attributes: post_params
    )

    result = invoker.execute(command)

    if result.success?
      redirect_to @post, notice: "Post updated. #{undo_link}"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def undo
    result = invoker.undo

    if result.success?
      redirect_to posts_path, notice: "Last action undone. #{redo_link}"
    else
      redirect_to posts_path, alert: result.failure
    end
  end

  def redo
    result = invoker.redo

    if result.success?
      redirect_to posts_path, notice: "Action redone. #{undo_link}"
    else
      redirect_to posts_path, alert: result.failure
    end
  end

  private

  def invoker
    @invoker ||= CommandInvoker.new
    session[:command_invoker_state] = Marshal.dump(@invoker)
    @invoker
  end

  def undo_link
    return unless invoker.can_undo?
    helpers.link_to("Undo", undo_posts_path, method: :post)
  end

  def redo_link
    return unless invoker.can_redo?
    helpers.link_to("Redo", redo_posts_path, method: :post)
  end

  def post_params
    params.require(:post).permit(:title, :content, :status)
  end
end
```

### Routes

```ruby
resources :posts do
  collection do
    post :undo
    post :redo
  end
end
```

### View with Hotwire

```erb
<!-- app/views/posts/edit.html.erb -->
<div class="toolbar">
  <%= turbo_frame_tag "undo_redo" do %>
    <%= button_to "Undo",
                  undo_posts_path,
                  method: :post,
                  disabled: !@invoker&.can_undo?,
                  data: { turbo_frame: "_top" },
                  class: "btn btn-secondary" %>

    <%= button_to "Redo",
                  redo_posts_path,
                  method: :post,
                  disabled: !@invoker&.can_redo?,
                  data: { turbo_frame: "_top" },
                  class: "btn btn-secondary" %>
  <% end %>
</div>

<%= form_with model: @post, data: { turbo_frame: "_top" } do |f| %>
  <%= f.text_field :title %>
  <%= f.text_area :content %>
  <%= f.submit "Save" %>
<% end %>
```

## History Limits

Prevent memory issues by limiting history size:

```ruby
class CommandInvoker
  MAX_HISTORY = 50

  def execute(command)
    result = command.call

    if result.success?
      @history = @history[0..@current_position]
      @history << command
      @current_position += 1

      # Limit history size
      if @history.size > MAX_HISTORY
        @history.shift
        @current_position -= 1
      end
    end

    result
  end
end
```

## Testing Undo/Redo

```ruby
RSpec.describe CommandInvoker do
  let(:invoker) { described_class.new }
  let(:post) { create(:post, title: "Original") }

  describe "undo/redo cycle" do
    it "restores state through multiple operations" do
      # Execute commands
      cmd1 = Posts::EditCommand.new(post: post, attributes: { title: "V1" })
      cmd2 = Posts::EditCommand.new(post: post, attributes: { title: "V2" })
      cmd3 = Posts::EditCommand.new(post: post, attributes: { title: "V3" })

      invoker.execute(cmd1)
      invoker.execute(cmd2)
      invoker.execute(cmd3)

      expect(post.reload.title).to eq("V3")

      # Undo twice
      invoker.undo
      expect(post.reload.title).to eq("V2")

      invoker.undo
      expect(post.reload.title).to eq("V1")

      # Redo once
      invoker.redo
      expect(post.reload.title).to eq("V2")

      # New command clears redo history
      cmd4 = Posts::EditCommand.new(post: post, attributes: { title: "V4" })
      invoker.execute(cmd4)

      expect(invoker.can_redo?).to be false
      expect(post.reload.title).to eq("V4")
    end
  end

  describe "history limits" do
    it "maintains maximum history size" do
      51.times do |i|
        cmd = Posts::EditCommand.new(post: post, attributes: { title: "V#{i}" })
        invoker.execute(cmd)
      end

      expect(invoker.history_size).to eq(50)
      expect(invoker.can_undo?).to be true
    end
  end
end
```

## Best Practices

✅ **Do:**
- Backup state before execution
- Clear redo history when new command executes
- Set reasonable history limits
- Use Memento for complex state
- Test undo → redo → undo cycles

❌ **Don't:**
- Store unlimited history (memory leak)
- Forget to backup state
- Allow undo of irreversible operations (payments, emails)
- Undo without proper authorization checks

## Common Pitfalls

### 1. Forgetting to Clear Redo History

```ruby
# ❌ Wrong: Redo history not cleared
def execute(command)
  result = command.call
  @history << command if result.success?
  result
end

# ✅ Correct: Clear redo history
def execute(command)
  result = command.call
  if result.success?
    @history = @history[0..@current_position]  # Clear redo
    @history << command
    @current_position += 1
  end
  result
end
```

### 2. Not Handling Side Effects

```ruby
# ❌ Wrong: Side effects can't be undone
class PublishCommand < ApplicationCommand
  def call
    @post.update!(published: true)
    SendNewsletterJob.perform_later(@post)  # Can't undo this!
    Success(@post)
  end
end

# ✅ Correct: Track side effects for compensation
class PublishCommand < ApplicationCommand
  def call
    @post.update!(published: true)
    @newsletter_job_id = SendNewsletterJob.perform_later(@post).job_id
    Success(@post)
  end

  def undo
    @post.update!(published: false)
    # Cancel job if still pending
    Solid::Queue::Job.find(@newsletter_job_id).cancel if @newsletter_job_id
    Success(@post)
  end
end
```

### 3. Mutable State Backup

```ruby
# ❌ Wrong: Mutable backup can be modified
def call
  @backup = @post.attributes.dup  # Not frozen!
  @post.update!(@attributes)
end

# ✅ Correct: Freeze backup
def call
  @backup = @post.attributes.dup.freeze
  @post.update!(@attributes)
end
```

## Resources

- [Memento Pattern](https://refactoring.guru/design-patterns/memento)
- [Command Pattern](https://refactoring.guru/design-patterns/command)
