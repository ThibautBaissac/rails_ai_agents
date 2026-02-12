# Command Pattern in Rails

## Overview

The Command Pattern encapsulates requests as independent objects, enabling parametrization of operations, delayed execution, queuing, and reversible operations (undo/redo).

**Key Insight**: A Command doesn't perform work itself—it delegates to a Receiver (business logic object).

## Core Components

```
Client → Command → Receiver
           ↓
        Invoker
```

1. **Command (Interface)** - Declares `execute()` method
2. **Concrete Command** - Implements specific operation, delegates to Receiver
3. **Receiver** - Contains actual business logic
4. **Invoker** - Stores and executes commands without knowing details
5. **Client** - Creates and configures commands with receivers

## When to Use Command Pattern

✅ **Use Command Pattern when you need:**

- **Undo/Redo functionality** - History stack of reversible operations
- **Queuing operations** - Delayed execution, background jobs
- **Logging/Auditing** - Record all operations for replay or audit trail
- **Transactional operations** - Group commands and rollback if needed
- **Macro commands** - Composite operations from simple commands
- **Parametrizing UI elements** - Buttons/menus execute different commands

❌ **Don't use Command Pattern for:**

- Simple CRUD operations (use Service Objects instead)
- Operations that don't need undo/redo
- One-time operations without history tracking
- Simple controller actions

## Difference from Service Objects

| Aspect | Service Object | Command Pattern |
|--------|---------------|-----------------|
| Purpose | Encapsulate business logic | Encapsulate request as object |
| Undo/Redo | No | Yes (with Memento) |
| Queuing | Limited | Native support |
| History | No | Command history stack |
| Delegation | Direct execution | Delegates to Receiver |
| Complexity | Low | Higher (more components) |

## Rails Implementation

### 1. Basic Command Structure

```ruby
# app/commands/application_command.rb
class ApplicationCommand
  include Dry::Monads[:result]

  def self.call(*args, **kwargs)
    new(*args, **kwargs).call
  end

  def call
    raise NotImplementedError, "Subclasses must implement #call"
  end

  def undo
    raise NotImplementedError, "Subclasses must implement #undo for reversible commands"
  end
end
```

### 2. Concrete Command with Receiver

```ruby
# app/commands/posts/publish_command.rb
module Posts
  class PublishCommand < ApplicationCommand
    attr_reader :post, :publisher

    def initialize(post:, publisher: Posts::Publisher.new)
      @post = post
      @publisher = publisher
      @previous_state = nil
    end

    def call
      return Failure("Post already published") if post.published?

      # Backup state for undo
      @previous_state = post.dup.freeze

      # Delegate to Receiver
      result = publisher.publish(post)

      return Failure(result.error) if result.failure?

      Success(post)
    end

    def undo
      return Failure("No state to restore") unless @previous_state

      post.update!(
        status: @previous_state.status,
        published_at: @previous_state.published_at
      )

      Success(post)
    end
  end
end

# app/services/posts/publisher.rb (Receiver)
module Posts
  class Publisher
    include Dry::Monads[:result]

    def publish(post)
      ActiveRecord::Base.transaction do
        post.update!(
          status: :published,
          published_at: Time.current
        )

        # Side effects
        NotificationService.notify_subscribers(post)
        SearchIndexer.index(post)
      end

      Success(post)
    rescue StandardError => e
      Failure(e.message)
    end
  end
end
```

### 3. Command Invoker (History)

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
      # Remove any commands after current position (for redo)
      @history = @history[0..@current_position]
      @history << command
      @current_position += 1
    end

    result
  end

  def undo
    return Failure("Nothing to undo") if @current_position < 0

    command = @history[@current_position]
    result = command.undo

    @current_position -= 1 if result.success?

    result
  end

  def redo
    return Failure("Nothing to redo") if @current_position >= @history.size - 1

    @current_position += 1
    command = @history[@current_position]
    command.call
  end

  def can_undo?
    @current_position >= 0
  end

  def can_redo?
    @current_position < @history.size - 1
  end

  def clear_history
    @history.clear
    @current_position = -1
  end
end
```

### 4. Controller Usage

```ruby
class PostsController < ApplicationController
  def publish
    @post = Post.find(params[:id])
    authorize @post

    command = Posts::PublishCommand.new(post: @post)
    result = invoker.execute(command)

    if result.success?
      redirect_to @post, notice: "Post published"
    else
      redirect_to @post, alert: result.failure
    end
  end

  def undo
    result = invoker.undo

    if result.success?
      redirect_to posts_path, notice: "Last action undone"
    else
      redirect_to posts_path, alert: result.failure
    end
  end

  def redo
    result = invoker.redo

    if result.success?
      redirect_to posts_path, notice: "Action redone"
    else
      redirect_to posts_path, alert: result.failure
    end
  end

  private

  def invoker
    @invoker ||= session[:command_invoker] ||= CommandInvoker.new
  end
end
```

## Advanced Patterns

### Composite Commands (Macro)

Execute multiple commands as one:

```ruby
# app/commands/composite_command.rb
class CompositeCommand < ApplicationCommand
  def initialize
    @commands = []
  end

  def add(command)
    @commands << command
  end

  def call
    results = []

    @commands.each do |command|
      result = command.call
      return result if result.failure?
      results << result.value!
    end

    Success(results)
  end

  def undo
    # Undo in reverse order
    @commands.reverse.each do |command|
      result = command.undo
      return result if result.failure?
    end

    Success(true)
  end
end

# Usage
macro = CompositeCommand.new
macro.add(Posts::PublishCommand.new(post: post1))
macro.add(Posts::PublishCommand.new(post: post2))
macro.add(Emails::SendNewsletterCommand.new(posts: [post1, post2]))

result = invoker.execute(macro)
```

### Queued Commands (Background Jobs)

```ruby
# app/commands/posts/schedule_publish_command.rb
module Posts
  class SchedulePublishCommand < ApplicationCommand
    def initialize(post:, publish_at:)
      @post = post
      @publish_at = publish_at
    end

    def call
      PublishPostJob.set(wait_until: @publish_at).perform_later(@post.id)
      Success(@post)
    end
  end
end

# app/jobs/publish_post_job.rb
class PublishPostJob < ApplicationJob
  queue_as :default

  def perform(post_id)
    post = Post.find(post_id)
    command = Posts::PublishCommand.new(post: post)
    command.call
  end
end
```

### Command with Memento (State Backup)

```ruby
# app/commands/posts/edit_command.rb
module Posts
  class EditCommand < ApplicationCommand
    def initialize(post:, attributes:)
      @post = post
      @attributes = attributes
      @memento = nil
    end

    def call
      # Save state with Memento
      @memento = PostMemento.new(@post)

      @post.update!(@attributes)
      Success(@post)
    rescue ActiveRecord::RecordInvalid => e
      Failure(e.message)
    end

    def undo
      return Failure("No saved state") unless @memento

      @memento.restore(@post)
      Success(@post)
    end
  end
end

# app/mementos/post_memento.rb
class PostMemento
  def initialize(post)
    @state = post.attributes.dup.freeze
  end

  def restore(post)
    post.update!(@state)
  end
end
```

### Logging/Audit Trail

```ruby
# app/commands/auditable_command.rb
class AuditableCommand < ApplicationCommand
  def call
    result = super

    if result.success?
      log_execution(result.value!)
    else
      log_failure(result.failure)
    end

    result
  end

  private

  def log_execution(data)
    CommandLog.create!(
      command_type: self.class.name,
      status: :success,
      data: data.as_json,
      executed_at: Time.current
    )
  end

  def log_failure(error)
    CommandLog.create!(
      command_type: self.class.name,
      status: :failure,
      error_message: error,
      executed_at: Time.current
    )
  end
end

# app/commands/posts/publish_command.rb
module Posts
  class PublishCommand < AuditableCommand
    # ... implementation
  end
end
```

## Testing Commands

```ruby
# spec/commands/posts/publish_command_spec.rb
RSpec.describe Posts::PublishCommand do
  let(:post) { create(:post, :draft) }
  let(:publisher) { instance_double(Posts::Publisher) }
  let(:command) { described_class.new(post: post, publisher: publisher) }

  describe "#call" do
    context "when post is draft" do
      before do
        allow(publisher).to receive(:publish).and_return(Success(post))
      end

      it "publishes the post" do
        result = command.call

        expect(result).to be_success
        expect(publisher).to have_received(:publish).with(post)
      end

      it "backs up state for undo" do
        command.call
        post.update!(status: :archived)

        result = command.undo

        expect(result).to be_success
        expect(post.reload.status).to eq("draft")
      end
    end

    context "when post is already published" do
      let(:post) { create(:post, :published) }

      it "returns failure" do
        result = command.call

        expect(result).to be_failure
        expect(result.failure).to eq("Post already published")
      end
    end
  end

  describe "#undo" do
    context "when command was executed" do
      before do
        allow(publisher).to receive(:publish).and_return(Success(post))
        command.call
      end

      it "restores previous state" do
        original_status = post.status

        result = command.undo

        expect(result).to be_success
        expect(post.reload.status).to eq(original_status)
      end
    end

    context "when command was not executed" do
      it "returns failure" do
        result = command.undo

        expect(result).to be_failure
        expect(result.failure).to eq("No state to restore")
      end
    end
  end
end
```

## Command Pattern vs Service Object Decision Tree

```
Need undo/redo functionality?
├─ YES → Command Pattern
└─ NO
   ├─ Need command history/audit trail?
   │  ├─ YES → Command Pattern
   │  └─ NO
   │     ├─ Need to queue/schedule operations?
   │     │  ├─ YES → Command Pattern
   │     │  └─ NO → Service Object
   └─ Simple business logic?
      └─ YES → Service Object
```

## Real-World Use Cases

### 1. Content Management System

```ruby
# Undo/Redo for rich text editor
invoker.execute(Posts::EditCommand.new(post: post, attributes: { title: "New Title" }))
invoker.execute(Posts::PublishCommand.new(post: post))
invoker.undo  # Unpublish
invoker.undo  # Revert title change
invoker.redo  # Restore title
invoker.redo  # Republish
```

### 2. Project Management Tool

```ruby
# Macro command for project setup
setup = CompositeCommand.new
setup.add(Projects::CreateCommand.new(attributes: project_attrs))
setup.add(Teams::AssignCommand.new(team: team))
setup.add(Tasks::CreateBulkCommand.new(tasks: task_list))

invoker.execute(setup)

# If something goes wrong, undo entire setup
invoker.undo if setup_failed?
```

### 3. E-commerce Order Processing

```ruby
# Transactional command with rollback
order_command = Orders::ProcessCommand.new(order: order)
payment_command = Payments::ChargeCommand.new(order: order)
inventory_command = Inventory::ReserveCommand.new(order: order)

transaction = CompositeCommand.new
transaction.add(inventory_command)
transaction.add(payment_command)
transaction.add(order_command)

result = invoker.execute(transaction)

# Automatic rollback on failure
invoker.undo if result.failure?
```

## Benefits

✅ **Decoupling** - Invokers don't know command details
✅ **Open/Closed** - Add new commands without changing invokers
✅ **Undo/Redo** - Natural support for reversible operations
✅ **Queuing** - Commands are objects, easily serialized
✅ **Composability** - Build complex operations from simple ones
✅ **Audit Trail** - Every command is logged

## Drawbacks

⚠️ **Complexity** - More classes and abstractions
⚠️ **Overhead** - Overkill for simple operations
⚠️ **Memory** - Command history can grow large

## Checklist

- [ ] Command implements `execute()` method
- [ ] Command delegates to Receiver (doesn't do work itself)
- [ ] Reversible commands implement `undo()` method
- [ ] Invoker maintains command history
- [ ] State backed up before execution (for undo)
- [ ] Commands return Result monad
- [ ] Tests cover execute and undo paths
- [ ] Consider memory limits for history

## Related Patterns

- **Memento** - Backup state for undo
- **Chain of Responsibility** - Commands can chain
- **Composite** - Macro commands
- **Strategy** - Different algorithm, same interface (but different intent)

## Resources

- [Refactoring Guru: Command Pattern](https://refactoring.guru/es/design-patterns/command)
- [Gang of Four: Design Patterns](https://en.wikipedia.org/wiki/Design_Patterns)
