# Service Object Patterns

## Basic Service Structure

```ruby
# app/services/[namespace]/[verb]_service.rb
module Namespace
  class VerbService
    def initialize(dependencies = {})
      @dependency = dependencies[:dependency] || DefaultDependency.new
    end

    def call(params)
      validate_input(params)
      perform_operation(params)
      success(result)
    rescue StandardError => e
      failure(e.message)
    end

    private

    attr_reader :dependency

    def success(data)
      Result.new(success: true, data: data)
    end

    def failure(error, code = :unknown)
      Result.new(success: false, error: error, code: code)
    end
  end
end
```

## Service Categories

### 1. Command Services (Write Operations)

Single action that changes state:

```ruby
# app/services/orders/create_service.rb
module Orders
  class CreateService
    def call(user:, items:)
      order = nil

      ActiveRecord::Base.transaction do
        order = user.orders.create!(status: :pending)
        create_line_items(order, items)
        reserve_inventory(items)
      end

      OrderMailer.confirmation(order).deliver_later
      success(order)
    rescue ActiveRecord::RecordInvalid => e
      failure(e.message, :validation_error)
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
    def call(account:, date_range:, format:)
      data = gather_data(account, date_range)
      formatted = format_data(data, format)
      success(formatted)
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

      success(charge)
    rescue PaymentGateway::CardDeclined => e
      failure(e.message, :card_declined)
    rescue PaymentGateway::Error => e
      failure(e.message, :payment_error)
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
    def call(user:, params:)
      results = []

      results << Accounts::SetupService.new.call(user: user, params: params[:account])
      return results.last if results.last.failure?

      results << Preferences::ConfigureService.new.call(user: user, params: params[:preferences])
      return results.last if results.last.failure?

      results << Notifications::WelcomeService.new.call(user: user)

      user.update!(onboarding_completed_at: Time.current)
      success(user)
    end
  end
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

### Typed Error Codes

```ruby
module Orders
  class CreateService
    ERROR_CODES = {
      empty_cart: "No items in cart",
      insufficient_inventory: "Item out of stock",
      payment_failed: "Payment could not be processed",
      validation_failed: "Invalid order data"
    }.freeze

    def call(params)
      return failure(:empty_cart) if params[:items].empty?
      return failure(:insufficient_inventory) unless inventory_available?(params[:items])

      order = create_order(params)
      success(order)
    rescue PaymentError
      failure(:payment_failed)
    rescue ActiveRecord::RecordInvalid => e
      failure(:validation_failed, e.message)
    end

    private

    def failure(code, details = nil)
      message = ERROR_CODES[code]
      message = "#{message}: #{details}" if details
      Result.new(success: false, error: message, code: code)
    end
  end
end
```

### Controller Error Handling

```ruby
class OrdersController < ApplicationController
  def create
    result = Orders::CreateService.new.call(order_params)

    if result.success?
      redirect_to result.data, notice: t(".success")
    else
      handle_service_error(result)
    end
  end

  private

  def handle_service_error(result)
    case result.code
    when :empty_cart
      redirect_to cart_path, alert: result.error
    when :insufficient_inventory
      flash.now[:alert] = result.error
      render :new, status: :unprocessable_entity
    when :payment_failed
      redirect_to checkout_path, alert: result.error
    else
      flash.now[:alert] = result.error
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
