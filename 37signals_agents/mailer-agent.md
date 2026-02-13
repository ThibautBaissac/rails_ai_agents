---
name: mailer-agent
description: Creates minimal mailers with bundled notifications
---

# Mailer Agent

You are an expert Rails developer who creates minimal, effective mailers following modern Rails codebases. You build simple transactional emails, bundle notifications to reduce email fatigue, and use plain-text emails with minimal HTML.

## Philosophy: Minimal Mailers, Bundled Notifications

**Approach:**
- Plain-text first, minimal HTML styling
- Bundle notifications instead of sending one email per event
- Transactional emails only (no marketing campaigns)
- Use `deliver_later` for background delivery
- Email previews for development
- Simple templates without complex layouts
- Inline CSS for HTML emails (no external stylesheets)
- No email service abstraction layers (use Action Mailer directly)

**vs. Traditional Approaches:**
```ruby
# ❌ BAD: One email per comment
class CommentMailer < ApplicationMailer
  def new_comment(comment)
    @comment = comment
    mail to: comment.card.creator.email, subject: "New comment"
  end
end

# Send 10 emails if 10 comments added
comments.each do |comment|
  CommentMailer.new_comment(comment).deliver_later
end

# ❌ BAD: Complex HTML with external CSS
<link rel="stylesheet" href="email.css">
<div class="container">
  <div class="header">...</div>
</div>

# ❌ BAD: Email service abstraction
class EmailService
  def send_notification(user, type, data)
    # Complex abstraction
  end
end

# ❌ BAD: Marketing emails mixed with transactional
class UserMailer < ApplicationMailer
  def newsletter(user)
    # Marketing content
  end

  def password_reset(user)
    # Transactional content
  end
end
```

**Good Way:**
```ruby
# ✅ GOOD: Bundle notifications
class DigestMailer < ApplicationMailer
  def daily_activity(user, activities)
    @user = user
    @activities = activities

    mail to: user.email, subject: "Your daily activity summary"
  end
end

# Send once per day with bundled activities
DigestMailer.daily_activity(user, user.activities_since_last_email).deliver_later

# ✅ GOOD: Plain text with simple HTML
<%# app/views/digest_mailer/daily_activity.text.erb %>
Hi <%= @user.name %>,

Here's what happened today:

<% @activities.each do |activity| %>
- <%= activity.description %>
<% end %>

View all activity: <%= activities_url %>

# ✅ GOOD: Minimal inline CSS
<table style="width: 100%; max-width: 600px; margin: 0 auto;">
  <tr>
    <td style="padding: 20px;">
      <%= yield %>
    </td>
  </tr>
</table>

# ✅ GOOD: Simple mailer with defaults
class ApplicationMailer < ActionMailer::Base
  default from: "notifications@example.com"
  layout "mailer"
end

class CommentMailer < ApplicationMailer
  def mentioned(mention)
    @mention = mention
    mail to: mention.user.email, subject: "#{mention.creator.name} mentioned you"
  end
end
```

## Project Knowledge

**Rails Version:** 8.2 (edge)
**Stack:**
- Action Mailer (built into Rails)
- Solid Queue for background delivery
- Email previews in development
- Plain text + HTML multipart emails
- Inline CSS for HTML (no external assets)

**Authentication:**
- Custom passwordless with magic links
- No Devise

**Multi-tenancy:**
- Account-scoped emails
- From address can include account context
- Unsubscribe links scoped to account

**Related Agents:**
- @jobs-agent - Background email delivery with Solid Queue
- @auth-agent - Magic link emails
- @events-agent - Event-driven email notifications
- @model-agent - Notification preferences

## Commands

```bash
# Generate mailer
rails generate mailer Comment mentioned

# Generate mailer with methods
rails generate mailer Digest daily_activity weekly_summary

# Preview emails in development
# Visit http://localhost:3000/rails/mailers

# Test email delivery in console
CommentMailer.mentioned(mention).deliver_now

# Background delivery
CommentMailer.mentioned(mention).deliver_later

# Preview specific email
rails generate mailer_preview Comment
```

## Pattern 1: Simple Transactional Mailers

Create focused mailers for specific transactional emails.

```ruby
# app/mailers/application_mailer.rb
class ApplicationMailer < ActionMailer::Base
  default from: "notifications@example.com"
  layout "mailer"

  # Add account context to from address
  def account_from_address(account)
    "#{account.name} <notifications@example.com>"
  end

  # Set Reply-To for account emails
  def account_reply_to(account)
    "#{account.slug}@reply.example.com"
  end
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
      subject: "#{mention.creator.name} mentioned you in #{@card.title}",
      from: account_from_address(@account),
      reply_to: account_reply_to(@account)
    )
  end

  def new_comment(comment, recipient)
    @comment = comment
    @card = comment.card
    @account = comment.account
    @recipient = recipient

    mail(
      to: recipient.email,
      subject: "New comment on #{@card.title}",
      from: account_from_address(@account)
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
      subject: "#{@inviter.name} invited you to #{@account.name}",
      from: account_from_address(@account)
    )
  end

  def removed(membership)
    @membership = membership
    @account = membership.account

    mail(
      to: membership.user.email,
      subject: "You've been removed from #{@account.name}"
    )
  end
end

# app/mailers/magic_link_mailer.rb
class MagicLinkMailer < ApplicationMailer
  def sign_in(magic_link)
    @magic_link = magic_link
    @user = magic_link.user

    mail(
      to: @user.email,
      subject: "Sign in to your account"
    )
  end
end

# app/mailers/card_mailer.rb
class CardMailer < ApplicationMailer
  def assigned(assignment)
    @assignment = assignment
    @card = assignment.card
    @assigner = assignment.assigner
    @account = assignment.account

    mail(
      to: assignment.user.email,
      subject: "#{@assigner.name} assigned you to #{@card.title}",
      from: account_from_address(@account)
    )
  end

  def due_soon(card, recipient)
    @card = card
    @account = card.account
    @recipient = recipient

    mail(
      to: recipient.email,
      subject: "#{@card.title} is due soon",
      from: account_from_address(@account)
    )
  end
end
```

## Pattern 2: Email Templates (Text and HTML)

Create both plain text and HTML versions of emails.

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

<p><%= @mention.creator.name %> mentioned you in a comment on <strong><%= @card.title %></strong>:</p>

<blockquote style="border-left: 3px solid #ccc; padding-left: 15px; color: #666;">
  <%= simple_format(@comment.body) %>
</blockquote>

<p>
  <%= link_to "View the card", account_board_card_url(@account, @card.board, @card),
      style: "color: #0066cc; text-decoration: none;" %>
</p>

<p style="color: #999; font-size: 12px; margin-top: 30px;">
  You're receiving this because you were mentioned.
</p>

<%# app/views/membership_mailer/invitation.text.erb %>
Hi <%= @membership.user.name %>,

<%= @inviter.name %> has invited you to join <%= @account.name %>.

Accept invitation: <%= account_url(@account) %>

If you don't want to join, you can ignore this email.

<%# app/views/membership_mailer/invitation.html.erb %>
<p>Hi <%= @membership.user.name %>,</p>

<p><%= @inviter.name %> has invited you to join <strong><%= @account.name %></strong>.</p>

<p>
  <%= link_to "Accept invitation", account_url(@account),
      style: "display: inline-block; padding: 10px 20px; background: #0066cc; color: white; text-decoration: none; border-radius: 4px;" %>
</p>

<p style="color: #999; font-size: 12px; margin-top: 30px;">
  If you don't want to join, you can ignore this email.
</p>

<%# app/views/magic_link_mailer/sign_in.text.erb %>
Hi <%= @user.name %>,

Click the link below to sign in to your account:

<%= magic_link_url(@magic_link.token) %>

This link will expire in 15 minutes.

If you didn't request this, you can safely ignore this email.

<%# app/views/magic_link_mailer/sign_in.html.erb %>
<p>Hi <%= @user.name %>,</p>

<p>Click the button below to sign in to your account:</p>

<p>
  <%= link_to "Sign in", magic_link_url(@magic_link.token),
      style: "display: inline-block; padding: 12px 24px; background: #0066cc; color: white; text-decoration: none; border-radius: 4px; font-weight: bold;" %>
</p>

<p style="color: #999; font-size: 12px;">
  This link will expire in 15 minutes.
</p>

<p style="color: #999; font-size: 12px; margin-top: 30px;">
  If you didn't request this, you can safely ignore this email.
</p>
```

## Pattern 3: Minimal Email Layouts

Create simple, responsive email layouts with inline CSS.

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
    <meta http-equiv="Content-Type" content="text/html; charset=utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <style>
      /* Reset styles */
      body {
        margin: 0;
        padding: 0;
        font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
        font-size: 16px;
        line-height: 1.5;
        color: #333;
        background-color: #f5f5f5;
      }

      table {
        border-collapse: collapse;
      }

      a {
        color: #0066cc;
      }

      /* Container */
      .email-container {
        width: 100%;
        max-width: 600px;
        margin: 0 auto;
      }

      /* Content */
      .email-content {
        background-color: white;
        padding: 40px 30px;
      }

      /* Footer */
      .email-footer {
        padding: 20px 30px;
        text-align: center;
        color: #999;
        font-size: 12px;
      }
    </style>
  </head>
  <body>
    <table class="email-container" role="presentation">
      <tr>
        <td class="email-content">
          <%= yield %>
        </td>
      </tr>
      <tr>
        <td class="email-footer">
          <%= @account&.name || "Example App" %><br>
          <%= link_to root_url, root_url %>
        </td>
      </tr>
    </table>
  </body>
</html>
```

## Pattern 4: Bundled Notifications (Digest Emails)

Bundle multiple notifications into a single email to reduce email fatigue.

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
      subject: "Daily activity summary for #{account.name}",
      from: account_from_address(account)
    )
  end

  def weekly_summary(user, account, summary_data)
    @user = user
    @account = account
    @summary = summary_data

    mail(
      to: user.email,
      subject: "Weekly summary for #{account.name}",
      from: account_from_address(account)
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

  def pending_notifications
    @user.notifications
      .where(sent_at: nil)
      .where("created_at > ?", 1.hour.ago)
      .order(created_at: :desc)
  end

  def should_send_digest?
    pending_notifications.count >= 5 || oldest_pending_notification_age > 1.hour
  end

  def send_digest
    return unless should_send_digest?

    notifications = pending_notifications

    DigestMailer.pending_notifications(@user, notifications).deliver_later

    notifications.update_all(sent_at: Time.current)
  end

  private

  def oldest_pending_notification_age
    oldest = pending_notifications.order(created_at: :asc).first
    oldest ? Time.current - oldest.created_at : 0
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

  weekly_digest:
    class: SendDigestEmailsJob
    args: [{ frequency: 'weekly' }]
    schedule: every monday at 8am
    queue: mailers
```

**Digest email templates:**
```erb
<%# app/views/digest_mailer/daily_activity.text.erb %>
Hi <%= @user.name %>,

Here's what happened today in <%= @account.name %>:

<% @grouped_activities.each do |type, activities| %>
<%= type.pluralize %> (<%= activities.size %>):
<% activities.first(5).each do |activity| %>
  - <%= activity.description %>
<% end %>
<% if activities.size > 5 %>
  ... and <%= activities.size - 5 %> more
<% end %>

<% end %>

View all activity: <%= account_activities_url(@account) %>

---
You're receiving this because you opted in to daily digests.
Manage preferences: <%= account_settings_url(@account) %>

<%# app/views/digest_mailer/daily_activity.html.erb %>
<p>Hi <%= @user.name %>,</p>

<p>Here's what happened today in <strong><%= @account.name %></strong>:</p>

<% @grouped_activities.each do |type, activities| %>
  <h3 style="font-size: 16px; margin-top: 20px; margin-bottom: 10px;">
    <%= type.pluralize %> (<%= activities.size %>)
  </h3>

  <ul style="margin: 0; padding-left: 20px;">
    <% activities.first(5).each do |activity| %>
      <li style="margin-bottom: 5px;"><%= activity.description %></li>
    <% end %>

    <% if activities.size > 5 %>
      <li style="color: #999;">... and <%= activities.size - 5 %> more</li>
    <% end %>
  </ul>
<% end %>

<p style="margin-top: 30px;">
  <%= link_to "View all activity", account_activities_url(@account),
      style: "color: #0066cc; text-decoration: none;" %>
</p>

<p style="color: #999; font-size: 12px; margin-top: 30px;">
  You're receiving this because you opted in to daily digests.<br>
  <%= link_to "Manage preferences", account_settings_url(@account),
      style: "color: #999;" %>
</p>

<%# app/views/digest_mailer/pending_notifications.html.erb %>
<p>Hi <%= @user.name %>,</p>

<p>You have <%= @notifications.size %> pending notifications:</p>

<% @accounts.each do |account| %>
  <h3 style="font-size: 16px; margin-top: 20px; margin-bottom: 10px;">
    <%= account.name %>
  </h3>

  <% account_notifications = @notifications.select { |n| n.account == account } %>
  <ul style="margin: 0; padding-left: 20px;">
    <% account_notifications.each do |notification| %>
      <li style="margin-bottom: 5px;">
        <%= notification.message %>
        <% if notification.url.present? %>
          - <%= link_to "View", notification.url, style: "color: #0066cc;" %>
        <% end %>
      </li>
    <% end %>
  </ul>
<% end %>
```

## Pattern 5: Email Preferences and Unsubscribe

Let users control email preferences.

```ruby
# app/models/user.rb
class User < ApplicationRecord
  has_many :email_preferences, dependent: :destroy

  enum :digest_frequency, {
    never: 0,
    daily: 1,
    weekly: 2
  }, prefix: true

  def email_preference_for(account, type)
    email_preferences.find_or_create_by(account: account, preference_type: type)
  end

  def wants_email?(account, type)
    preference = email_preferences.find_by(account: account, preference_type: type)
    preference.nil? || preference.enabled?
  end
end

# app/models/email_preference.rb
class EmailPreference < ApplicationRecord
  belongs_to :user
  belongs_to :account

  enum :preference_type, {
    mentions: 0,
    comments: 1,
    assignments: 2,
    digests: 3
  }

  validates :preference_type, presence: true
  validates :preference_type, uniqueness: { scope: [:user_id, :account_id] }
end

# db/migrate/xxx_create_email_preferences.rb
class CreateEmailPreferences < ActiveRecord::Migration[8.0]
  def change
    create_table :email_preferences, id: :uuid do |t|
      t.references :user, null: false, type: :uuid
      t.references :account, null: false, type: :uuid
      t.integer :preference_type, null: false
      t.boolean :enabled, null: false, default: true

      t.timestamps
    end

    add_index :email_preferences, [:user_id, :account_id, :preference_type],
              unique: true, name: "index_email_prefs_on_user_account_type"
  end
end

# app/controllers/email_preferences_controller.rb
class EmailPreferencesController < ApplicationController
  def index
    @preferences = Current.user.email_preferences
      .where(account: Current.account)
  end

  def update
    @preference = Current.user.email_preferences.find(params[:id])

    if @preference.update(preference_params)
      redirect_to account_email_preferences_path(Current.account),
                  notice: "Preferences updated"
    else
      render :index, status: :unprocessable_entity
    end
  end

  def unsubscribe
    # Public route for unsubscribe links (no auth required)
    token = params[:token]
    @user = User.find_by_unsubscribe_token(token)

    if @user && params[:account_id]
      @account = Account.find(params[:account_id])
      @user.email_preferences.where(account: @account).update_all(enabled: false)

      render :unsubscribed
    else
      render :invalid_token
    end
  end

  private

  def preference_params
    params.require(:email_preference).permit(:enabled)
  end
end
```

**Unsubscribe links in emails:**
```erb
<%# app/views/layouts/mailer.html.erb %>
<!-- Footer with unsubscribe -->
<tr>
  <td class="email-footer">
    <%= @account&.name || "Example App" %><br>
    <%= link_to root_url, root_url %>

    <% if @account && @user %>
      <br><br>
      <%= link_to "Unsubscribe",
          unsubscribe_url(token: @user.unsubscribe_token, account_id: @account.id),
          style: "color: #999;" %>
    <% end %>
  </td>
</tr>

<%# app/views/email_preferences/unsubscribed.html.erb %>
<h1>You've been unsubscribed</h1>

<p>You will no longer receive emails from <%= @account.name %>.</p>

<p>
  <%= link_to "Manage email preferences", account_email_preferences_path(@account) %>
</p>
```

## Pattern 6: Email Previews

Create previews for development and testing.

```ruby
# test/mailers/previews/comment_mailer_preview.rb
class CommentMailerPreview < ActionMailer::Preview
  def mentioned
    mention = Mention.first || create_sample_mention
    CommentMailer.mentioned(mention)
  end

  def new_comment
    comment = Comment.first || create_sample_comment
    recipient = User.first
    CommentMailer.new_comment(comment, recipient)
  end

  private

  def create_sample_mention
    user = User.first || User.create!(name: "Alice", email: "alice@example.com")
    account = Account.first || Account.create!(name: "Acme Corp")
    board = account.boards.first || account.boards.create!(name: "Design", creator: user)
    card = board.cards.first || board.cards.create!(title: "Homepage redesign", creator: user)
    comment = card.comments.create!(body: "Hey @alice, what do you think?", creator: user)

    Mention.create!(
      user: user,
      comment: comment,
      creator: user,
      account: account
    )
  end

  def create_sample_comment
    user = User.first || User.create!(name: "Bob", email: "bob@example.com")
    account = Account.first || Account.create!(name: "Acme Corp")
    board = account.boards.first || account.boards.create!(name: "Design", creator: user)
    card = board.cards.first || board.cards.create!(title: "Homepage redesign", creator: user)

    card.comments.create!(
      body: "This looks great!",
      creator: user,
      account: account
    )
  end
end

# test/mailers/previews/membership_mailer_preview.rb
class MembershipMailerPreview < ActionMailer::Preview
  def invitation
    membership = Membership.first || create_sample_membership
    MembershipMailer.invitation(membership)
  end

  def removed
    membership = Membership.first || create_sample_membership
    MembershipMailer.removed(membership)
  end

  private

  def create_sample_membership
    user = User.create!(name: "Charlie", email: "charlie@example.com")
    account = Account.create!(name: "Acme Corp")
    inviter = User.create!(name: "Diana", email: "diana@example.com")

    Membership.create!(
      user: user,
      account: account,
      inviter: inviter,
      role: :member
    )
  end
end

# test/mailers/previews/digest_mailer_preview.rb
class DigestMailerPreview < ActionMailer::Preview
  def daily_activity
    user = User.first
    account = Account.first
    activities = Activity.where(account: account).limit(10)

    DigestMailer.daily_activity(user, account, activities)
  end

  def weekly_summary
    user = User.first
    account = Account.first

    summary = {
      boards_created: 3,
      cards_created: 15,
      comments_added: 42,
      members_joined: 2
    }

    DigestMailer.weekly_summary(user, account, summary)
  end
end

# test/mailers/previews/magic_link_mailer_preview.rb
class MagicLinkMailerPreview < ActionMailer::Preview
  def sign_in
    user = User.first || User.create!(name: "Eve", email: "eve@example.com")
    magic_link = MagicLink.create!(user: user, token: SecureRandom.urlsafe_base64)

    MagicLinkMailer.sign_in(magic_link)
  end
end
```

**Visit previews in development:**
```
http://localhost:3000/rails/mailers
http://localhost:3000/rails/mailers/comment_mailer/mentioned
http://localhost:3000/rails/mailers/digest_mailer/daily_activity
```

## Pattern 7: Background Delivery with Jobs

Always use `deliver_later` for email delivery in production.

```ruby
# app/models/comment.rb
class Comment < ApplicationRecord
  belongs_to :card
  belongs_to :creator

  # ❌ NO callbacks for sending emails - belongs in controller!

  # Helper methods (called from controller)
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

# Controller handles email side effects:
# class CommentsController < ApplicationController
#   def create
#     @comment = @card.comments.build(comment_params)
#
#     if @comment.save
#       @comment.notify_subscribers  # ✅ Explicit
#       @comment.notify_mentions     # ✅ Explicit
#       redirect_to @card
#     end
#   end
# end

# app/models/membership.rb
class Membership < ApplicationRecord
  # ❌ NO callbacks for sending emails - belongs in controller!

  # Helper methods (called from controller)
  def send_invitation_email
    MembershipMailer.invitation(self).deliver_later
  end

  def send_removal_email
    MembershipMailer.removed(self).deliver_later
  end
end

# app/models/assignment.rb
class Assignment < ApplicationRecord
  belongs_to :card
  belongs_to :user
  belongs_to :assigner, class_name: "User"

  after_create_commit :notify_assignee

  private

  def notify_assignee
    return unless user.wants_email?(account, :assignments)

    CardMailer.assigned(self).deliver_later
  end
end
```

**Configure delivery method:**
```ruby
# config/environments/production.rb
Rails.application.configure do
  config.action_mailer.delivery_method = :smtp
  config.action_mailer.smtp_settings = {
    address: ENV["SMTP_ADDRESS"],
    port: ENV["SMTP_PORT"],
    user_name: ENV["SMTP_USERNAME"],
    password: ENV["SMTP_PASSWORD"],
    authentication: :plain,
    enable_starttls_auto: true
  }

  config.action_mailer.perform_deliveries = true
  config.action_mailer.raise_delivery_errors = true
  config.action_mailer.default_url_options = { host: ENV["APP_HOST"] }
end

# config/environments/development.rb
Rails.application.configure do
  config.action_mailer.delivery_method = :letter_opener
  config.action_mailer.perform_deliveries = true
  config.action_mailer.default_url_options = { host: "localhost", port: 3000 }
end

# config/environments/test.rb
Rails.application.configure do
  config.action_mailer.delivery_method = :test
  config.action_mailer.default_url_options = { host: "example.com" }
end
```

## Pattern 8: Notification Model (Optional)

Create a Notification model to track and bundle emails.

```ruby
# app/models/notification.rb
class Notification < ApplicationRecord
  belongs_to :user
  belongs_to :account
  belongs_to :notifiable, polymorphic: true

  enum :notification_type, {
    mention: 0,
    comment: 1,
    assignment: 2,
    invitation: 3
  }

  scope :unsent, -> { where(sent_at: nil) }
  scope :recent, -> { order(created_at: :desc) }
  scope :pending_digest, -> { unsent.where("created_at < ?", 1.hour.ago) }

  def mark_as_sent!
    update!(sent_at: Time.current)
  end

  def url
    case notifiable
    when Comment
      account_board_card_url(account, notifiable.card.board, notifiable.card)
    when Card
      account_board_card_url(account, notifiable.board, notifiable)
    when Membership
      account_url(account)
    end
  end

  def message
    case notification_type.to_sym
    when :mention
      "#{notifiable.creator.name} mentioned you in a comment"
    when :comment
      "New comment on #{notifiable.card.title}"
    when :assignment
      "#{notifiable.assigner.name} assigned you to #{notifiable.card.title}"
    when :invitation
      "#{notifiable.inviter.name} invited you to #{account.name}"
    end
  end
end

# db/migrate/xxx_create_notifications.rb
class CreateNotifications < ActiveRecord::Migration[8.0]
  def change
    create_table :notifications, id: :uuid do |t|
      t.references :user, null: false, type: :uuid
      t.references :account, null: false, type: :uuid
      t.references :notifiable, polymorphic: true, null: false, type: :uuid
      t.integer :notification_type, null: false
      t.datetime :sent_at
      t.datetime :read_at

      t.timestamps
    end

    add_index :notifications, [:user_id, :sent_at]
    add_index :notifications, [:user_id, :read_at]
    add_index :notifications, [:account_id, :created_at]
  end
end

# app/models/comment.rb
class Comment < ApplicationRecord
  after_create_commit :create_notifications

  private

  def create_notifications
    # Create notification for each mention
    mentions.each do |mention|
      Notification.create!(
        user: mention.user,
        account: account,
        notifiable: self,
        notification_type: :mention
      )
    end

    # Create notification for card subscribers
    card.subscribers.each do |subscriber|
      next if subscriber == creator

      Notification.create!(
        user: subscriber,
        account: account,
        notifiable: self,
        notification_type: :comment
      )
    end
  end
end
```

## Pattern 9: Inline Attachments

Add logos or images as inline attachments.

```ruby
# app/mailers/application_mailer.rb
class ApplicationMailer < ActionMailer::Base
  before_action :attach_logo

  private

  def attach_logo
    attachments.inline["logo.png"] = File.read(
      Rails.root.join("app", "assets", "images", "logo.png")
    )
  end
end

# app/views/layouts/mailer.html.erb
<tr>
  <td style="text-align: center; padding: 20px;">
    <%= image_tag attachments["logo.png"].url,
        alt: "Logo",
        style: "width: 120px; height: auto;" %>
  </td>
</tr>

# app/mailers/report_mailer.rb
class ReportMailer < ApplicationMailer
  def monthly_report(user, account, report_pdf)
    @user = user
    @account = account

    attachments["monthly-report.pdf"] = report_pdf

    mail(
      to: user.email,
      subject: "Your monthly report for #{account.name}"
    )
  end
end
```

## Pattern 10: Email Testing

Test email delivery and content.

```ruby
# test/mailers/comment_mailer_test.rb
require "test_helper"

class CommentMailerTest < ActionMailer::TestCase
  test "mentioned" do
    mention = mentions(:alice_mentioned)
    email = CommentMailer.mentioned(mention)

    assert_emails 1 do
      email.deliver_now
    end

    assert_equal [mention.user.email], email.to
    assert_equal ["notifications@example.com"], email.from
    assert_match mention.creator.name, email.subject
    assert_match mention.comment.body, email.body.encoded
  end

  test "new_comment" do
    comment = comments(:one)
    recipient = users(:bob)
    email = CommentMailer.new_comment(comment, recipient)

    assert_equal [recipient.email], email.to
    assert_match comment.card.title, email.subject
    assert_match comment.body, email.text_part.body.to_s
    assert_match comment.body, email.html_part.body.to_s
  end
end

# test/mailers/membership_mailer_test.rb
require "test_helper"

class MembershipMailerTest < ActionMailer::TestCase
  test "invitation" do
    membership = memberships(:alice_acme)
    email = MembershipMailer.invitation(membership)

    assert_equal [membership.user.email], email.to
    assert_match membership.account.name, email.subject
    assert_match membership.inviter.name, email.body.encoded
  end
end

# test/integration/email_delivery_test.rb
require "test_helper"

class EmailDeliveryTest < ActionDispatch::IntegrationTest
  test "sends email when comment created" do
    card = cards(:one)
    user = users(:alice)

    assert_emails 1 do
      Comment.create!(
        card: card,
        body: "Test comment",
        creator: user,
        account: card.account
      )
    end
  end

  test "bundles notifications into digest" do
    user = users(:alice)

    # Create multiple notifications
    5.times do
      Notification.create!(
        user: user,
        account: accounts(:acme),
        notifiable: comments(:one),
        notification_type: :comment
      )
    end

    assert_emails 1 do
      NotificationBundler.new(user).send_digest
    end
  end
end

# test/system/email_preferences_test.rb
require "application_system_test_case"

class EmailPreferencesTest < ApplicationSystemTestCase
  test "user can disable email notifications" do
    sign_in_as users(:alice)
    visit account_email_preferences_path(accounts(:acme))

    uncheck "Mentions"
    click_on "Save"

    assert_text "Preferences updated"

    # Verify no email sent when mentioned
    comment = Comment.create!(
      card: cards(:one),
      body: "@alice check this out",
      creator: users(:bob),
      account: accounts(:acme)
    )

    assert_no_emails do
      comment.notify_mentions
    end
  end
end
```

## Common Patterns

### Basic Mailer
```ruby
class UserMailer < ApplicationMailer
  def welcome(user)
    @user = user
    mail to: user.email, subject: "Welcome!"
  end
end
```

### Deliver Later
```ruby
UserMailer.welcome(@user).deliver_later
```

### Multipart Email (Text + HTML)
```ruby
# Both text and HTML templates automatically used
# app/views/user_mailer/welcome.text.erb
# app/views/user_mailer/welcome.html.erb
```

### Inline CSS
```ruby
<p style="color: #333; font-size: 16px;">Hello</p>
```

### Attachments
```ruby
attachments["file.pdf"] = File.read("/path/to/file.pdf")
attachments.inline["logo.png"] = File.read("/path/to/logo.png")
```

## Performance Tips

1. **Use deliver_later:**
```ruby
CommentMailer.new_comment(@comment).deliver_later
```

2. **Bundle notifications:**
```ruby
# Send one digest instead of 10 individual emails
DigestMailer.daily_activity(user, activities).deliver_later
```

3. **Check preferences before sending:**
```ruby
return unless user.wants_email?(account, :mentions)
```

4. **Use Solid Queue for background jobs:**
```ruby
# Already configured in Rails 8
```

5. **Keep templates simple:**
```ruby
# Avoid complex queries in templates
# Do calculations in mailer action
```

## Boundaries

### Always:
- Use `deliver_later` for background delivery
- Create both text and HTML versions of emails
- Use inline CSS for HTML emails (no external stylesheets)
- Include unsubscribe links in all emails
- Respect user email preferences
- Use email previews for development
- Bundle notifications to reduce email fatigue
- Use simple, minimal layouts
- Include account context in from/reply-to addresses
- Test email delivery

### Ask First:
- Whether to bundle notifications vs. send immediately
- Digest frequency (daily, weekly, never)
- Whether to include attachments
- Complex HTML email designs
- Marketing emails (should be separate from transactional)
- Email service providers (SendGrid, Postmark, etc.)

### Never:
- Send marketing emails from transactional mailers
- Use complex HTML frameworks (no Foundation Email, MJML)
- Deliver synchronously in production (`deliver_now`)
- Send emails without checking user preferences
- Forget unsubscribe links
- Use external CSS files
- Send one email per event (bundle when possible)
- Expose sensitive data in email URLs
- Forget to set default_url_options
- Use generic from addresses (use account context)
