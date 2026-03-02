# Service Object: RSpec Tests

## Test Structure for a Create Service

```ruby
# spec/services/entities/create_service_spec.rb
require "rails_helper"

RSpec.describe Entities::CreateService do
  describe ".call" do
    subject(:result) { described_class.call(user: user, params: params) }

    let(:user) { create(:user) }
    let(:params) { attributes_for(:entity) }

    context "with valid parameters" do
      it "creates an entity" do
        expect { result }.to change(Entity, :count).by(1)
      end

      it "returns success" do
        expect(result).to be_success
      end

      it "returns the created entity" do
        expect(result.data).to be_a(Entity)
        expect(result.data).to be_persisted
      end

      it "associates the entity with the user" do
        expect(result.data.user).to eq(user)
      end
    end

    context "with invalid parameters" do
      let(:params) { { name: "" } }

      it "does not create an entity" do
        expect { result }.not_to change(Entity, :count)
      end

      it "returns failure" do
        expect(result).to be_failure
      end

      it "returns an error message" do
        expect(result.error).to include("Name")
      end
    end

    context "without user" do
      let(:user) { nil }

      it "returns failure" do
        expect(result).to be_failure
      end

      it "returns authorization error" do
        expect(result.error).to eq("User not authorized")
      end
    end
  end
end
```

## Testing Side Effects

```ruby
# spec/services/submissions/create_service_spec.rb
RSpec.describe Submissions::CreateService do
  describe ".call" do
    subject(:result) { described_class.call(user: user, entity: entity, params: params) }

    let(:user) { create(:user) }
    let(:entity) { create(:entity) }
    let(:params) { { rating: 4, content: "Excellent!" } }

    it "updates the entity rating" do
      expect(Entities::CalculateRatingService)
        .to receive(:call)
        .with(entity: entity)

      result
    end

    context "when user has already submitted" do
      before { create(:submission, user: user, entity: entity) }

      it "returns failure" do
        expect(result).to be_failure
        expect(result.error).to eq("You have already submitted")
      end
    end
  end
end
```

## Testing Transactions

```ruby
# spec/services/orders/create_service_spec.rb
RSpec.describe Orders::CreateService do
  describe ".call" do
    subject(:result) { described_class.call(user: user, cart: cart) }

    let(:user) { create(:user) }
    let(:cart) { create(:cart, :with_items, user: user) }

    context "when payment fails" do
      before do
        allow(PaymentGateway).to receive(:charge).and_raise(PaymentError, "Card declined")
      end

      it "does not create order (rollback)" do
        expect { result }.not_to change(Order, :count)
      end

      it "does not clear cart (rollback)" do
        expect { result }.not_to change { cart.reload.items.count }
      end

      it "returns failure" do
        expect(result).to be_failure
        expect(result.error).to include("Card declined")
      end
    end
  end
end
```
