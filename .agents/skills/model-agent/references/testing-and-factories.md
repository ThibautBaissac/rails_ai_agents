# Model Testing and FactoryBot Factories

## Complete Model Spec

```ruby
# spec/models/entity_spec.rb
require 'rails_helper'

RSpec.describe Entity, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to have_many(:submissions).dependent(:destroy) }
  end

  describe 'validations' do
    subject { build(:entity) }

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_length_of(:name).is_at_least(2).is_at_most(100) }
    it { is_expected.to validate_inclusion_of(:status).in_array(%w[draft published archived]) }
  end

  describe 'scopes' do
    describe '.published' do
      let!(:published_entity) { create(:entity, status: 'published') }
      let!(:draft_entity) { create(:entity, status: 'draft') }

      it 'returns only published entities' do
        expect(Entity.published).to include(published_entity)
        expect(Entity.published).not_to include(draft_entity)
      end
    end

    describe '.recent' do
      let!(:old_entity) { create(:entity, created_at: 2.days.ago) }
      let!(:new_entity) { create(:entity, created_at: 1.hour.ago) }

      it 'returns entities ordered by creation date descending' do
        expect(Entity.recent.first).to eq(new_entity)
        expect(Entity.recent.last).to eq(old_entity)
      end
    end
  end

  describe 'instance methods' do
    describe '#published?' do
      it 'returns true when status is published' do
        entity = build(:entity, status: 'published')
        expect(entity.published?).to be true
      end

      it 'returns false when status is not published' do
        entity = build(:entity, status: 'draft')
        expect(entity.published?).to be false
      end
    end
  end
end
```

## Testing Custom Validations

```ruby
RSpec.describe Booking, type: :model do
  describe 'validations' do
    describe 'end_date_after_start_date' do
      it 'is valid when end_date is after start_date' do
        booking = build(:booking, start_date: Date.today, end_date: Date.tomorrow)
        expect(booking).to be_valid
      end

      it 'is invalid when end_date is before start_date' do
        booking = build(:booking, start_date: Date.tomorrow, end_date: Date.today)
        expect(booking).not_to be_valid
        expect(booking.errors[:end_date]).to include("must be after start date")
      end

      it 'is invalid when end_date equals start_date' do
        booking = build(:booking, start_date: Date.today, end_date: Date.today)
        expect(booking).not_to be_valid
      end
    end

    describe 'no_overlapping_bookings' do
      let(:resource) { create(:resource) }
      let!(:existing_booking) do
        create(:booking, resource: resource, start_date: Date.today, end_date: Date.today + 3.days)
      end

      it 'is invalid when dates overlap' do
        overlapping = build(:booking, resource: resource, start_date: Date.today + 1.day, end_date: Date.today + 4.days)
        expect(overlapping).not_to be_valid
        expect(overlapping.errors[:base]).to include("dates overlap with existing booking")
      end

      it 'is valid when dates do not overlap' do
        non_overlapping = build(:booking, resource: resource, start_date: Date.today + 5.days, end_date: Date.today + 7.days)
        expect(non_overlapping).to be_valid
      end
    end
  end
end
```

## Testing Callbacks

```ruby
RSpec.describe User, type: :model do
  describe 'callbacks' do
    describe 'before_validation :normalize_email' do
      it 'downcases and strips email' do
        user = build(:user, email: '  TEST@EXAMPLE.COM  ')
        user.valid?
        expect(user.email).to eq('test@example.com')
      end
    end

    describe 'after_create :send_welcome_email' do
      it 'enqueues welcome email' do
        expect {
          create(:user)
        }.to have_enqueued_mail(UserMailer, :welcome)
      end
    end
  end
end
```

## Testing Enums

```ruby
RSpec.describe Order, type: :model do
  describe 'enums' do
    it { is_expected.to define_enum_for(:status).with_values(
      pending: 'pending',
      paid: 'paid',
      shipped: 'shipped',
      delivered: 'delivered',
      cancelled: 'cancelled'
    ).with_prefix(:status) }

    it 'allows setting status with enum methods' do
      order = create(:order)
      order.status_paid!
      expect(order.status_paid?).to be true
    end
  end
end
```

## FactoryBot Factories

### Basic Factory

```ruby
# spec/factories/entities.rb
FactoryBot.define do
  factory :entity do
    association :user

    name { Faker::Company.name }
    description { Faker::Lorem.paragraph }
    status { 'draft' }

    trait :published do
      status { 'published' }
      published_at { Time.current }
    end

    trait :archived do
      status { 'archived' }
    end

    trait :with_submissions do
      after(:create) do |entity|
        create_list(:submission, 3, entity: entity)
      end
    end
  end
end
```

### Factory with Nested Associations

```ruby
# spec/factories/posts.rb
FactoryBot.define do
  factory :post do
    association :author, factory: :user
    association :category

    title { Faker::Lorem.sentence }
    body { Faker::Lorem.paragraphs(number: 3).join("\n\n") }
    status { 'draft' }

    trait :published do
      status { 'published' }
      published_at { Time.current }
    end

    trait :with_comments do
      after(:create) do |post|
        create_list(:comment, 5, commentable: post)
      end
    end
  end
end
```
