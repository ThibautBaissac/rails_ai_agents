# Controller Templates

## Standard REST Controller

```ruby
class ResourcesController < ApplicationController
  # Authentication (Devise)
  before_action :authenticate_user!, except: [:index, :show]

  # Load resource
  before_action :set_resource, only: [:show, :edit, :update, :destroy]

  # GET /resources
  def index
    @resources = Resource.all
    authorize @resources

    # Optional: filtering, sorting, pagination
    @resources = @resources.where(status: params[:status]) if params[:status].present?
    @resources = @resources.order(created_at: :desc).page(params[:page])
  end

  # GET /resources/:id
  def show
    authorize @resource
  end

  # GET /resources/new
  def new
    @resource = Resource.new
    authorize @resource
  end

  # POST /resources
  def create
    authorize Resource

    result = Resources::CreateService.call(
      user: current_user,
      params: resource_params
    )

    if result.success?
      redirect_to result.data, notice: "Resource created successfully."
    else
      @resource = Resource.new(resource_params)
      @resource.errors.merge!(result.error)
      render :new, status: :unprocessable_entity
    end
  end

  # GET /resources/:id/edit
  def edit
    authorize @resource
  end

  # PATCH /resources/:id
  def update
    authorize @resource

    result = Resources::UpdateService.call(
      resource: @resource,
      params: resource_params
    )

    if result.success?
      redirect_to result.data, notice: "Resource updated successfully."
    else
      @resource.errors.merge!(result.error)
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /resources/:id
  def destroy
    authorize @resource

    @resource.destroy!
    redirect_to resources_path, notice: "Resource deleted successfully."
  end

  private

  def set_resource
    @resource = Resource.find(params[:id])
  end

  def resource_params
    params.require(:resource).permit(:name, :description, :status)
  end
end
```

## Controller with Service Objects

```ruby
class OrdersController < ApplicationController
  before_action :authenticate_user!
  before_action :set_order, only: [:show, :cancel]

  # POST /orders
  def create
    authorize Order

    result = Orders::CreateService.call(
      user: current_user,
      cart: current_cart,
      payment_params: payment_params
    )

    if result.success?
      redirect_to result.data, notice: "Order placed successfully!"
    else
      @order = Order.new
      @order.errors.add(:base, result.error)
      render :new, status: :unprocessable_entity
    end
  end

  # POST /orders/:id/cancel
  def cancel
    authorize @order, :cancel?

    result = Orders::CancelService.call(order: @order, reason: params[:reason])

    if result.success?
      redirect_to @order, notice: "Order cancelled."
    else
      redirect_to @order, alert: result.error, status: :unprocessable_entity
    end
  end

  private

  def set_order
    @order = current_user.orders.find(params[:id])
  end

  def payment_params
    params.require(:payment).permit(:method, :token)
  end
end
```

## Nested Resources Controller

```ruby
class ReviewsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_restaurant
  before_action :set_review, only: [:show, :edit, :update, :destroy]

  # GET /restaurants/:restaurant_id/reviews
  def index
    @reviews = @restaurant.reviews.published.recent
    authorize @reviews
  end

  # POST /restaurants/:restaurant_id/reviews
  def create
    authorize Review

    result = Reviews::CreateService.call(
      user: current_user,
      restaurant: @restaurant,
      params: review_params
    )

    if result.success?
      redirect_to restaurant_path(@restaurant), notice: "Review posted!"
    else
      @review = @restaurant.reviews.build(review_params)
      @review.errors.merge!(result.error)
      render :new, status: :unprocessable_entity
    end
  end

  private

  def set_restaurant
    @restaurant = Restaurant.find(params[:restaurant_id])
  end

  def set_review
    @review = @restaurant.reviews.find(params[:id])
  end

  def review_params
    params.require(:review).permit(:rating, :comment)
  end
end
```

## API Controller (JSON)

```ruby
class Api::V1::RestaurantsController < Api::V1::BaseController
  before_action :authenticate_api_user!
  before_action :set_restaurant, only: [:show, :update, :destroy]

  # GET /api/v1/restaurants
  def index
    @restaurants = Restaurant.all
    authorize @restaurants

    @restaurants = @restaurants.page(params[:page]).per(params[:per_page] || 20)

    render json: @restaurants, status: :ok
  end

  # GET /api/v1/restaurants/:id
  def show
    authorize @restaurant
    render json: @restaurant, status: :ok
  end

  # POST /api/v1/restaurants
  def create
    authorize Restaurant

    result = Restaurants::CreateService.call(
      user: current_api_user,
      params: restaurant_params
    )

    if result.success?
      render json: result.data, status: :created
    else
      render json: { errors: result.error }, status: :unprocessable_entity
    end
  end

  # PATCH /api/v1/restaurants/:id
  def update
    authorize @restaurant

    result = Restaurants::UpdateService.call(
      restaurant: @restaurant,
      params: restaurant_params
    )

    if result.success?
      render json: result.data, status: :ok
    else
      render json: { errors: result.error }, status: :unprocessable_entity
    end
  end

  # DELETE /api/v1/restaurants/:id
  def destroy
    authorize @restaurant

    @restaurant.destroy!
    head :no_content
  end

  private

  def set_restaurant
    @restaurant = Restaurant.find(params[:id])
  end

  def restaurant_params
    params.require(:restaurant).permit(:name, :description, :address, :phone)
  end
end
```

## Controller with Turbo Streams

```ruby
class CommentsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_post

  # POST /posts/:post_id/comments
  def create
    authorize Comment

    result = Comments::CreateService.call(
      user: current_user,
      post: @post,
      params: comment_params
    )

    respond_to do |format|
      if result.success?
        format.turbo_stream do
          render turbo_stream: turbo_stream.prepend(
            "comments",
            partial: "comments/comment",
            locals: { comment: result.data }
          )
        end
        format.html { redirect_to @post, notice: "Comment posted!" }
      else
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            "comment_form",
            partial: "comments/form",
            locals: { comment: Comment.new(comment_params).tap { |c| c.errors.merge!(result.error) } }
          )
        end
        format.html { render :new, status: :unprocessable_entity }
      end
    end
  end

  private

  def set_post
    @post = Post.find(params[:post_id])
  end

  def comment_params
    params.require(:comment).permit(:body)
  end
end
```

## Error Handling

### Handle Pundit Authorization Errors

```ruby
# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  include Pundit::Authorization

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  private

  def user_not_authorized
    flash[:alert] = "You are not authorized to perform this action."
    redirect_to(request.referrer || root_path)
  end
end
```

### Handle ActiveRecord Errors

```ruby
class RestaurantsController < ApplicationController
  rescue_from ActiveRecord::RecordNotFound, with: :record_not_found

  private

  def record_not_found
    redirect_to restaurants_path, alert: "Restaurant not found."
  end
end
```

## HTTP Status Codes Reference

```ruby
# Success responses
:ok                    # 200 - Standard success
:created               # 201 - Resource created
:no_content            # 204 - Success but no content to return

# Redirection
:found                 # 302 - Temporary redirect (default redirect)
:see_other             # 303 - After POST, redirect to GET

# Client errors
:bad_request           # 400 - Invalid request
:unauthorized          # 401 - Authentication required
:forbidden             # 403 - Authenticated but not authorized
:not_found             # 404 - Resource not found
:unprocessable_entity  # 422 - Validation errors

# Server errors
:internal_server_error # 500 - Server error
```
