---
name: solid-queue-setup
description: >-
  Configures Solid Queue for background jobs in Rails 8. Use when setting up
  background processing, creating background jobs, configuring job queues,
  or migrating from Sidekiq to Solid Queue.
license: MIT
compatibility: Ruby 3.3+, Rails 8.1+, Solid Queue
metadata:
  author: ThibautBaissac
  version: "1.0"
---

# Solid Queue Setup for Rails 8

## Overview

Solid Queue is Rails 8's default Active Job backend:
- Database-backed (no Redis required)
- Built-in concurrency controls
- Supports priorities and multiple queues
- Mission-critical job processing
- Web UI available via Mission Control

## Quick Start

### Installation

```bash
# Add to Gemfile (included in Rails 8 by default)
bundle add solid_queue

# Install Solid Queue
bin/rails solid_queue:install

# Run migrations
bin/rails db:migrate
```

### Configuration

```yaml
# config/solid_queue.yml
default: &default
  dispatchers:
    - polling_interval: 1
      batch_size: 500
  workers:
    - queues: "*"
      threads: 3
      processes: 1
      polling_interval: 0.1

development:
  <<: *default

production:
  <<: *default
  workers:
    - queues: [critical, default]
      threads: 5
      processes: 2
    - queues: [low]
      threads: 2
      processes: 1
```

### Set as Active Job Adapter

```ruby
# config/application.rb
config.active_job.queue_adapter = :solid_queue

# Or per environment
# config/environments/production.rb
config.active_job.queue_adapter = :solid_queue
```

## Workflow Checklist

```
Solid Queue Setup:
- [ ] Add solid_queue gem
- [ ] Run solid_queue:install
- [ ] Run migrations
- [ ] Configure queues in solid_queue.yml
- [ ] Set queue adapter in config
- [ ] Create first job with spec
- [ ] Test job execution
- [ ] Configure recurring jobs (if needed)
```

## Creating Jobs

### Basic Job

```ruby
# app/jobs/send_welcome_email_job.rb
class SendWelcomeEmailJob < ApplicationJob
  queue_as :default

  def perform(user_id)
    user = User.find(user_id)
    UserMailer.welcome(user).deliver_now
  end
end
```

### Job with Retries

```ruby
# app/jobs/process_payment_job.rb
class ProcessPaymentJob < ApplicationJob
  queue_as :critical

  # Retry on specific errors
  retry_on PaymentGatewayError, wait: :polynomially_longer, attempts: 5

  # Don't retry on these
  discard_on ActiveRecord::RecordNotFound

  # Custom error handling
  rescue_from(StandardError) do |exception|
    ErrorNotifier.notify(exception)
    raise # Re-raise to trigger retry
  end

  def perform(order_id)
    order = Order.find(order_id)
    PaymentService.new.charge(order)
  end
end
```

### Job with Priority

```ruby
class UrgentNotificationJob < ApplicationJob
  queue_as :critical

  # Lower number = higher priority
  # Default is 0
  def priority
    -10
  end

  def perform(notification_id)
    # Process urgent notification
  end
end
```

## Enqueueing Jobs

```ruby
# Enqueue immediately
SendWelcomeEmailJob.perform_later(user.id)

# Enqueue with delay
SendReminderJob.set(wait: 1.hour).perform_later(user.id)

# Enqueue at specific time
SendReportJob.set(wait_until: Date.tomorrow.noon).perform_later

# Enqueue on specific queue
ProcessJob.set(queue: :low).perform_later(data)

# Perform immediately (skips queue - use sparingly)
SendWelcomeEmailJob.perform_now(user.id)
```

## Recurring Jobs

```yaml
# config/recurring.yml
production:
  daily_report:
    class: GenerateDailyReportJob
    schedule: every day at 6am
    queue: low

  cleanup:
    class: CleanupOldRecordsJob
    schedule: every sunday at 2am

  sync:
    class: SyncExternalDataJob
    schedule: every 15 minutes
```

## Testing Jobs

### Job Spec Template

```ruby
# spec/jobs/send_welcome_email_job_spec.rb
require 'rails_helper'

RSpec.describe SendWelcomeEmailJob, type: :job do
  let(:user) { create(:user) }

  describe '#perform' do
    it 'sends welcome email' do
      expect {
        described_class.perform_now(user.id)
      }.to have_enqueued_mail(UserMailer, :welcome)
    end
  end

  describe 'enqueueing' do
    it 'enqueues the job' do
      expect {
        described_class.perform_later(user.id)
      }.to have_enqueued_job(described_class)
        .with(user.id)
        .on_queue('default')
    end
  end

  describe 'retry behavior' do
    it 'retries on PaymentGatewayError' do
      expect(described_class).to have_retry_on(PaymentGatewayError)
    end
  end
end
```

### Test Helpers

```ruby
# spec/rails_helper.rb
RSpec.configure do |config|
  config.include ActiveJob::TestHelper
end

# In specs
it 'processes all jobs' do
  perform_enqueued_jobs do
    UserSignupService.call(user_params)
  end
  expect(user.reload.welcome_email_sent?).to be true
end

it 'enqueues multiple jobs' do
  expect {
    BatchProcessor.process(items)
  }.to have_enqueued_job(ProcessItemJob).exactly(items.count).times
end
```

## Running Solid Queue

```bash
# Development (runs in separate terminal)
bin/rails solid_queue:start

# Production (via Procfile)
# Procfile
web: bin/rails server
worker: bin/rails solid_queue:start
```

## Monitoring

### Mission Control (Web UI)

```ruby
# Gemfile
gem "mission_control-jobs"

# config/routes.rb
mount MissionControl::Jobs::Engine, at: "/jobs"
```

### Console Queries

```ruby
# Check pending jobs
SolidQueue::Job.where(finished_at: nil).count

# Check failed jobs
SolidQueue::FailedExecution.count

# Retry failed job
SolidQueue::FailedExecution.last.retry

# Clear old completed jobs
SolidQueue::Job.where('finished_at < ?', 1.week.ago).delete_all
```

## Migration from Sidekiq

| Sidekiq | Solid Queue |
|---------|-------------|
| `perform_async(args)` | `perform_later(args)` |
| `perform_in(5.minutes, args)` | `set(wait: 5.minutes).perform_later(args)` |
| `sidekiq_options queue: 'critical'` | `queue_as :critical` |
| `sidekiq_retry_in` | `retry_on` with `wait:` |
