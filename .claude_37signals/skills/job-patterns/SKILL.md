---
name: job-patterns
description: >-
  Implements shallow background jobs with _later/_now conventions using Solid
  Queue. Use when adding background processing, async operations, scheduled
  tasks, or when user mentions jobs, queues, workers, or background processing.
  WHEN NOT: Business logic implementation (use model-patterns), controller
  work (use crud-patterns), or mailer delivery (use mailer-patterns).
license: MIT
compatibility: Ruby 3.3+, Rails 8.0+, Solid Queue
---

# Job Patterns (37signals)

Jobs orchestrate. Models do the work. Background jobs are thin wrappers around model methods.

## Project knowledge

**Tech Stack:** Rails 8.2 (edge), Solid Queue, ActiveJob
**Pattern:** Thin jobs call model methods; models have `_later`/`_now` pairs

**Commands:**
```bash
bin/rails generate job NotifyRecipients        # Generate job
bundle exec rake solid_queue:start             # Run worker
bin/rails runner "puts SolidQueue::Job.count"  # Check queue
bin/rails runner "SolidQueue::Job.destroy_all" # Clear jobs
```

## Why shallow jobs

- Business logic stays in models (testable, reusable)
- Jobs are simple orchestrators
- Easy to run sync or async
- Can call methods directly in tests
- Clearer separation of concerns

## Why _later/_now convention

- Clear which version is async
- Default method can be sync (explicit async)
- Easy to switch between sync/async
- Testable (call `_now` in tests)

## Core pattern: shallow job

The job receives a model and calls its `_now` method. The `_now` suffix is conventional but not required -- some jobs call the plain method name (e.g., `notifiable.notify_recipients`).

```ruby
# app/jobs/notify_recipients_job.rb
class NotifyRecipientsJob < ApplicationJob
  queue_as :default

  def perform(notifiable)
    notifiable.notify_recipients_now
  end
end
```

The model defines both `_later` and `_now` methods:

```ruby
# In model or concern
def notify_recipients_later
  NotifyRecipientsJob.perform_later(self)
end

def notify_recipients_now
  recipients.each do |recipient|
    next if recipient == creator
    Notification.create!(recipient: recipient, notifiable: self, action: notification_action)
  end
end

# Default to sync
def notify_recipients
  notify_recipients_now
end

# Trigger async from callbacks
after_create_commit :notify_recipients_later
```

## Job patterns

### Notification job

```ruby
class NotifyRecipientsJob < ApplicationJob
  queue_as :default

  def perform(notifiable)
    notifiable.notify_recipients_now
  end
end
```

### Batch processing job

```ruby
class DeliverBundledNotificationsJob < ApplicationJob
  queue_as :default

  def perform
    Notification::Bundle.deliver_all_now
  end
end
```

### Cleanup job

```ruby
class SessionCleanupJob < ApplicationJob
  queue_as :low_priority

  def perform
    Session.cleanup_old_sessions_now
  end
end
```

### Event tracking job

```ruby
class TrackEventJob < ApplicationJob
  queue_as :default

  def perform(eventable, action, options = {})
    eventable.track_event_now(action, options)
  end
end
```

### Broadcasting job

```ruby
class BroadcastUpdateJob < ApplicationJob
  queue_as :default

  def perform(broadcastable)
    broadcastable.broadcast_update_now
  end
end
```

### External API job

```ruby
class DispatchWebhookJob < ApplicationJob
  queue_as :webhooks
  retry_on StandardError, wait: :exponentially_longer, attempts: 5

  def perform(webhook, event)
    webhook.dispatch_now(event)
  end
end
```

## Retry and error handling

```ruby
class DispatchWebhookJob < ApplicationJob
  discard_on Webhook::InvalidUrl                              # Don't retry
  retry_on StandardError, wait: :exponentially_longer, attempts: 5  # Backoff
  retry_on CustomError, wait: 5.minutes, attempts: 3          # Fixed interval

  rescue_from Webhook::Timeout do |exception|
    webhook.mark_as_slow!
    raise exception  # Re-raise to trigger retry
  end

  def perform(webhook, event)
    webhook.dispatch_now(event)
  end
end
```

## Current attributes in jobs

Always set and reset `Current` context:

```ruby
class NotifyRecipientsJob < ApplicationJob
  before_perform do |job|
    notifiable = job.arguments.first
    Current.account = notifiable.account
    Current.user = notifiable.creator if notifiable.respond_to?(:creator)
  end

  after_perform { Current.reset }

  def perform(notifiable)
    notifiable.notify_recipients_now
  end
end
```

## Performance patterns

### Batch processing

```ruby
# Enqueue in batches
Card.active.pluck(:id).each_slice(100) do |batch|
  ProcessCardsJob.perform_later(batch)
end

class ProcessCardsJob < ApplicationJob
  def perform(card_ids)
    Card.where(id: card_ids).find_each(&:process_now)
  end
end
```

### Debouncing (avoid duplicate jobs)

```ruby
def reindex_later
  return if reindex_job_queued?
  ReindexBoardJob.perform_later(id)
end

def reindex_job_queued?
  SolidQueue::Job.exists?(
    job_class: "ReindexBoardJob",
    arguments: [id].to_json,
    finished_at: nil
  )
end
```

## Testing jobs

### Test model methods directly (preferred)

```ruby
class CommentTest < ActiveSupport::TestCase
  test "notify_recipients_now creates notifications" do
    comment = comments(:logo_comment)
    assert_difference -> { Notification.count }, 2 do
      comment.notify_recipients_now
    end
  end
end
```

### Verify job is enqueued

```ruby
class NotifyRecipientsJobTest < ActiveJob::TestCase
  test "enqueues job" do
    comment = comments(:logo_comment)
    assert_enqueued_with job: NotifyRecipientsJob, args: [comment] do
      NotifyRecipientsJob.perform_later(comment)
    end
  end
end
```

### Verify callbacks enqueue jobs

```ruby
test "creating comment enqueues notification job" do
  card = cards(:logo)
  assert_enqueued_with job: NotifyRecipientsJob do
    card.comments.create!(body: "Great work!", creator: users(:david))
  end
end
```

See `references/solid-queue.md` for Solid Queue configuration and
`references/recurring-jobs.md` for recurring job setup.

## Boundaries

- **Always:** Keep jobs thin (call model methods), follow the `_later`/`_now` naming convention (though the `_now` suffix is not strictly enforced), put business logic in models, set queue priorities, implement retry strategies, test model methods directly
- **Ask first:** Before putting business logic in jobs, before using Redis/Sidekiq, before running jobs synchronously in production
- **Never:** Put business logic in jobs, use Sidekiq/Resque (use Solid Queue), enqueue jobs in transactions (may not commit), forget `Current.reset` in jobs, skip retry strategies for unreliable operations
