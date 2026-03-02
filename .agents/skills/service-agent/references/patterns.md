# Service Object Patterns

## Pattern 1: Simple CRUD Service

```ruby
# app/services/submissions/create_service.rb
module Submissions
  class CreateService < ApplicationService
    def initialize(user:, entity:, params:)
      @user = user
      @entity = entity
      @params = params
    end

    def call
      return failure("You have already submitted") if already_submitted?

      submission = build_submission

      if submission.save
        update_entity_rating
        success(submission)
      else
        failure(submission.errors.full_messages.join(", "))
      end
    end

    private

    attr_reader :user, :entity, :params

    def already_submitted?
      entity.submissions.exists?(user: user)
    end

    def build_submission
      entity.submissions.build(params.merge(user: user))
    end

    def update_entity_rating
      Entities::CalculateRatingService.call(entity: entity)
    end
  end
end
```

## Pattern 2: Service with Transaction

```ruby
# app/services/orders/create_service.rb
module Orders
  class CreateService < ApplicationService
    def initialize(user:, cart:)
      @user = user
      @cart = cart
    end

    def call
      return failure("Cart is empty") if cart.empty?

      order = nil

      ActiveRecord::Base.transaction do
        order = create_order
        create_order_items(order)
        clear_cart
        charge_payment(order)
      end

      success(order)
    rescue ActiveRecord::RecordInvalid => e
      failure(e.message)
    rescue PaymentError => e
      failure("Payment error: #{e.message}")
    end

    private

    attr_reader :user, :cart

    def create_order
      user.orders.create!(total: cart.total, status: :pending)
    end

    def create_order_items(order)
      cart.items.each do |item|
        order.order_items.create!(
          product: item.product,
          quantity: item.quantity,
          price: item.price
        )
      end
    end

    def clear_cart
      cart.clear!
    end

    def charge_payment(order)
      PaymentGateway.charge(user: user, amount: order.total)
      order.update!(status: :paid)
    end
  end
end
```

## Pattern 3: Calculation/Query Service

```ruby
# app/services/entities/calculate_rating_service.rb
module Entities
  class CalculateRatingService < ApplicationService
    def initialize(entity:)
      @entity = entity
    end

    def call
      average = calculate_average_rating

      if entity.update(average_rating: average, submissions_count: submissions_count)
        success(average)
      else
        failure(entity.errors.full_messages.join(", "))
      end
    end

    private

    attr_reader :entity

    def calculate_average_rating
      return 0.0 if submissions_count.zero?

      entity.submissions.average(:rating).to_f.round(1)
    end

    def submissions_count
      @submissions_count ||= entity.submissions.count
    end
  end
end
```

## Pattern 4: Service with Injected Dependencies

```ruby
# app/services/notifications/send_service.rb
module Notifications
  class SendService < ApplicationService
    def initialize(user:, message:, notifier: default_notifier)
      @user = user
      @message = message
      @notifier = notifier
    end

    def call
      return failure("User has notifications disabled") unless user.notifications_enabled?

      notifier.deliver(user: user, message: message)
      success
    rescue NotificationError => e
      failure(e.message)
    end

    private

    attr_reader :user, :message, :notifier

    def default_notifier
      Rails.env.test? ? NullNotifier.new : PushNotifier.new
    end
  end
end
```
