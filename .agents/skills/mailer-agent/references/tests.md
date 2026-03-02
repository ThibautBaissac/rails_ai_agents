# RSpec Tests for Mailers

## Complete Mailer Test

```ruby
# spec/mailers/entity_mailer_spec.rb
require "rails_helper"

RSpec.describe EntityMailer, type: :mailer do
  describe "#created" do
    let(:owner) { create(:user, email: "owner@example.com", first_name: "John") }
    let(:entity) { create(:entity, owner: owner, name: "Test Entity") }
    let(:mail) { described_class.created(entity) }

    it "sends email to the owner" do
      expect(mail.to).to eq([owner.email])
    end

    it "has the correct subject" do
      expect(mail.subject).to eq("Your entity Test Entity has been created")
    end

    it "comes from the default address" do
      expect(mail.from).to eq(["noreply@example.com"])
    end

    it "includes the owner's name in the body" do
      expect(mail.body.encoded).to include("John")
    end

    it "includes the entity name" do
      expect(mail.body.encoded).to include("Test Entity")
    end

    it "includes a link to the entity" do
      expect(mail.body.encoded).to include(entity_url(entity))
    end

    it "has an HTML version" do
      expect(mail.html_part.body.encoded).to include("<h2>")
    end

    it "has a text version" do
      expect(mail.text_part.body.encoded).to be_present
      expect(mail.text_part.body.encoded).not_to include("<")
    end
  end

  describe "#updated" do
    let(:entity) { create(:entity) }
    let(:mail) { described_class.updated(entity) }

    it "sends email to the owner" do
      expect(mail.to).to eq([entity.owner.email])
    end

    it "has the correct subject" do
      expect(mail.subject).to eq("Your entity has been updated")
    end
  end
end
```

## Test with Attachments

```ruby
# spec/mailers/report_mailer_spec.rb
require "rails_helper"

RSpec.describe ReportMailer, type: :mailer do
  describe "#monthly_report" do
    let(:user) { create(:user) }
    let(:month) { Date.new(2025, 1, 1) }
    let(:mail) { described_class.monthly_report(user, month) }

    it "has a PDF attachment" do
      expect(mail.attachments.count).to eq(1)
      expect(mail.attachments.first.filename).to eq("report_2025-01.pdf")
      expect(mail.attachments.first.content_type).to start_with("application/pdf")
    end

    it "includes statistics in the body" do
      expect(mail.body.encoded).to include("statistics")
    end
  end
end
```

## Test with Jobs

```ruby
# spec/mailers/submission_mailer_spec.rb
require "rails_helper"

RSpec.describe SubmissionMailer, type: :mailer do
  describe "#new_submission" do
    let(:submission) { create(:submission) }

    context "when called from a service" do
      it "enqueues the delivery job" do
        expect {
          described_class.new_submission(submission).deliver_later
        }.to have_enqueued_job(ActionMailer::MailDeliveryJob)
          .with("SubmissionMailer", "new_submission", "deliver_now", { args: [submission] })
      end
    end

    context "content test" do
      let(:mail) { described_class.new_submission(submission) }

      it "sends to the entity owner" do
        expect(mail.to).to include(submission.entity.owner.email)
      end

      it "has the author in reply-to" do
        expect(mail.reply_to).to eq([submission.author.email])
      end

      it "includes the submission content" do
        expect(mail.body.encoded).to include(submission.content)
      end
    end
  end
end
```
