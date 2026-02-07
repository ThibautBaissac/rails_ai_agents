---
name: 37signals-mailer
description: Create minimal mailers with bundled notifications and plain-text first approach. Triggers on email, mailer, notifications, digest, transactional email.
allowed-tools: Read, Write, Edit, Bash
---

# 37signals Mailer Skill

## Overview

Create minimal, effective mailers following 37signals patterns. Plain-text first, bundle notifications to reduce email fatigue, use Action Mailer directly.

## Core Philosophy

- **Plain-text first**: Minimal HTML styling with inline CSS
- **Bundle notifications**: One digest email instead of many individual
- **deliver_later**: Always background delivery in production
- **Transactional only**: No marketing emails from app mailers

## Key Patterns

### Pattern 1: Simple Transactional Mailer

```ruby
# app/mailers/comment_mailer.rb
class CommentMailer < ApplicationMailer
  def mentioned(mention)
    @mention = mention
    @comment = mention.comment
    @card = @comment.card

    mail(
      to: mention.user.email,
      subject: "#{mention.creator.name} mentioned you in #{@card.title}"
    )
  end
end
```

### Pattern 2: Text + HTML Templates

```erb
<%# app/views/comment_mailer/mentioned.text.erb %>
Hi <%= @mention.user.name %>,

<%= @mention.creator.name %> mentioned you in <%= @card.title %>:

"<%= @comment.body %>"

View: <%= card_url(@card) %>

<%# app/views/comment_mailer/mentioned.html.erb %>
<p>Hi <%= @mention.user.name %>,</p>

<p><%= @mention.creator.name %> mentioned you in <strong><%= @card.title %></strong>:</p>

<blockquote style="border-left: 3px solid #ccc; padding-left: 15px; color: #666;">
  <%= simple_format(@comment.body) %>
</blockquote>

<p><%= link_to "View", card_url(@card), style: "color: #0066cc;" %></p>
```

### Pattern 3: Bundled Digest Emails

```ruby
# app/mailers/digest_mailer.rb
class DigestMailer < ApplicationMailer
  def daily_activity(user, account, activities)
    @user = user
    @account = account
    @activities = activities
    @grouped = activities.group_by(&:subject_type)

    mail(
      to: user.email,
      subject: "Daily activity summary for #{account.name}"
    )
  end
end

# app/jobs/send_digest_emails_job.rb
class SendDigestEmailsJob < ApplicationJob
  queue_as :mailers

  def perform(frequency: :daily)
    User.where(digest_frequency: frequency).find_each do |user|
      user.accounts.each do |account|
        activities = user.activities_for_digest(account, frequency)
        next unless activities.any?

        DigestMailer.daily_activity(user, account, activities).deliver_now
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
```

### Pattern 4: Minimal Layout

```erb
<%# app/views/layouts/mailer.html.erb %>
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <style>
    body { font-family: sans-serif; font-size: 16px; color: #333; }
    a { color: #0066cc; }
  </style>
</head>
<body>
  <table style="width: 100%; max-width: 600px; margin: 0 auto;">
    <tr><td style="padding: 20px;"><%= yield %></td></tr>
    <tr><td style="padding: 20px; text-align: center; color: #999; font-size: 12px;">
      <%= @account&.name %> | <%= link_to "Unsubscribe", unsubscribe_url(token: @user.unsubscribe_token) %>
    </td></tr>
  </table>
</body>
</html>
```

### Pattern 5: Email Preferences

```ruby
class User < ApplicationRecord
  enum :digest_frequency, { never: 0, daily: 1, weekly: 2 }

  def wants_email?(account, type)
    preference = email_preferences.find_by(account: account, preference_type: type)
    preference.nil? || preference.enabled?
  end
end

# Check before sending
def notify_assignee
  return unless user.wants_email?(account, :assignments)
  CardMailer.assigned(self).deliver_later
end
```

### Pattern 6: Background Delivery

```ruby
# Always use deliver_later in production
class Comment < ApplicationRecord
  after_create_commit :notify_subscribers

  private

  def notify_subscribers
    card.subscribers.each do |subscriber|
      next if subscriber == creator
      next unless subscriber.wants_email?(account, :comments)

      CommentMailer.new_comment(self, subscriber).deliver_later
    end
  end
end
```

## Email Previews

```ruby
# test/mailers/previews/comment_mailer_preview.rb
class CommentMailerPreview < ActionMailer::Preview
  def mentioned
    mention = Mention.first || create_sample_mention
    CommentMailer.mentioned(mention)
  end

  private

  def create_sample_mention
    # Create sample data for preview
  end
end

# Visit http://localhost:3000/rails/mailers
```

## Testing

```ruby
class CommentMailerTest < ActionMailer::TestCase
  test "mentioned email" do
    mention = mentions(:one)
    email = CommentMailer.mentioned(mention)

    assert_emails 1 do
      email.deliver_now
    end

    assert_equal [mention.user.email], email.to
    assert_match mention.creator.name, email.subject
    assert_match mention.comment.body, email.body.encoded
  end
end

# Integration test
test "sends email when comment created" do
  assert_emails 1 do
    Comment.create!(card: cards(:one), body: "Test", creator: users(:alice))
  end
end
```

## Commands

```bash
rails generate mailer Comment mentioned
rails generate mailer Digest daily_activity

# Preview emails
# Visit http://localhost:3000/rails/mailers
```

## Boundaries

### Always
- Use `deliver_later` for background delivery
- Create both text and HTML templates
- Use inline CSS for HTML emails
- Include unsubscribe links
- Respect user email preferences
- Bundle notifications when possible

### Never
- Send marketing from transactional mailers
- Use external CSS files
- Deliver synchronously in production
- Send without checking preferences
- Forget unsubscribe links
