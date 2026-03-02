# Mailer Patterns

## 1. Simple Transactional Mailer

```ruby
# app/mailers/entity_mailer.rb
class EntityMailer < ApplicationMailer
  # Subject can be set in your I18n file at config/locales/en.yml
  # with the following lookup:
  #
  #   en.entity_mailer.created.subject
  #
  def created(entity)
    @entity = entity
    @owner = entity.owner

    mail(
      to: email_address_with_name(@owner.email, @owner.full_name),
      subject: "Your entity #{@entity.name} has been created"
    )
  end

  def updated(entity)
    @entity = entity
    @owner = entity.owner

    mail(
      to: @owner.email,
      subject: "Your entity has been updated"
    )
  end

  def approved(entity)
    @entity = entity
    @owner = entity.owner
    @dashboard_url = entity_dashboard_url(@entity)

    mail(
      to: @owner.email,
      subject: "🎉 Your entity has been approved!"
    )
  end
end
```

## 2. Mailer with Attachments

```ruby
# app/mailers/report_mailer.rb
class ReportMailer < ApplicationMailer
  def monthly_report(user, month)
    @user = user
    @month = month
    @stats = calculate_stats(user, month)

    # Generate PDF
    pdf = ReportPdfGenerator.new(user, month).generate

    attachments["report_#{month.strftime('%Y-%m')}.pdf"] = pdf

    mail(
      to: @user.email,
      subject: "Your monthly report - #{month.strftime('%B %Y')}"
    )
  end

  def invoice(order)
    @order = order
    @user = order.user

    # Attach from ActiveStorage
    if order.invoice.attached?
      attachments[order.invoice.filename.to_s] = order.invoice.download
    end

    mail(
      to: @user.email,
      subject: "Invoice ##{order.number}"
    )
  end

  private

  def calculate_stats(user, month)
    # Statistics calculation logic
    {
      entities_count: user.entities.count,
      submissions_count: user.submissions.where(created_at: month.all_month).count
    }
  end
end
```

## 3. Mailer with Multiple Recipients

```ruby
# app/mailers/submission_mailer.rb
class SubmissionMailer < ApplicationMailer
  def new_submission(submission)
    @submission = submission
    @entity = submission.entity
    @owner = @entity.owner
    @author = submission.author

    mail(
      to: @owner.email,
      cc: admin_emails,
      subject: "New submission for #{@entity.name}",
      reply_to: @author.email
    )
  end

  def submission_response(submission, response)
    @submission = submission
    @response = response
    @entity = submission.entity
    @author = submission.author

    mail(
      to: @author.email,
      subject: "Response to your submission on #{@entity.name}"
    )
  end

  private

  def admin_emails
    User.admin.pluck(:email)
  end
end
```

## 4. Mailer with Conditions and Locales

```ruby
# app/mailers/notification_mailer.rb
class NotificationMailer < ApplicationMailer
  def weekly_digest(user)
    @user = user
    @notifications = user.notifications.unread.where("created_at > ?", 7.days.ago)

    return if @notifications.empty? # Don't send if empty

    I18n.with_locale(@user.locale || :en) do
      mail(
        to: @user.email,
        subject: I18n.t("mailers.notification.weekly_digest.subject", count: @notifications.count)
      )
    end
  end

  def reminder(user, action_type)
    @user = user
    @action_type = action_type
    @action_url = action_url_for(action_type)

    # Don't send if user disabled notifications
    return unless @user.notification_preferences.email_reminders?

    mail(
      to: @user.email,
      subject: reminder_subject_for(action_type)
    )
  end

  private

  def action_url_for(action_type)
    case action_type
    when "complete_profile"
      edit_user_url(@user)
    when "add_entity"
      new_entity_url
    else
      root_url
    end
  end

  def reminder_subject_for(action_type)
    I18n.t("mailers.notification.reminder.#{action_type}.subject")
  end
end
```
