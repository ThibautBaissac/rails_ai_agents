# Job Patterns

## 1. Simple and Idempotent Job

```ruby
# app/jobs/calculate_metrics_job.rb
class CalculateMetricsJob < ApplicationJob
  queue_as :default

  def perform(entity_id)
    entity = Entity.find_by(id: entity_id)
    return unless entity # Idempotent: ignore if deleted

    log_job_execution("Calculating metrics for entity ##{entity_id}")

    average_score = entity.submissions.average(:rating).to_f.round(1)
    submissions_count = entity.submissions.count

    entity.update!(
      average_score: average_score,
      submissions_count: submissions_count
    )

    log_job_execution("Metrics updated: #{average_score} (#{submissions_count} submissions)")
  end
end
```

## 2. Job with Custom Retry

```ruby
# app/jobs/send_notification_job.rb
class SendNotificationJob < ApplicationJob
  queue_as :notifications

  # Retry up to 5 times with exponential backoff
  retry_on StandardError, wait: :exponentially_longer, attempts: 5

  # Don't retry on certain errors
  discard_on NotificationDisabledError
  discard_on InvalidRecipientError

  # Timeout after 30 seconds
  around_perform do |job, block|
    Timeout.timeout(30) do
      block.call
    end
  end

  def perform(user_id, notification_type, data = {})
    user = User.find(user_id)

    return unless user.notifications_enabled?

    log_job_execution("Sending notification #{notification_type} to user ##{user_id}")

    NotificationService.send(
      user: user,
      type: notification_type,
      data: data
    )
  rescue Timeout::Error
    Rails.logger.error("[#{self.class.name}] Timeout for user ##{user_id}")
    raise # Will retry
  end
end
```

## 3. Job with Batch Processing

```ruby
# app/jobs/send_weekly_digest_job.rb
class SendWeeklyDigestJob < ApplicationJob
  queue_as :mailers

  def perform
    log_job_execution("Starting weekly digest sending")

    users_count = 0
    errors_count = 0

    User.where(digest_enabled: true).find_each(batch_size: 100) do |user|
      begin
        DigestMailer.weekly(user).deliver_now
        users_count += 1
      rescue StandardError => e
        Rails.logger.error("[#{self.class.name}] Error for user ##{user.id}: #{e.message}")
        errors_count += 1
      end

      # Avoid overloading mail server
      sleep 0.1
    end

    log_job_execution("Digests sent: #{users_count} success, #{errors_count} errors")
  end
end
```

## 4. Job with Dependencies and Cascading Enqueue

```ruby
# app/jobs/process_import_job.rb
class ProcessImportJob < ApplicationJob
  queue_as :imports

  def perform(import_id)
    import = Import.find(import_id)

    log_job_execution("Processing import ##{import_id}")

    import.update!(status: :processing, started_at: Time.current)

    entities_data = parse_import_file(import)
    created_entities = []

    entities_data.each do |entity_data|
      entity = create_entity(entity_data)
      created_entities << entity if entity
    end

    import.update!(
      status: :completed,
      completed_at: Time.current,
      processed_count: created_entities.count
    )

    # Enqueue jobs for each created entity
    created_entities.each do |entity|
      GeocodingJob.perform_later(entity.id)
      CalculateMetricsJob.perform_later(entity.id)
    end

    # Notify the user
    ImportMailer.completed(import).deliver_later

    log_job_execution("Import completed: #{created_entities.count} entities created")
  rescue StandardError => e
    import.update!(status: :failed, error_message: e.message)
    ImportMailer.failed(import).deliver_later
    raise
  end

  private

  def parse_import_file(import)
    # Parse CSV, JSON, etc.
    CSV.parse(import.file.download, headers: true).map(&:to_h)
  end

  def create_entity(data)
    Entity.create!(
      name: data["name"],
      address: data["address"],
      phone: data["phone"]
    )
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.warn("Invalid entity: #{e.message}")
    nil
  end
end
```

## 5. Job with Progress Tracking

```ruby
# app/jobs/export_data_job.rb
class ExportDataJob < ApplicationJob
  queue_as :exports

  def perform(user_id, export_type)
    user = User.find(user_id)
    export = user.exports.create!(export_type: export_type, status: :processing)

    log_job_execution("Export #{export_type} for user ##{user_id}")

    begin
      total_records = count_records(user, export_type)
      processed = 0

      csv_data = CSV.generate do |csv|
        csv << headers_for(export_type)

        records_for(user, export_type).find_each do |record|
          csv << data_for(record, export_type)
          processed += 1

          # Update progress every 100 records
          if processed % 100 == 0
            progress = (processed.to_f / total_records * 100).round(2)
            export.update!(progress: progress)
          end
        end
      end

      # Attach CSV file
      export.file.attach(
        io: StringIO.new(csv_data),
        filename: "export_#{export_type}_#{Date.current}.csv",
        content_type: "text/csv"
      )

      export.update!(status: :completed, completed_at: Time.current, progress: 100)

      # Notify the user
      ExportMailer.ready(export).deliver_later

      log_job_execution("Export completed: #{processed} records")
    rescue StandardError => e
      export.update!(status: :failed, error_message: e.message)
      raise
    end
  end

  private

  def count_records(user, export_type)
    records_for(user, export_type).count
  end

  def records_for(user, export_type)
    case export_type
    when "entities"
      user.entities
    when "submissions"
      user.submissions
    else
      raise ArgumentError, "Unknown export type: #{export_type}"
    end
  end

  def headers_for(export_type)
    case export_type
    when "entities"
      ["ID", "Name", "Address", "Phone", "Created At"]
    when "submissions"
      ["ID", "Entity", "Rating", "Content", "Date"]
    end
  end

  def data_for(record, export_type)
    case export_type
    when "entities"
      [record.id, record.name, record.address, record.phone, record.created_at]
    when "submissions"
      [record.id, record.entity.name, record.rating, record.content, record.created_at]
    end
  end
end
```

## 6. Recurring Cleanup Job

```ruby
# app/jobs/cleanup_old_data_job.rb
class CleanupOldDataJob < ApplicationJob
  queue_as :maintenance

  def perform
    log_job_execution("Starting old data cleanup")

    deleted_counts = {
      sessions: cleanup_old_sessions,
      notifications: cleanup_old_notifications,
      exports: cleanup_old_exports,
      logs: cleanup_old_logs
    }

    log_job_execution("Cleanup completed: #{deleted_counts}")
  end

  private

  def cleanup_old_sessions
    count = ActiveRecord::SessionStore::Session
      .where("updated_at < ?", 30.days.ago)
      .delete_all

    log_job_execution("Sessions deleted: #{count}")
    count
  end

  def cleanup_old_notifications
    count = Notification
      .read
      .where("created_at < ?", 90.days.ago)
      .delete_all

    log_job_execution("Notifications deleted: #{count}")
    count
  end

  def cleanup_old_exports
    exports = Export
      .completed
      .where("created_at < ?", 7.days.ago)

    count = exports.count

    exports.find_each do |export|
      export.file.purge if export.file.attached?
      export.destroy
    end

    log_job_execution("Exports deleted: #{count}")
    count
  end

  def cleanup_old_logs
    # Clean up application logs if stored in database
    count = ActivityLog
      .where("created_at < ?", 180.days.ago)
      .delete_all

    log_job_execution("Logs deleted: #{count}")
    count
  end
end
```
