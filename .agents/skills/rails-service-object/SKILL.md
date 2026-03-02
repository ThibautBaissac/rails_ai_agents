---
name: rails-service-object
description: >-
  Creates service objects following single-responsibility principle with
  comprehensive specs. Use when extracting business logic from controllers,
  creating complex operations, implementing interactors, or when user mentions
  service objects or POROs.
license: MIT
compatibility: Ruby 3.3+, Rails 8.1+, RSpec
metadata:
  author: ThibautBaissac
  version: "1.0"
---

# Rails Service Object Pattern

## Overview

Service objects encapsulate business logic:
- Single responsibility (one public method: `#call`)
- Easy to test in isolation
- Reusable across controllers, jobs, rake tasks
- Clear input/output contract
- Dependency injection for testability

## When to Use Service Objects

| Scenario | Use Service Object? |
|----------|---------------------|
| Complex business logic | Yes |
| Multiple model interactions | Yes |
| External API calls | Yes |
| Logic shared across controllers | Yes |
| Simple CRUD operations | No (use model) |
| Single model validation | No (use model) |

## Workflow Checklist

```
Service Object Progress:
- [ ] Step 1: Define input/output contract
- [ ] Step 2: Create service spec (RED)
- [ ] Step 3: Run spec (fails - no service)
- [ ] Step 4: Create service file with empty #call
- [ ] Step 5: Run spec (fails - wrong return)
- [ ] Step 6: Implement #call method
- [ ] Step 7: Run spec (GREEN)
- [ ] Step 8: Add error case specs
- [ ] Step 9: Implement error handling
- [ ] Step 10: Final spec run
```

## Step 1: Define Contract

```markdown
## Service: Orders::CreateService

### Purpose
Creates a new order with inventory validation and payment processing.

### Input
- user: User (required) - The user placing the order
- items: Array<Hash> (required) - Items to order [{product_id:, quantity:}]
- payment_method_id: Integer (optional) - Saved payment method

### Output (Result object)
Success:
- success?: true
- data: Order instance

Failure:
- success?: false
- error: String (error message)
- code: Symbol (error code for programmatic handling)

### Dependencies
- inventory_service: Checks product availability
- payment_gateway: Processes payment

### Side Effects
- Creates Order and OrderItem records
- Decrements inventory
- Charges payment method
- Sends confirmation email (async)
```

## Step 2: Service Spec

Location: `spec/services/orders/create_service_spec.rb`

```ruby
# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Orders::CreateService do
  subject(:service) { described_class.new(dependencies) }

  let(:dependencies) { {} }
  let(:user) { create(:user) }
  let(:product) { create(:product, inventory_count: 10) }
  let(:items) { [{ product_id: product.id, quantity: 2 }] }

  describe '#call' do
    subject(:result) { service.call(user: user, items: items) }

    context 'with valid inputs' do
      it 'returns success' do
        expect(result).to be_success
      end

      it 'creates an order' do
        expect { result }.to change(Order, :count).by(1)
      end

      it 'returns the order' do
        expect(result.data).to be_a(Order)
        expect(result.data.user).to eq(user)
      end
    end

    context 'with empty items' do
      let(:items) { [] }

      it 'returns failure' do
        expect(result).to be_failure
      end

      it 'returns error message' do
        expect(result.error).to eq('No items provided')
      end
    end

    context 'with insufficient inventory' do
      let(:items) { [{ product_id: product.id, quantity: 100 }] }

      it 'returns failure' do
        expect(result).to be_failure
      end

      it 'does not create order' do
        expect { result }.not_to change(Order, :count)
      end
    end
  end
end
```

## Step 3-6: Implement Service

Location: `app/services/orders/create_service.rb`

```ruby
# frozen_string_literal: true

module Orders
  class CreateService
    def initialize(inventory_service: InventoryService.new,
                   payment_gateway: PaymentGateway.new)
      @inventory_service = inventory_service
      @payment_gateway = payment_gateway
    end

    def call(user:, items:, payment_method_id: nil)
      return failure('No items provided', :empty_items) if items.empty?
      return failure('Insufficient inventory', :insufficient_inventory) unless inventory_available?(items)

      order = create_order(user, items)
      process_payment(order, payment_method_id) if payment_method_id

      success(order)
    rescue ActiveRecord::RecordInvalid => e
      failure(e.message, :validation_failed)
    rescue PaymentError => e
      failure(e.message, :payment_failed)
    end

    private

    attr_reader :inventory_service, :payment_gateway

    def inventory_available?(items)
      items.all? do |item|
        inventory_service.available?(item[:product_id], item[:quantity])
      end
    end

    def create_order(user, items)
      ActiveRecord::Base.transaction do
        order = Order.create!(user: user, status: :pending)

        items.each do |item|
          order.order_items.create!(
            product_id: item[:product_id],
            quantity: item[:quantity]
          )
          inventory_service.decrement(item[:product_id], item[:quantity])
        end

        order
      end
    end

    def process_payment(order, payment_method_id)
      payment_gateway.charge(
        amount: order.total,
        payment_method_id: payment_method_id
      )
      order.update!(status: :paid)
    end

    def success(data)
      Result.new(success: true, data: data)
    end

    def failure(error, code = :unknown)
      Result.new(success: false, error: error, code: code)
    end
  end
end
```

## Result Object

Use Ruby 3.2+ `Data.define` for immutable result objects:

```ruby
# app/services/result.rb
# frozen_string_literal: true

Result = Data.define(:success, :data, :error) do
  def success? = success
  def failure? = !success
end
```

## Calling Services

### From Controllers

```ruby
class OrdersController < ApplicationController
  def create
    result = Orders::CreateService.new.call(
      user: current_user,
      items: order_params[:items],
      payment_method_id: order_params[:payment_method_id]
    )

    if result.success?
      render json: result.data, status: :created
    else
      render json: { error: result.error }, status: :unprocessable_entity
    end
  end
end
```

### From Jobs

```ruby
class ProcessOrderJob < ApplicationJob
  def perform(user_id, items)
    user = User.find(user_id)
    result = Orders::CreateService.new.call(user: user, items: items)

    unless result.success?
      Rails.logger.error("Order failed: #{result.error}")
      # Handle failure (retry, notify, etc.)
    end
  end
end
```

## Testing with Mocked Dependencies

```ruby
RSpec.describe Orders::CreateService do
  let(:inventory_service) { instance_double(InventoryService) }
  let(:payment_gateway) { instance_double(PaymentGateway) }
  let(:service) { described_class.new(inventory_service: inventory_service, payment_gateway: payment_gateway) }

  before do
    allow(inventory_service).to receive(:available?).and_return(true)
    allow(inventory_service).to receive(:decrement)
    allow(payment_gateway).to receive(:charge)
  end

  # Tests...
end
```

## Directory Structure

```
app/services/
├── result.rb                    # Shared Result class
├── application_service.rb       # Optional base class
├── orders/
│   ├── create_service.rb
│   ├── cancel_service.rb
│   └── refund_service.rb
├── users/
│   ├── register_service.rb
│   └── update_profile_service.rb
└── payments/
    ├── charge_service.rb
    └── refund_service.rb
```

## Conventions

1. **Naming**: `VerbNounService` (e.g., `CreateOrderService`)
2. **Location**: `app/services/[namespace]/[name]_service.rb`
3. **Interface**: Single public method `#call`
4. **Return**: Always return Result object
5. **Dependencies**: Inject via constructor
6. **Errors**: Catch and wrap, don't raise

## Anti-Patterns to Avoid

1. **God service**: Too many responsibilities
2. **Hidden dependencies**: Using globals instead of injection
3. **No return contract**: Returning different types
4. **Raising exceptions**: Use Result objects instead
5. **Business logic in controller**: Extract to service
