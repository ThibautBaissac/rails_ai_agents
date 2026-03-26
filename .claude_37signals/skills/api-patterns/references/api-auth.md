# API Authentication Reference

## Token Model

```ruby
# app/models/api_token.rb
class ApiToken < ApplicationRecord
  belongs_to :user
  belongs_to :account

  has_secure_token :token, length: 32

  validates :name, presence: true
  validates :token, presence: true, uniqueness: true

  scope :active, -> { where(active: true) }

  before_create :set_token

  def use!
    touch(:last_used_at)
  end

  def deactivate!
    update!(active: false)
  end

  private

  def set_token
    self.token = SecureRandom.base58(32)
  end
end
```

## Migration

```ruby
class CreateApiTokens < ActiveRecord::Migration[8.0]
  def change
    create_table :api_tokens, id: :uuid do |t|
      t.references :user, null: false, type: :uuid
      t.references :account, null: false, type: :uuid
      t.string :token, null: false
      t.string :name, null: false
      t.datetime :last_used_at
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :api_tokens, :token, unique: true
    add_index :api_tokens, [:account_id, :active]
  end
end
```

## Authentication Concern

```ruby
# app/controllers/concerns/api_authenticatable.rb
module ApiAuthenticatable
  extend ActiveSupport::Concern

  included do
    before_action :authenticate_from_token, if: :api_request?
  end

  private

  def api_request?
    request.format.json?
  end

  def authenticate_from_token
    token = extract_token_from_header

    if token
      @api_token = ApiToken.active.find_by(token: token)

      if @api_token
        @api_token.use!
        Current.user = @api_token.user
        Current.account = @api_token.account
      else
        render_unauthorized
      end
    else
      render_unauthorized
    end
  end

  def extract_token_from_header
    header = request.headers["Authorization"]
    header&.match(/Bearer (.+)/)&.captures&.first
  end

  def render_unauthorized
    render json: { error: "Unauthorized" }, status: :unauthorized
  end
end
```

## Application Controller Setup

```ruby
class ApplicationController < ActionController::Base
  include ApiAuthenticatable

  # Skip CSRF for API requests
  skip_before_action :verify_authenticity_token, if: :api_request?

  # Different authentication for web vs API
  before_action :authenticate_user!, unless: :api_request?
end
```

## Token Management Controller

```ruby
class ApiTokensController < ApplicationController
  before_action :set_account

  def index
    @api_tokens = Current.account.api_tokens
      .where(user: Current.user)
      .order(created_at: :desc)
  end

  def create
    @api_token = Current.account.api_tokens.build(api_token_params)
    @api_token.user = Current.user

    if @api_token.save
      redirect_to account_api_tokens_path(@account),
                  notice: "Token created. Save it now: #{@api_token.token}"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    @api_token = Current.account.api_tokens
      .where(user: Current.user)
      .find(params[:id])

    @api_token.deactivate!

    redirect_to account_api_tokens_path(@account), notice: "Token deactivated"
  end

  private

  def api_token_params
    params.require(:api_token).permit(:name)
  end
end
```

## Rate Limiting (Optional)

Simple rate limiting using `Rails.cache`:

```ruby
module RateLimitable
  extend ActiveSupport::Concern

  private

  def rate_limit!(limit: 100, period: 1.hour)
    key = "rate_limit:#{@api_token.id}:#{Time.current.beginning_of_hour.to_i}"
    count = Rails.cache.increment(key, 1, expires_in: period)

    if count > limit
      response.headers["Retry-After"] = period.to_i.to_s
      render json: { error: "Rate limit exceeded" }, status: :too_many_requests
    end
  end
end
```

## Testing API Authentication

```ruby
test "index returns JSON with valid token" do
  get account_boards_path(@account),
      headers: { "Authorization" => "Bearer #{@token.token}" },
      as: :json

  assert_response :success
  assert_equal "application/json; charset=utf-8", response.content_type
end

test "requires authentication" do
  get account_boards_path(@account), as: :json
  assert_response :unauthorized
end

test "rejects invalid token" do
  get account_boards_path(@account),
      headers: { "Authorization" => "Bearer invalid" },
      as: :json

  assert_response :unauthorized
end

test "returns 304 when not modified" do
  get account_board_path(@account, @board),
      headers: { "Authorization" => "Bearer #{@token.token}" },
      as: :json

  etag = response.headers["ETag"]

  get account_board_path(@account, @board),
      headers: {
        "Authorization" => "Bearer #{@token.token}",
        "If-None-Match" => etag
      },
      as: :json

  assert_response :not_modified
end
```
