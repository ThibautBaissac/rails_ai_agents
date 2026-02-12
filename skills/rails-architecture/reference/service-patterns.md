# Service Object Patterns

> **Note**: This document covers Service Object patterns. For the formal **Command Pattern** (with undo/redo, command queues, and history), see the [`command-pattern` skill](../../command-pattern/SKILL.md).

## Basic Service Structure

```ruby
# app/services/[namespace]/[verb]_service.rb
module Namespace
  class VerbService
    include Dry::Monads[:result]

    def initialize(dependencies = {})
      @dependency = dependencies[:dependency] || DefaultDependency.new
    end

    def call(params)
      validate_input(params)
      result = perform_operation(params)
      Success(result)
    rescue StandardError => e
      Failure(e.message)
    end

    private

    attr_reader :dependency
  end
end
```

## Service Categories

### 1. Command Services (Write Operations)

> **Terminology**: "Command Services" here refers to services that perform **write operations** (create, update, delete). This is different from the formal [**Command Pattern**](../../command-pattern/SKILL.md) which encapsulates requests as objects with undo/redo capabilities.

Single action that changes state:

```ruby
# app/services/orders/create_service.rb
module Orders
  class CreateService
    include Dry::Monads[:result]

    def call(user:, items:)
      order = nil

      ActiveRecord::Base.transaction do
        order = user.orders.create!(status: :pending)
        create_line_items(order, items)
        reserve_inventory(items)
      end

      OrderMailer.confirmation(order).deliver_later
      Success(order)
    rescue ActiveRecord::RecordInvalid => e
      Failure(e.message)
    end
  end
end
```

### 2. Query Services (Read Operations)

Complex reads that don't fit in Query Objects:

```ruby
# app/services/reports/generate_service.rb
module Reports
  class GenerateService
    include Dry::Monads[:result]

    def call(account:, date_range:, format:)
      data = gather_data(account, date_range)
      formatted = format_data(data, format)
      Success(formatted)
    end

    private

    def gather_data(account, range)
      {
        events: EventStatsQuery.new(account: account).call(range),
        revenue: RevenueQuery.new(account: account).call(range),
        leads: LeadConversionQuery.new(account: account).call(range)
      }
    end
  end
end
```

### 3. Integration Services (External APIs)

Wrap external service calls:

```ruby
# app/services/payments/charge_service.rb
module Payments
  class ChargeService
    include Dry::Monads[:result]

    def initialize(gateway: StripeGateway.new)
      @gateway = gateway
    end

    def call(order:, payment_method_id:)
      charge = gateway.charge(
        amount: order.total_cents,
        currency: "eur",
        payment_method_id: payment_method_id
      )

      order.update!(
        payment_status: :paid,
        payment_reference: charge.id
      )

      Success(charge)
    rescue PaymentGateway::CardDeclined => e
      Failure(e.message)
    rescue PaymentGateway::Error => e
      Failure(e.message)
    end

    private

    attr_reader :gateway
  end
end
```

### 4. Orchestrator Services (Complex Workflows)

Coordinate multiple services:

```ruby
# app/services/onboarding/complete_service.rb
module Onboarding
  class CompleteService
    include Dry::Monads[:result]

    def call(user:, params:)
      Accounts::SetupService.new.call(user: user, params: params[:account])
        .bind { |_| Preferences::ConfigureService.new.call(user: user, params: params[:preferences]) }
        .bind { |_| Notifications::WelcomeService.new.call(user: user) }
        .bind { |_| complete_onboarding(user) }
    end

    private

    def complete_onboarding(user)
      user.update!(onboarding_completed_at: Time.current)
      Success(user)
    end
  end
end
```

**Alternative without `.bind` chaining:**

```ruby
def call(user:, params:)
  result = Accounts::SetupService.new.call(user: user, params: params[:account])
  return result if result.failure?

  result = Preferences::ConfigureService.new.call(user: user, params: params[:preferences])
  return result if result.failure?

  result = Notifications::WelcomeService.new.call(user: user)
  return result if result.failure?

  user.update!(onboarding_completed_at: Time.current)
  Success(user)
end
```

## Dependency Injection Patterns

### Constructor Injection (Preferred)

```ruby
class OrderService
  def initialize(
    inventory: InventoryService.new,
    payment: PaymentService.new,
    notifier: NotificationService.new
  )
    @inventory = inventory
    @payment = payment
    @notifier = notifier
  end
end
```

### Testing with Mocks

```ruby
RSpec.describe Orders::CreateService do
  let(:inventory) { instance_double(InventoryService, available?: true, reserve: true) }
  let(:payment) { instance_double(PaymentService, charge: true) }
  let(:service) { described_class.new(inventory: inventory, payment: payment) }

  it "checks inventory before charging" do
    service.call(user: user, items: items)
    expect(inventory).to have_received(:available?).ordered
    expect(payment).to have_received(:charge).ordered
  end
end
```

## Error Handling Patterns

### Simple Error Messages

```ruby
module Orders
  class CreateService
    include Dry::Monads[:result]

    def call(params)
      return Failure("No items in cart") if params[:items].empty?
      return Failure("Item out of stock") unless inventory_available?(params[:items])

      order = create_order(params)
      Success(order)
    rescue PaymentError => e
      Failure("Payment failed: #{e.message}")
    rescue ActiveRecord::RecordInvalid => e
      Failure("Invalid order: #{e.message}")
    end
  end
end
```

### Structured Errors (Hash)

```ruby
module Orders
  class CreateService
    include Dry::Monads[:result]

    def call(params)
      return Failure(code: :empty_cart, message: "No items in cart") if params[:items].empty?
      return Failure(code: :out_of_stock, message: "Item unavailable") unless inventory_available?(params[:items])

      order = create_order(params)
      Success(order)
    rescue PaymentError => e
      Failure(code: :payment_failed, message: e.message)
    end
  end
end
```

### Controller Error Handling

**Simple version:**

```ruby
class OrdersController < ApplicationController
  def create
    result = Orders::CreateService.new.call(order_params)

    if result.success?
      redirect_to result.value!, notice: "Order created"
    else
      flash.now[:alert] = result.failure
      render :new, status: :unprocessable_entity
    end
  end
end
```

**With structured errors:**

```ruby
def create
  result = Orders::CreateService.new.call(order_params)

  if result.success?
    redirect_to result.value!, notice: "Order created"
  else
    error = result.failure
    case error[:code]
    when :empty_cart
      redirect_to cart_path, alert: error[:message]
    when :out_of_stock
      flash.now[:alert] = error[:message]
      render :new, status: :unprocessable_entity
    else
      flash.now[:alert] = error[:message]
      render :new, status: :unprocessable_entity
    end
  end
end
```

## Service Naming Conventions

| Pattern | Example | Use Case |
|---------|---------|----------|
| `VerbNounService` | `CreateOrderService` | Single action |
| `Namespace::VerbService` | `Orders::CreateService` | Namespaced (preferred) |
| `NounVerbService` | `OrderCreatorService` | Alternative style |

## Checklist

- [ ] Single public method (`#call`)
- [ ] Returns Result object
- [ ] Dependencies injected via constructor
- [ ] Errors caught and wrapped
- [ ] Transaction for multi-model writes
- [ ] Typed error codes for handling
- [ ] Spec covers success and failure paths
