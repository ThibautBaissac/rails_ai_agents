# Recurring Jobs (Solid Queue)

Scheduled/recurring tasks using Solid Queue's built-in recurring job support.

## Configuration

```yaml
# config/recurring.yml
production:
  # Bundle and send notifications every 30 minutes
  deliver_bundled_notifications:
    command: "Notification::Bundle.deliver_all_later"
    schedule: every 30 minutes

  # Cleanup old sessions daily at 3am
  cleanup_old_sessions:
    command: "Session.cleanup_old_sessions_later"
    schedule: every day at 3am

  # Mark entropic cards (daily at 2am)
  mark_entropic_cards:
    command: "Card.mark_entropic_later"
    schedule: every day at 2am

  # Weekly digest (Sundays at 9am)
  weekly_digest:
    command: "Digest.send_weekly_later"
    schedule: every sunday at 9am

development:
  # Same jobs, but more frequent for testing
  deliver_bundled_notifications:
    command: "Notification::Bundle.deliver_all_later"
    schedule: every 5 minutes
```

## Pattern: recurring job calls _later, which enqueues a job, which calls _now

The recurring.yml `command` calls a class method that enqueues a job:

```yaml
# config/recurring.yml
mark_entropic_cards:
  command: "Card.mark_entropic_later"
  schedule: every day at 2am
```

```ruby
# app/models/card.rb
class Card < ApplicationRecord
  def self.mark_entropic_later
    MarkEntropicCardsJob.perform_later
  end

  def self.mark_entropic_now
    entropic.find_each do |card|
      card.postpone(user: nil)  # System action
    end
  end

  scope :entropic, -> {
    open
      .published
      .where.missing(:not_now)
      .where("updated_at < ?", 30.days.ago)
  }
end
```

```ruby
# app/jobs/mark_entropic_cards_job.rb
class MarkEntropicCardsJob < ApplicationJob
  queue_as :low_priority

  def perform
    Card.mark_entropic_now
  end
end
```

## Pattern: bundled notification delivery

```ruby
# app/models/notification/bundle.rb
class Notification::Bundle
  def self.deliver_all_later
    DeliverBundledNotificationsJob.perform_later
  end

  def self.deliver_all_now
    User.find_each do |user|
      bundle = new(user)
      bundle.deliver if bundle.has_notifications?
    end
  end

  attr_reader :user

  def initialize(user)
    @user = user
  end

  def has_notifications?
    unread_notifications.any?
  end

  def deliver
    NotificationMailer.bundled(user, unread_notifications).deliver_now
    mark_as_bundled
  end

  private

  def unread_notifications
    @unread_notifications ||= user.notifications.unread.where("created_at > ?", 30.minutes.ago)
  end

  def mark_as_bundled
    unread_notifications.update_all(bundled_at: Time.current)
  end
end
```

## Pattern: session cleanup

```ruby
# app/models/session.rb
class Session < ApplicationRecord
  def self.cleanup_old_sessions_later
    SessionCleanupJob.perform_later
  end

  def self.cleanup_old_sessions_now
    where("created_at < ?", 30.days.ago).delete_all
    MagicLink.where("expires_at < ?", 1.day.ago).delete_all
  end
end
```

## Testing recurring jobs

```ruby
class CardTest < ActiveSupport::TestCase
  test "mark_entropic_now postpones old cards" do
    card = cards(:old_card)
    card.update!(updated_at: 31.days.ago)

    assert_difference -> { Card::NotNow.count }, 1 do
      Card.mark_entropic_now
    end

    assert card.reload.postponed?
  end
end
```

## Schedule syntax

Common schedule expressions:

```yaml
schedule: every 5 minutes
schedule: every 30 minutes
schedule: every hour
schedule: every day at 3am
schedule: every day at 2:30am
schedule: every monday at 9am
schedule: every sunday at 9am
schedule: every 1st of month at midnight
```
