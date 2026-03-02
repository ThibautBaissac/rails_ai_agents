# RSpec Tests for Jobs

## Basic Test

```ruby
# spec/jobs/calculate_metrics_job_spec.rb
require "rails_helper"

RSpec.describe CalculateMetricsJob, type: :job do
  describe "#perform" do
    let(:entity) { create(:entity) }
    let!(:submissions) do
      [
        create(:submission, entity: entity, rating: 5),
        create(:submission, entity: entity, rating: 4),
        create(:submission, entity: entity, rating: 5)
      ]
    end

    it "calculates the average score" do
      described_class.perform_now(entity.id)

      entity.reload
      expect(entity.average_score).to eq(4.7)
      expect(entity.submissions_count).to eq(3)
    end

    it "is idempotent" do
      described_class.perform_now(entity.id)
      described_class.perform_now(entity.id)

      entity.reload
      expect(entity.average_score).to eq(4.7)
    end

    context "when the entity no longer exists" do
      it "does not raise an error" do
        entity.destroy
        expect { described_class.perform_now(entity.id) }.not_to raise_error
      end
    end
  end

  describe "enqueue" do
    it "uses the correct queue" do
      expect(described_class.new.queue_name).to eq("default")
    end

    it "can be enqueued" do
      expect {
        described_class.perform_later(1)
      }.to have_enqueued_job(described_class)
        .with(1)
        .on_queue("default")
    end
  end
end
```

## Test with Retry

```ruby
# spec/jobs/send_notification_job_spec.rb
require "rails_helper"

RSpec.describe SendNotificationJob, type: :job do
  describe "#perform" do
    let(:user) { create(:user, notifications_enabled: true) }

    it "sends the notification" do
      expect(NotificationService).to receive(:send).with(
        user: user,
        type: "new_submission",
        data: { entity_id: 1 }
      )

      described_class.perform_now(user.id, "new_submission", { entity_id: 1 })
    end

    context "when notifications are disabled" do
      let(:user) { create(:user, notifications_enabled: false) }

      it "does nothing" do
        expect(NotificationService).not_to receive(:send)
        described_class.perform_now(user.id, "new_submission")
      end
    end

    context "when the service fails" do
      before do
        allow(NotificationService).to receive(:send).and_raise(StandardError, "API error")
      end

      it "retries the job" do
        expect {
          described_class.perform_now(user.id, "new_submission")
        }.to raise_error(StandardError)
      end
    end

    context "when the recipient is invalid" do
      before do
        allow(NotificationService).to receive(:send).and_raise(InvalidRecipientError)
      end

      it "discards the job without retry" do
        expect {
          described_class.perform_now(user.id, "new_submission")
        }.not_to raise_error
      end
    end
  end
end
```

## Test with Mailer Job

```ruby
# spec/jobs/send_weekly_digest_job_spec.rb
require "rails_helper"

RSpec.describe SendWeeklyDigestJob, type: :job do
  describe "#perform" do
    let!(:users_with_digest) { create_list(:user, 3, digest_enabled: true) }
    let!(:users_without_digest) { create_list(:user, 2, digest_enabled: false) }

    it "sends email to users with digest enabled" do
      expect {
        described_class.perform_now
      }.to change { ActionMailer::Base.deliveries.count }.by(3)
    end

    it "does not send to users without digest" do
      described_class.perform_now

      sent_to = ActionMailer::Base.deliveries.map(&:to).flatten
      expect(sent_to).to match_array(users_with_digest.map(&:email))
    end

    context "when sending fails" do
      before do
        allow(DigestMailer).to receive(:weekly).and_call_original
        allow(DigestMailer).to receive(:weekly)
          .with(users_with_digest.first)
          .and_raise(StandardError, "SMTP error")
      end

      it "continues with other users" do
        expect {
          described_class.perform_now
        }.to change { ActionMailer::Base.deliveries.count }.by(2)
      end
    end
  end
end
```

## Test for Recurring Job

```ruby
# spec/jobs/cleanup_old_data_job_spec.rb
require "rails_helper"

RSpec.describe CleanupOldDataJob, type: :job do
  describe "#perform" do
    let!(:old_notifications) do
      create_list(:notification, 5, :read, created_at: 100.days.ago)
    end
    let!(:recent_notifications) do
      create_list(:notification, 3, :read, created_at: 10.days.ago)
    end

    it "deletes old notifications" do
      expect {
        described_class.perform_now
      }.to change(Notification, :count).by(-5)
    end

    it "keeps recent notifications" do
      described_class.perform_now
      expect(Notification.all).to match_array(recent_notifications)
    end

    it "logs the results" do
      allow(Rails.logger).to receive(:info)
      described_class.perform_now
      expect(Rails.logger).to have_received(:info).at_least(:once)
    end
  end
end
```
