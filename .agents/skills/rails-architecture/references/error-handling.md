# Error Handling Strategies

## Result Object Pattern (Preferred)

Services return Result objects instead of raising exceptions:

```ruby
# app/services/result.rb
class Result
  attr_reader :data, :error, :code

  def initialize(success:, data: nil, error: nil, code: nil)
    @success = success
    @data = data
    @error = error
    @code = code
  end

  def success? = @success
  def failure? = !@success

  # Pattern matching support (Ruby 3+)
  def deconstruct_keys(keys)
    { success: @success, data: @data, error: @error, code: @code }
  end
end
```

## Error Code System

### Define Error Codes

```ruby
module Orders
  class CreateService
    ERROR_CODES = {
      empty_cart: :empty_cart,
      out_of_stock: :out_of_stock,
      payment_declined: :payment_declined,
      invalid_coupon: :invalid_coupon,
      validation_failed: :validation_failed
    }.freeze

    MESSAGES = {
      empty_cart: "Your cart is empty",
      out_of_stock: "One or more items are out of stock",
      payment_declined: "Your payment was declined",
      invalid_coupon: "The coupon code is invalid",
      validation_failed: "Please check your order details"
    }.freeze
  end
end
```

### Return Typed Errors

```ruby
def call(params)
  return error(:empty_cart) if params[:items].empty?
  return error(:out_of_stock) unless inventory_available?(params[:items])

  order = create_order(params)
  success(order)
rescue PaymentGateway::Declined
  error(:payment_declined)
rescue ActiveRecord::RecordInvalid => e
  error(:validation_failed, e.message)
end

private

def error(code, details = nil)
  message = self.class::MESSAGES[code]
  message = "#{message}: #{details}" if details
  Result.new(success: false, error: message, code: code)
end
```

## Controller Error Handling

### Handle by Error Code

```ruby
class OrdersController < ApplicationController
  def create
    result = Orders::CreateService.new.call(order_params)

    if result.success?
      redirect_to result.data, notice: t(".success")
    else
      handle_error(result)
    end
  end

  private

  def handle_error(result)
    case result.code
    when :empty_cart
      redirect_to cart_path, alert: result.error
    when :out_of_stock
      flash.now[:alert] = result.error
      @out_of_stock = true
      render :new, status: :unprocessable_entity
    when :payment_declined
      redirect_to payment_path, alert: result.error
    else
      flash.now[:alert] = result.error
      render :new, status: :unprocessable_entity
    end
  end
end
```

### Pattern Matching (Ruby 3+)

```ruby
def create
  case Orders::CreateService.new.call(order_params)
  in { success: true, data: order }
    redirect_to order, notice: t(".success")
  in { code: :empty_cart }
    redirect_to cart_path, alert: t(".empty_cart")
  in { code: :payment_declined, error: message }
    redirect_to payment_path, alert: message
  in { error: message }
    flash.now[:alert] = message
    render :new, status: :unprocessable_entity
  end
end
```

## API Error Responses

### Consistent Error Format

```ruby
# app/controllers/api/base_controller.rb
module Api
  class BaseController < ApplicationController
    private

    def render_error(result, status: :unprocessable_entity)
      render json: {
        error: {
          code: result.code,
          message: result.error,
          details: result.data # Optional additional context
        }
      }, status: status
    end

    def render_success(data, status: :ok)
      render json: { data: data }, status: status
    end
  end
end
```

### HTTP Status Mapping

```ruby
ERROR_STATUS_MAP = {
  not_found: :not_found,
  unauthorized: :unauthorized,
  forbidden: :forbidden,
  validation_failed: :unprocessable_entity,
  conflict: :conflict,
  rate_limited: :too_many_requests
}.freeze

def render_service_result(result)
  if result.success?
    render_success(result.data)
  else
    status = ERROR_STATUS_MAP.fetch(result.code, :unprocessable_entity)
    render_error(result, status: status)
  end
end
```

## Exception Handling Layers

### Service Layer (Catch and Wrap)

```ruby
class ExternalApiService
  def call(params)
    response = client.request(params)
    success(response.data)
  rescue Faraday::TimeoutError
    error(:timeout, "External service timed out")
  rescue Faraday::ConnectionFailed
    error(:connection_failed, "Could not connect to service")
  rescue JSON::ParserError
    error(:invalid_response, "Invalid response from service")
  end
end
```

### Controller Layer (Rescue From)

```ruby
class ApplicationController < ActionController::Base
  rescue_from ActiveRecord::RecordNotFound, with: :not_found
  rescue_from Pundit::NotAuthorizedError, with: :forbidden

  private

  def not_found
    respond_to do |format|
      format.html { render "errors/not_found", status: :not_found }
      format.json { render json: { error: "Not found" }, status: :not_found }
    end
  end

  def forbidden
    respond_to do |format|
      format.html { redirect_to root_path, alert: t("errors.forbidden") }
      format.json { render json: { error: "Forbidden" }, status: :forbidden }
    end
  end
end
```

### Global Error Handler

```ruby
# config/initializers/error_handler.rb
Rails.application.config.exceptions_app = ->(env) {
  ErrorsController.action(:show).call(env)
}

# app/controllers/errors_controller.rb
class ErrorsController < ApplicationController
  skip_before_action :authenticate_user!

  def show
    @status = request.env["PATH_INFO"].delete("/").to_i
    render status: @status
  end
end
```

## Validation Errors

### Model Validations to Result

```ruby
def call(params)
  record = Model.new(params)

  if record.save
    success(record)
  else
    validation_error(record)
  end
end

def validation_error(record)
  Result.new(
    success: false,
    error: record.errors.full_messages.join(", "),
    code: :validation_failed,
    data: record.errors.to_hash
  )
end
```

### Display Validation Errors

```ruby
# In controller
if result.failure? && result.code == :validation_failed
  @errors = result.data # Hash of field => [messages]
end

# In view
<% if @errors&.dig(:email) %>
  <p class="text-red-500"><%= @errors[:email].join(", ") %></p>
<% end %>
```

## Logging Errors

```ruby
class ApplicationService
  private

  def error(code, message = nil, exception: nil)
    log_error(code, message, exception)
    Result.new(success: false, error: message || default_message(code), code: code)
  end

  def log_error(code, message, exception)
    Rails.logger.error({
      service: self.class.name,
      error_code: code,
      message: message,
      exception: exception&.class&.name,
      backtrace: exception&.backtrace&.first(5)
    }.to_json)
  end
end
```

## Error Tracking Integration

```ruby
# With Sentry/Rollbar
def error(code, message = nil, exception: nil)
  if exception && should_report?(code)
    Sentry.capture_exception(exception, extra: { code: code, message: message })
  end

  Result.new(success: false, error: message, code: code)
end

def should_report?(code)
  # Don't report expected errors
  ![:validation_failed, :not_found, :unauthorized].include?(code)
end
```

## Checklist

- [ ] Services return Result objects
- [ ] Error codes are typed symbols
- [ ] Controllers handle errors by code
- [ ] API responses have consistent format
- [ ] Unexpected errors logged with context
- [ ] Sensitive data not exposed in errors
- [ ] User-facing messages use I18n
