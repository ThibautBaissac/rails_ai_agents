# RED Phase Test Patterns by Component Type

## New Model

```ruby
# spec/models/membership_spec.rb
require 'rails_helper'

# This model doesn't exist yet - the test should fail with:
# "uninitialized constant Membership"

RSpec.describe Membership, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to belong_to(:tier) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:starts_at) }
    it { is_expected.to validate_presence_of(:status) }
  end

  describe '#active?' do
    context 'when status is active and not expired' do
      let(:membership) { build(:membership, status: 'active', ends_at: 1.month.from_now) }

      it 'returns true' do
        expect(membership.active?).to be true
      end
    end

    context 'when status is cancelled' do
      let(:membership) { build(:membership, status: 'cancelled') }

      it 'returns false' do
        expect(membership.active?).to be false
      end
    end
  end
end
```

## New Service

```ruby
# spec/services/transaction_processor_spec.rb
require 'rails_helper'

# This service doesn't exist yet - the test should fail with:
# "uninitialized constant TransactionProcessor"

RSpec.describe TransactionProcessor do
  describe '#process' do
    subject(:processor) { described_class.new(order) }

    let(:order) { create(:order, total: 100.00) }
    let(:payment_method) { create(:payment_method, :credit_card) }

    context 'with valid payment method' do
      it 'charges the payment method' do
        result = processor.process(payment_method)

        expect(result).to be_success
        expect(result.transaction_id).to be_present
      end

      it 'marks the order as paid' do
        processor.process(payment_method)

        expect(order.reload.status).to eq('paid')
      end
    end

    context 'with insufficient funds' do
      let(:payment_method) { create(:payment_method, :credit_card, :insufficient_funds) }

      it 'returns a failure result' do
        result = processor.process(payment_method)

        expect(result).to be_failure
        expect(result.error).to eq('Insufficient funds')
      end

      it 'does not change order status' do
        expect { processor.process(payment_method) }
          .not_to change { order.reload.status }
      end
    end
  end
end
```

## New Method on Existing Model

```ruby
# spec/models/user_spec.rb
require 'rails_helper'

RSpec.describe User, type: :model do
  # Existing tests...

  # NEW: This method doesn't exist yet
  describe '#membership_status' do
    context 'when user has active membership' do
      let(:user) { create(:user, :with_active_membership) }

      it 'returns :active' do
        expect(user.membership_status).to eq(:active)
      end
    end

    context 'when user has expired membership' do
      let(:user) { create(:user, :with_expired_membership) }

      it 'returns :expired' do
        expect(user.membership_status).to eq(:expired)
      end
    end

    context 'when user has no membership' do
      let(:user) { create(:user) }

      it 'returns :none' do
        expect(user.membership_status).to eq(:none)
      end
    end
  end
end
```

## New Controller/Request

```ruby
# spec/requests/api/memberships_spec.rb
require 'rails_helper'

# This route and controller don't exist yet

RSpec.describe 'API::Memberships', type: :request do
  let(:user) { create(:user) }
  let(:headers) { auth_headers_for(user) }

  describe 'POST /api/memberships' do
    let(:tier) { create(:tier, :premium) }
    let(:valid_params) do
      { membership: { tier_id: tier.id } }
    end

    context 'when user is authenticated' do
      it 'creates a new membership' do
        expect {
          post '/api/memberships', params: valid_params, headers: headers
        }.to change(Membership, :count).by(1)
      end

      it 'returns the created membership' do
        post '/api/memberships', params: valid_params, headers: headers

        expect(response).to have_http_status(:created)
        expect(json_response['tier_id']).to eq(tier.id)
      end
    end

    context 'when user already has an active membership' do
      before { create(:membership, :active, user: user) }

      it 'returns an error' do
        post '/api/memberships', params: valid_params, headers: headers

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response['error']).to include('already has an active membership')
      end
    end
  end
end
```

## New View Component

```ruby
# spec/components/tier_card_component_spec.rb
require 'rails_helper'

# This component doesn't exist yet

RSpec.describe TierCardComponent, type: :component do
  let(:tier) { create(:tier, name: 'Premium', price: 29.99) }

  describe 'rendering' do
    subject { render_inline(described_class.new(tier: tier)) }

    it 'displays the tier name' do
      expect(subject.text).to include('Premium')
    end

    it 'displays the formatted price' do
      expect(subject.text).to include('29.99')
    end

    it 'includes a subscribe button' do
      expect(subject.css('button[data-action="subscribe"]')).to be_present
    end

    context 'when tier has a discount' do
      let(:tier) { create(:tier, :with_discount, original_price: 39.99, price: 29.99) }

      it 'shows the original price crossed out' do
        expect(subject.css('.original-price.line-through')).to be_present
        expect(subject.text).to include('39.99')
      end

      it 'displays the discount badge' do
        expect(subject.css('.discount-badge')).to be_present
      end
    end
  end
end
```

## New Policy

```ruby
# spec/policies/membership_policy_spec.rb
require 'rails_helper'

# This policy doesn't exist yet

RSpec.describe MembershipPolicy do
  subject { described_class.new(user, membership) }

  let(:membership) { create(:membership, user: owner) }
  let(:owner) { create(:user) }

  context 'when user is the membership owner' do
    let(:user) { owner }

    it { is_expected.to permit_action(:show) }
    it { is_expected.to permit_action(:cancel) }
    it { is_expected.to forbid_action(:destroy) }
  end

  context 'when user is not the owner' do
    let(:user) { create(:user) }

    it { is_expected.to forbid_action(:show) }
    it { is_expected.to forbid_action(:cancel) }
    it { is_expected.to forbid_action(:destroy) }
  end

  context 'when user is an admin' do
    let(:user) { create(:user, :admin) }

    it { is_expected.to permit_action(:show) }
    it { is_expected.to permit_action(:cancel) }
    it { is_expected.to permit_action(:destroy) }
  end
end
```

## Factory for RED Tests

When writing a RED test, also create the necessary factory. The factory will also fail until the model is created.

```ruby
# spec/factories/memberships.rb
FactoryBot.define do
  factory :membership do
    user
    tier
    status { 'active' }
    starts_at { Time.current }
    ends_at { 1.month.from_now }

    trait :active do
      status { 'active' }
      ends_at { 1.month.from_now }
    end

    trait :expired do
      status { 'expired' }
      ends_at { 1.day.ago }
    end

    trait :cancelled do
      status { 'cancelled' }
      cancelled_at { Time.current }
    end
  end
end
```
