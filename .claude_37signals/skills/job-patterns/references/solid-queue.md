# Solid Queue Configuration

Database-backed job queue for Rails. No Redis required.

## Why Solid Queue over Sidekiq

- Database-backed (no Redis dependency)
- Transactions work across jobs/data
- Simpler infrastructure (one less service)
- Built-in recurring jobs
- First-class Rails integration

## Database setup

```yaml
# config/database.yml
production:
  primary:
    <<: *default
    database: myapp_production

  queue:
    <<: *default
    database: myapp_queue
    migrations_paths: db/queue_migrate
```

## Worker configuration

```yaml
# config/solid_queue.yml
production:
  dispatchers:
    - polling_interval: 1
      batch_size: 500

  workers:
    - queues: "default,low_priority"
      threads: 3
      polling_interval: 1

    - queues: "webhooks"
      threads: 2
      polling_interval: 0.1
```

## Queue priorities

```ruby
# High priority -- user-facing
class NotifyRecipientsJob < ApplicationJob
  queue_as :default
end

# Low priority -- background cleanup
class SessionCleanupJob < ApplicationJob
  queue_as :low_priority
end

# Dedicated queue -- external API calls
class DispatchWebhookJob < ApplicationJob
  queue_as :webhooks
end
```

## Queue configuration in production

```ruby
# config/environments/production.rb
config.solid_queue.queues = [
  { name: "default", processes: 3, polling_interval: 1 },
  { name: "low_priority", processes: 1, polling_interval: 5 },
  { name: "webhooks", processes: 2, polling_interval: 1 }
]
```

## Process management

```bash
# Start Solid Queue
bundle exec rake solid_queue:start

# Or via Procfile
web: bundle exec puma -C config/puma.rb
worker: bundle exec rake solid_queue:start
```

## Monitoring jobs

```ruby
# In console or dashboard
SolidQueue::Job.where(finished_at: nil).count           # Pending
SolidQueue::Job.where.not(finished_at: nil).count       # Completed
SolidQueue::Job.where.not(failed_at: nil).count         # Failed

# By queue
SolidQueue::Job.where(queue_name: "default", finished_at: nil).count

# By job class
SolidQueue::Job.where(job_class: "NotifyRecipientsJob").count
```

## Performance metrics

```ruby
class ApplicationJob < ActiveJob::Base
  around_perform do |job, block|
    start = Time.current
    block.call
    duration = Time.current - start

    Rails.logger.info "[Job] #{job.class.name} completed in #{duration}s"

    ActiveSupport::Notifications.instrument(
      "job.duration",
      job_class: job.class.name,
      duration: duration
    )
  end
end
```

## Job argument serialization

```ruby
# ActiveRecord models (automatically uses GlobalID)
NotifyRecipientsJob.perform_later(@comment)

# Basic types
SendEmailJob.perform_later("user@example.com", "Subject")

# Complex arguments (use Hash)
TrackEventJob.perform_later(
  @card,
  "card_closed",
  { user: @user, particulars: { reason: "Completed" } }
)
```

## Job lifecycle callbacks

```ruby
class ComplexJob < ApplicationJob
  before_perform :set_current_context
  after_perform :cleanup_context
  around_perform :log_performance

  def perform(record)
    record.process_now
  end

  private

  def set_current_context
    Current.user = arguments.first.creator
  end

  def cleanup_context
    Current.reset
  end

  def log_performance
    start_time = Time.current
    yield
    duration = Time.current - start_time
    Rails.logger.info "Job completed in #{duration}s"
  end
end
```
