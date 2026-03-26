---
name: mailer-patterns
description: >-
  Creates minimal Action Mailer classes with bundled notification patterns
  following 37signals conventions. Use when sending emails, creating notification
  systems, digest emails, or when user mentions mailers, emails, notifications,
  or transactional messages.
  WHEN NOT: For background job scheduling (use job-patterns), for event-driven
  triggers (use event-tracking).
license: MIT
compatibility: Ruby 3.3+, Rails 8.0+, Action Mailer, Solid Queue
---

# Mailer Patterns

## Philosophy: Minimal Mailers, Bundled Notifications

- Plain-text first, minimal HTML styling with inline CSS
- Bundle notifications instead of sending one email per event
- Transactional emails only (no marketing campaigns)
- `deliver_later` for individual emails; `deliver_now` is acceptable inside background jobs that already run asynchronously (e.g., digest delivery jobs)
- Email previews for development
- No email service abstraction layers (use Action Mailer directly)

## Project Knowledge

**Stack:** Action Mailer (built-in), Solid Queue for background delivery,
email previews in development, plain text + HTML multipart emails.

**Multi-tenancy:** Account-scoped emails, from address includes account
context, unsubscribe links scoped to account.

**Commands:**
```bash
rails generate mailer Comment mentioned         # Generate mailer
rails generate mailer Digest daily_activity      # With methods
# Visit http://localhost:3000/rails/mailers      # Preview emails
```

## Pattern 1: Simple Transactional Mailers

```ruby
# app/mailers/application_mailer.rb
class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch("MAILER_FROM_ADDRESS", "Fizzy <support@fizzy.do>")
  layout "mailer"
end

# app/mailers/comment_mailer.rb
class CommentMailer < ApplicationMailer
  def mentioned(mention)
    @mention = mention
    @comment = mention.comment
    @card = mention.comment.card
    @account = mention.account

    mail(
      to: mention.user.email,
      subject: "#{mention.creator.name} mentioned you in #{@card.title}"
    )
  end

  def new_comment(comment, recipient)
    @comment = comment
    @card = comment.card
    @account = comment.account

    mail(
      to: recipient.email,
      subject: "New comment on #{@card.title}"
    )
  end
end

# app/mailers/membership_mailer.rb
class MembershipMailer < ApplicationMailer
  def invitation(membership)
    @membership = membership
    @account = membership.account
    @inviter = membership.inviter

    mail(
      to: membership.user.email,
      subject: "#{@inviter.name} invited you to #{@account.name}"
    )
  end
end

# app/mailers/card_mailer.rb
class CardMailer < ApplicationMailer
  def assigned(assignment)
    @assignment = assignment
    @card = assignment.card
    @account = assignment.account

    mail(
      to: assignment.user.email,
      subject: "#{assignment.assigner.name} assigned you to #{@card.title}"
    )
  end
end
```

## Pattern 2: Email Templates

See @references/mailer-templates.md for full template examples.

Always create both `.text.erb` and `.html.erb` versions:

```erb
<%# app/views/comment_mailer/mentioned.text.erb %>
Hi <%= @mention.user.name %>,

<%= @mention.creator.name %> mentioned you in a comment on <%= @card.title %>:

"<%= @comment.body %>"

View the card: <%= account_board_card_url(@account, @card.board, @card) %>

---
You're receiving this because you were mentioned.

<%# app/views/comment_mailer/mentioned.html.erb %>
<p>Hi <%= @mention.user.name %>,</p>

<p><%= @mention.creator.name %> mentioned you in a comment on
   <strong><%= @card.title %></strong>:</p>

<blockquote style="border-left: 3px solid #ccc; padding-left: 15px; color: #666;">
  <%= simple_format(@comment.body) %>
</blockquote>

<p><%= link_to "View the card",
    account_board_card_url(@account, @card.board, @card),
    style: "color: #0066cc; text-decoration: none;" %></p>
```

## Pattern 3: Bundled Notifications (Digest Emails)

See @references/bundled-notifications.md for full details.

```ruby
# app/mailers/digest_mailer.rb
class DigestMailer < ApplicationMailer
  def daily_activity(user, account, activities)
    @user = user
    @account = account
    @activities = activities
    @grouped_activities = activities.group_by(&:subject_type)

    mail(
      to: user.email,
      subject: "Daily activity summary for #{account.name}"
    )
  end

  def pending_notifications(user, notifications)
    @user = user
    @notifications = notifications
    @accounts = notifications.map(&:account).uniq

    mail(
      to: user.email,
      subject: "You have #{notifications.size} pending notifications"
    )
  end
end

# app/models/notification_bundler.rb
class NotificationBundler
  def initialize(user)
    @user = user
  end

  def should_send_digest?
    pending_notifications.count >= 5 ||
      oldest_pending_notification_age > 1.hour
  end

  def send_digest
    return unless should_send_digest?
    notifications = pending_notifications
    DigestMailer.pending_notifications(@user, notifications).deliver_later
    notifications.update_all(sent_at: Time.current)
  end

  private

  def pending_notifications
    @user.notifications.where(sent_at: nil)
      .where("created_at > ?", 1.hour.ago)
      .order(created_at: :desc)
  end
end

# app/jobs/send_digest_emails_job.rb
class SendDigestEmailsJob < ApplicationJob
  queue_as :mailers

  def perform(frequency: :daily)
    User.where(digest_frequency: frequency).find_each do |user|
      user.accounts.each do |account|
        activities = user.activities_for_digest(account, frequency)
        if activities.any?
          DigestMailer.daily_activity(user, account, activities).deliver_now
        end
      end
    end
  end
end

# config/recurring.yml
mailers:
  daily_digest:
    class: SendDigestEmailsJob
    args: [{ frequency: 'daily' }]
    schedule: every day at 8am
    queue: mailers
```

## Pattern 4: Background Delivery

Always use `deliver_later` in production. Trigger from model callbacks:

```ruby
class Comment < ApplicationRecord
  after_create_commit :notify_subscribers
  after_create_commit :notify_mentions

  private

  def notify_subscribers
    card.subscribers.each do |subscriber|
      next if subscriber == creator
      next unless subscriber.wants_email?(account, :comments)
      CommentMailer.new_comment(self, subscriber).deliver_later
    end
  end

  def notify_mentions
    mentions.each do |mention|
      next unless mention.user.wants_email?(account, :mentions)
      CommentMailer.mentioned(mention).deliver_later
    end
  end
end
```

## Pattern 5: Email Preferences and Unsubscribe

```ruby
class User < ApplicationRecord
  has_many :email_preferences, dependent: :destroy

  enum :digest_frequency, { never: 0, daily: 1, weekly: 2 }, prefix: true

  def wants_email?(account, type)
    pref = email_preferences.find_by(account: account, preference_type: type)
    pref.nil? || pref.enabled?
  end
end

class EmailPreference < ApplicationRecord
  belongs_to :user
  belongs_to :account

  enum :preference_type, { mentions: 0, comments: 1, assignments: 2, digests: 3 }

  validates :preference_type, uniqueness: { scope: [:user_id, :account_id] }
end
```

## Pattern 6: Email Previews

```ruby
# test/mailers/previews/comment_mailer_preview.rb
class CommentMailerPreview < ActionMailer::Preview
  def mentioned
    mention = Mention.first || create_sample_mention
    CommentMailer.mentioned(mention)
  end

  private

  def create_sample_mention
    user = User.first
    account = Account.first
    board = account.boards.first
    card = board.cards.first
    comment = card.comments.create!(body: "Hey @alice", creator: user)
    Mention.create!(user: user, comment: comment, creator: user, account: account)
  end
end
```

Visit previews at `http://localhost:3000/rails/mailers`.

## Pattern 7: Minimal Email Layout

```erb
<%# app/views/layouts/mailer.text.erb %>
<%= yield %>

---
<%= @account&.name || "Example App" %>
<%= root_url %>

<%# app/views/layouts/mailer.html.erb %>
<!DOCTYPE html>
<html>
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <style>
      body { margin: 0; padding: 0; font-family: -apple-system, sans-serif;
             font-size: 16px; line-height: 1.5; color: #333; background: #f5f5f5; }
      a { color: #0066cc; }
    </style>
  </head>
  <body>
    <table style="width: 100%; max-width: 600px; margin: 0 auto;" role="presentation">
      <tr><td style="background: white; padding: 40px 30px;"><%= yield %></td></tr>
      <tr><td style="padding: 20px 30px; text-align: center; color: #999; font-size: 12px;">
        <%= @account&.name || "Example App" %><br><%= link_to root_url, root_url %>
      </td></tr>
    </table>
  </body>
</html>
```

## Delivery Configuration

```ruby
# config/environments/production.rb
config.action_mailer.delivery_method = :smtp
config.action_mailer.perform_deliveries = true
config.action_mailer.default_url_options = { host: ENV["APP_HOST"] }

# config/environments/development.rb
config.action_mailer.delivery_method = :letter_opener
config.action_mailer.default_url_options = { host: "localhost", port: 3000 }

# config/environments/test.rb
config.action_mailer.delivery_method = :test
config.action_mailer.default_url_options = { host: "example.com" }
```

## Boundaries

### Always
- Create both `.text.erb` and `.html.erb` templates
- Use `deliver_later` for individual emails; `deliver_now` is acceptable inside background jobs that already run asynchronously (e.g., digest delivery jobs)
- Check user email preferences before sending
- Include unsubscribe links in emails
- Use inline CSS for HTML emails (no external stylesheets)
- Scope emails to account context
- Create email previews for development

### Ask First
- Digest frequency and bundling thresholds
- Whether to include inline attachments (logos)
- SMTP provider configuration

### Never
- Send one email per event (bundle notifications)
- Mix marketing and transactional emails
- Use external CSS in email templates
- Build email service abstraction layers
- Send emails synchronously in request cycle
- Skip email preferences check
