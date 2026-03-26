# Bundled Notifications Reference

## Why Bundle?

Instead of sending 10 emails for 10 comments, send one digest email with all
10 comments grouped. This reduces email fatigue and improves engagement.

## Notification Model

Track individual notifications in the database, then batch-send them:

```ruby
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
end
```

Migration:

```ruby
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
```

## Creating Notifications

Create notification records from model callbacks, then let the digest job
handle email delivery:

```ruby
class Comment < ApplicationRecord
  after_create_commit :create_notifications

  private

  def create_notifications
    # Notification for each mention
    mentions.each do |mention|
      Notification.create!(
        user: mention.user,
        account: account,
        notifiable: self,
        notification_type: :mention
      )
    end

    # Notification for card subscribers
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

## NotificationBundler

Decides when to send bundled emails:

```ruby
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

  def oldest_pending_notification_age
    oldest = pending_notifications.order(created_at: :asc).first
    oldest ? Time.current - oldest.created_at : 0
  end
end
```

## Digest Delivery Schedule

```ruby
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

## Digest Email Templates

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
      style: "color: #0066cc;" %>
</p>

<p style="color: #999; font-size: 12px; margin-top: 30px;">
  You're receiving this because you opted in to daily digests.<br>
  <%= link_to "Manage preferences", account_settings_url(@account),
      style: "color: #999;" %>
</p>
```

## Pending Notifications Template

```erb
<%# app/views/digest_mailer/pending_notifications.html.erb %>
<p>Hi <%= @user.name %>,</p>

<p>You have <%= @notifications.size %> pending notifications:</p>

<% @accounts.each do |account| %>
  <h3 style="font-size: 16px; margin-top: 20px;"><%= account.name %></h3>

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
