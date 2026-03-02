# Job Usage in Application

## From a Controller

```ruby
# app/controllers/entities_controller.rb
class EntitiesController < ApplicationController
  def create
    @entity = current_user.entities.build(entity_params)

    if @entity.save
      # Immediate job
      CalculateMetricsJob.perform_later(@entity.id)

      # Delayed job (5 minutes)
      SendWelcomeJob.set(wait: 5.minutes).perform_later(@entity.owner_id)

      redirect_to @entity
    else
      render :new
    end
  end
end
```

## From a Service

```ruby
# app/services/submissions/create_service.rb
module Submissions
  class CreateService < ApplicationService
    def call
      if submission.save
        # Enqueue metrics calculation
        CalculateMetricsJob.perform_later(submission.entity_id)

        # Notify the owner
        SendNotificationJob.perform_later(
          submission.entity.owner_id,
          "new_submission",
          { submission_id: submission.id }
        )

        success(submission)
      else
        failure(submission.errors)
      end
    end
  end
end
```

## Dynamically Scheduled Jobs

```ruby
# Enqueue a job for tomorrow at noon
ExportDataJob.set(wait_until: Date.tomorrow.noon).perform_later(user.id, "entities")

# Enqueue with priority
UrgentNotificationJob.set(priority: 10).perform_later(user.id)
```

## Queue Configuration

```yaml
# config/queue.yml
production:
  dispatchers:
    - polling_interval: 1
      batch_size: 500
  workers:
    - queues: default
      threads: 3
      processes: 2
      polling_interval: 0.1
    - queues: mailers,notifications
      threads: 5
      processes: 1
      polling_interval: 0.1
    - queues: imports,exports
      threads: 2
      processes: 1
      polling_interval: 1
    - queues: maintenance
      threads: 1
      processes: 1
      polling_interval: 5

development:
  workers:
    - queues: "*"
      threads: 3
      processes: 1
      polling_interval: 1
```

## Recurring Jobs Configuration

```yaml
# config/recurring.yml
production:
  # Every day at 8am
  send_daily_digest:
    class: SendDailyDigestJob
    schedule: "0 8 * * *"
    queue: mailers

  # Every Monday at 9am
  send_weekly_digest:
    class: SendWeeklyDigestJob
    schedule: "0 9 * * 1"
    queue: mailers

  # Every day at 2am
  cleanup_old_data:
    class: CleanupOldDataJob
    schedule: "0 2 * * *"
    queue: maintenance

  # Every hour
  calculate_all_metrics:
    class: CalculateAllMetricsJob
    schedule: "0 * * * *"
    queue: default

  # Every 15 minutes
  process_pending_notifications:
    class: ProcessPendingNotificationsJob
    schedule: "*/15 * * * *"
    queue: notifications
```
