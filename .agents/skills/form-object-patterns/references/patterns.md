# Form Object Pattern Implementations

## Pattern 1: Multi-Model Registration Form

### Spec First (RED)

```ruby
# spec/forms/registration_form_spec.rb
require 'rails_helper'

RSpec.describe RegistrationForm do
  describe "validations" do
    it { is_expected.to validate_presence_of(:email) }
    it { is_expected.to validate_presence_of(:password) }
    it { is_expected.to validate_presence_of(:company_name) }
    it { is_expected.to validate_length_of(:password).is_at_least(8) }
  end

  describe "#save" do
    subject(:form) { described_class.new(params) }

    context "with valid params" do
      let(:params) do
        {
          email: "user@example.com",
          password: "password123",
          password_confirmation: "password123",
          company_name: "Acme Inc",
          phone: "0123456789"
        }
      end

      it "returns true" do
        expect(form.save).to be true
      end

      it "creates a user" do
        expect { form.save }.to change(User, :count).by(1)
      end

      it "creates an account" do
        expect { form.save }.to change(Account, :count).by(1)
      end

      it "associates user with account" do
        form.save
        expect(form.user.account).to eq(form.account)
      end

      it "exposes created records" do
        form.save
        expect(form.user).to be_persisted
        expect(form.account).to be_persisted
      end
    end

    context "with invalid params" do
      let(:params) { { email: "", password: "short" } }

      it "returns false" do
        expect(form.save).to be false
      end

      it "does not create records" do
        expect { form.save }.not_to change(User, :count)
      end

      it "has errors" do
        form.save
        expect(form.errors).not_to be_empty
      end
    end

    context "with duplicate email" do
      let!(:existing_user) { create(:user, email_address: "taken@example.com") }
      let(:params) do
        {
          email: "taken@example.com",
          password: "password123",
          password_confirmation: "password123",
          company_name: "Acme Inc"
        }
      end

      it "returns false" do
        expect(form.save).to be false
      end

      it "adds error to email" do
        form.save
        expect(form.errors[:email]).to include("has already been taken")
      end
    end
  end
end
```

### Implementation (GREEN)

```ruby
# app/forms/registration_form.rb
class RegistrationForm < ApplicationForm
  attribute :email, :string
  attribute :password, :string
  attribute :password_confirmation, :string
  attribute :company_name, :string
  attribute :phone, :string

  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, presence: true, length: { minimum: 8 }
  validates :password_confirmation, presence: true
  validates :company_name, presence: true
  validate :passwords_match
  validate :email_unique

  attr_reader :user, :account

  private

  def persist!
    ActiveRecord::Base.transaction do
      @account = Account.create!(name: company_name)
      @user = User.create!(
        email_address: email,
        password: password,
        account: @account,
        phone: phone
      )
    end
  end

  def passwords_match
    return if password == password_confirmation
    errors.add(:password_confirmation, "doesn't match password")
  end

  def email_unique
    return unless User.exists?(email_address: email&.downcase)
    errors.add(:email, "has already been taken")
  end
end
```

## Pattern 2: Search/Filter Form

### Spec First

```ruby
# spec/forms/event_search_form_spec.rb
require 'rails_helper'

RSpec.describe EventSearchForm do
  let(:account) { create(:account) }
  let(:form) { described_class.new(account: account, params: params) }

  describe "#results" do
    let!(:wedding) { create(:event, account: account, event_type: :wedding, name: "Smith Wedding") }
    let!(:corporate) { create(:event, account: account, event_type: :corporate, name: "Tech Conference") }
    let!(:other_event) { create(:event, name: "Other") }

    context "without filters" do
      let(:params) { {} }

      it "returns all account events" do
        expect(form.results).to contain_exactly(wedding, corporate)
      end

      it "excludes other account events" do
        expect(form.results).not_to include(other_event)
      end
    end

    context "with type filter" do
      let(:params) { { event_type: "wedding" } }

      it "filters by type" do
        expect(form.results).to contain_exactly(wedding)
      end
    end

    context "with search query" do
      let(:params) { { query: "smith" } }

      it "searches by name" do
        expect(form.results).to contain_exactly(wedding)
      end
    end

    context "with date range" do
      let(:params) { { start_date: Date.today, end_date: 1.month.from_now } }
      let!(:upcoming) { create(:event, account: account, event_date: 2.weeks.from_now) }
      let!(:past) { create(:event, account: account, event_date: 1.week.ago) }

      it "filters by date range" do
        expect(form.results).to include(upcoming)
        expect(form.results).not_to include(past)
      end
    end
  end

  describe "#any_filters?" do
    context "with filters" do
      let(:params) { { query: "test" } }

      it "returns true" do
        expect(form.any_filters?).to be true
      end
    end

    context "without filters" do
      let(:params) { {} }

      it "returns false" do
        expect(form.any_filters?).to be false
      end
    end
  end
end
```

### Implementation

```ruby
# app/forms/event_search_form.rb
class EventSearchForm < ApplicationForm
  attribute :query, :string
  attribute :event_type, :string
  attribute :status, :string
  attribute :start_date, :date
  attribute :end_date, :date

  attr_reader :account

  def initialize(account:, params: {})
    @account = account
    super(params)
  end

  def results
    scope = account.events

    scope = apply_search(scope)
    scope = apply_type_filter(scope)
    scope = apply_status_filter(scope)
    scope = apply_date_filter(scope)

    scope.order(event_date: :desc)
  end

  def any_filters?
    [query, event_type, status, start_date, end_date].any?(&:present?)
  end

  def event_type_options
    Event.event_types.keys.map { |t| [t.humanize, t] }
  end

  def status_options
    Event.statuses.keys.map { |s| [s.humanize, s] }
  end

  private

  def apply_search(scope)
    return scope if query.blank?
    scope.where("name ILIKE :q OR description ILIKE :q", q: "%#{sanitize_like(query)}%")
  end

  def apply_type_filter(scope)
    return scope if event_type.blank?
    scope.where(event_type: event_type)
  end

  def apply_status_filter(scope)
    return scope if status.blank?
    scope.where(status: status)
  end

  def apply_date_filter(scope)
    scope = scope.where("event_date >= ?", start_date) if start_date.present?
    scope = scope.where("event_date <= ?", end_date) if end_date.present?
    scope
  end

  def sanitize_like(term)
    term.gsub(/[%_]/) { |x| "\\#{x}" }
  end
end
```

## Pattern 3: Wizard/Multi-Step Form

### Base Wizard Form

```ruby
# app/forms/wizard/base_form.rb
module Wizard
  class BaseForm < ApplicationForm
    attribute :wizard_data, :string  # JSON storage

    def self.steps
      raise NotImplementedError
    end

    def current_step
      raise NotImplementedError
    end

    def next_step
      steps = self.class.steps
      current_index = steps.index(current_step)
      steps[current_index + 1]
    end

    def previous_step
      steps = self.class.steps
      current_index = steps.index(current_step)
      return nil if current_index.zero?
      steps[current_index - 1]
    end

    def first_step?
      current_step == self.class.steps.first
    end

    def last_step?
      current_step == self.class.steps.last
    end

    def progress_percentage
      steps = self.class.steps
      ((steps.index(current_step) + 1).to_f / steps.size * 100).round
    end
  end
end
```

### Step Forms

```ruby
# app/forms/wizard/event_step_one_form.rb
module Wizard
  class EventStepOneForm < BaseForm
    attribute :name, :string
    attribute :event_type, :string
    attribute :event_date, :date

    validates :name, presence: true
    validates :event_type, presence: true
    validates :event_date, presence: true

    def self.steps
      [:basics, :details, :vendors, :confirmation]
    end

    def current_step
      :basics
    end
  end
end

# app/forms/wizard/event_step_two_form.rb
module Wizard
  class EventStepTwoForm < BaseForm
    attribute :description, :string
    attribute :guest_count, :integer
    attribute :budget_cents, :integer

    validates :guest_count, numericality: { greater_than: 0 }, allow_nil: true

    def self.steps
      [:basics, :details, :vendors, :confirmation]
    end

    def current_step
      :details
    end
  end
end
```

## Pattern 4: Contact Form (No Persistence)

```ruby
# app/forms/contact_form.rb
class ContactForm < ApplicationForm
  attribute :name, :string
  attribute :email, :string
  attribute :subject, :string
  attribute :message, :string

  validates :name, presence: true
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :subject, presence: true
  validates :message, presence: true, length: { minimum: 10 }

  def save
    return false unless valid?
    deliver_email
    true
  end

  private

  def deliver_email
    ContactMailer.inquiry(
      name: name,
      email: email,
      subject: subject,
      message: message
    ).deliver_later
  end
end
```
