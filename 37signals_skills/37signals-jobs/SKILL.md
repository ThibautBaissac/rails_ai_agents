---
name: 37signals-jobs
description: Implement shallow background jobs with _later/_now conventions using Solid Queue. Triggers on background jobs, async, perform_later, queue, Solid Queue, recurring jobs.
allowed-tools: Read, Write, Edit, Bash
---

# 37signals Jobs Skill

## Overview

Create thin background jobs that orchestrate model methods. Jobs call models; models do the work. Uses Solid Queue (database-backed, no Redis).

## Core Philosophy

- **Jobs orchestrate, models work**: Business logic stays in models
- **_later/_now convention**: Async/sync pairs for flexibility
- **Solid Queue**: Database-backed, no Redis required
- **Thin jobs**: Just call model methods

## Key Patterns

### Pattern 1: Notification Job

```ruby
# app/jobs/notify_recipients_job.rb
class NotifyRecipientsJob < ApplicationJob
  queue_as :default

  def perform(notifiable)
    notifiable.notify_recipients_now
  end
end

# app/models/concerns/notifiable.rb
module Notifiable
  def notify_recipients_later
    NotifyRecipientsJob.perform_later(self)
  end

  def notify_recipients_now
    recipients.each do |recipient|
      next if recipient == creator
      Notification.create!(recipient: recipient, notifiable: self)
    end
  end
end

# Usage in model
class Comment < ApplicationRecord
  include Notifiable
  after_create_commit :notify_recipients_later
end
```

### Pattern 2: Cleanup Job

```ruby
class SessionCleanupJob < ApplicationJob
  queue_as :low_priority

  def perform
    Session.cleanup_old_sessions_now
  end
end

# In model
class Session < ApplicationRecord
  def self.cleanup_old_sessions_later
    SessionCleanupJob.perform_later
  end

  def self.cleanup_old_sessions_now
    where("created_at < ?", 30.days.ago).delete_all
  end
end
```

### Pattern 3: External API Job

```ruby
class DispatchWebhookJob < ApplicationJob
  queue_as :webhooks
  retry_on StandardError, wait: :exponentially_longer, attempts: 5

  def perform(webhook, event)
    webhook.dispatch_now(event)
  end
end

# In model
class Webhook < ApplicationRecord
  def dispatch_later(event)
    DispatchWebhookJob.perform_later(self, event)
  end

  def dispatch_now(event)
    response = HTTP.post(url, json: event.to_webhook_payload)
    raise "Delivery failed" unless response.status.success?
  end
end
```

### Pattern 4: Broadcast Job

```ruby
class BroadcastUpdateJob < ApplicationJob
  queue_as :default

  def perform(broadcastable)
    broadcastable.broadcast_update_now
  end
end

# In model
module Broadcastable
  extend ActiveSupport::Concern

  included do
    after_update_commit :broadcast_update_later
  end

  def broadcast_update_later
    BroadcastUpdateJob.perform_later(self)
  end

  def broadcast_update_now
    broadcast_replace_to board, target: self
  end
end
```

## Recurring Jobs (Solid Queue)

```yaml
# config/recurring.yml
production:
  deliver_bundled_notifications:
    command: "Notification::Bundle.deliver_all_later"
    schedule: every 30 minutes

  cleanup_old_sessions:
    command: "Session.cleanup_old_sessions_later"
    schedule: every day at 3am

  weekly_digest:
    command: "Digest.send_weekly_later"
    schedule: every sunday at 9am
```

## Queue Configuration

```ruby
# Different queues for different priorities
class NotifyRecipientsJob < ApplicationJob
  queue_as :default  # User-facing, fast
end

class SessionCleanupJob < ApplicationJob
  queue_as :low_priority  # Background, can wait
end

class DispatchWebhookJob < ApplicationJob
  queue_as :webhooks  # External API calls
end
```

## Retry Strategies

```ruby
# Exponential backoff
retry_on StandardError, wait: :exponentially_longer, attempts: 5

# Fixed wait
retry_on NetworkError, wait: 5.minutes, attempts: 3

# Discard on specific errors
discard_on ActiveRecord::RecordNotFound
```

## Current Context in Jobs

```ruby
class TrackEventJob < ApplicationJob
  def perform(eventable, action, user_id:, account_id:)
    Current.user = User.find(user_id)
    Current.account = Account.find(account_id)

    eventable.track_event_now(action)
  ensure
    Current.reset
  end
end

# In model
def track_event_later(action)
  TrackEventJob.perform_later(
    self, action,
    user_id: Current.user.id,
    account_id: Current.account.id
  )
end
```

## Testing Jobs

```ruby
# Test model method directly
test "notify_recipients_now creates notifications" do
  comment = comments(:one)

  assert_difference -> { Notification.count }, 2 do
    comment.notify_recipients_now
  end
end

# Test job is enqueued
test "creating comment enqueues notification job" do
  assert_enqueued_with job: NotifyRecipientsJob do
    card.comments.create!(body: "Test", creator: users(:alice))
  end
end

# Test job calls model method
test "job calls notify_recipients_now" do
  comment = comments(:one)

  assert_difference -> { Notification.count }, 2 do
    NotifyRecipientsJob.perform_now(comment)
  end
end
```

## Commands

```bash
# Start Solid Queue worker
bundle exec rake solid_queue:start

# Check queue status
bin/rails runner "puts SolidQueue::Job.count"

# Clear all jobs
bin/rails runner "SolidQueue::Job.destroy_all"
```

## Boundaries

### Always
- Keep jobs thin (call model methods)
- Use _later/_now naming convention
- Put business logic in models
- Set queue priorities
- Implement retry strategies
- Use Solid Queue (database-backed)

### Never
- Put business logic in jobs
- Use Redis/Sidekiq (use Solid Queue)
- Skip retry strategies for external calls
- Enqueue jobs in transactions
- Forget Current.reset in jobs
