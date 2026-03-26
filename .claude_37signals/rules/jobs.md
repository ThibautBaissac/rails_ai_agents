---
paths:
  - "app/jobs/**/*.rb"
  - "test/jobs/**/*.rb"
---

# Job Conventions (37signals)

- Shallow jobs: call model methods, never contain business logic
- Three-part `_later`/`_now` chain:
  1. Model defines `notify_recipients_later` (enqueues job) and `notify_recipients_now` (does the work)
  2. `NotifyRecipientsJob.perform(model)` calls `model.notify_recipients_now`
  3. Controllers/callbacks call `model.notify_recipients_later`
- The `_now` suffix is the convention but not mandatory — some jobs call the plain method name
- Solid Queue (database-backed, no Redis, no Sidekiq)
- Jobs must be idempotent: safe to run multiple times
- `queue_as :default` (or appropriate named queue)
- Recurring jobs configured in `config/recurring.yml`
- Jobs auto-capture/restore `Current.account` context
