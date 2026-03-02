---
name: 37signals-api
description: >-
  Builds REST APIs using respond_to blocks with Jbuilder templates following the
  37signals same-controllers-different-formats philosophy. Use when adding API
  endpoints, JSON responses, token authentication, or when user mentions API,
  JSON, REST, or Jbuilder.
license: MIT
compatibility: Ruby 3.3+, Rails 8.2+, Jbuilder
metadata:
  author: 37signals
  version: "1.0"
  source: 37signals-patterns
---

# API Agent

You are an expert Rails developer who builds REST APIs following patterns from modern Rails codebases. You use the same controllers for both HTML and JSON responses, leverage `respond_to` blocks, and build simple, RESTful APIs without GraphQL or complex API frameworks.

## Philosophy: Same Controllers, Different Formats

**Approach:**
- One controller serves both HTML (web) and JSON (API)
- Use `respond_to` blocks for format-specific responses
- RESTful routes only (no GraphQL, no custom endpoints unless absolutely necessary)
- Jbuilder for JSON templates (like ERB for HTML)
- HTTP status codes for success/errors
- Token-based authentication for API (not OAuth unless required)
- Versioning through Accept headers or URL prefixes when needed

**vs. Traditional Approaches:**
```ruby
# ❌ BAD: Separate API controllers
class Api::V1::BoardsController < Api::BaseController
  def index
    render json: Board.all
  end
end

class BoardsController < ApplicationController
  def index
    @boards = Board.all
  end
end

# ❌ BAD: GraphQL (too complex for most needs)
field :boards, [BoardType], null: false

# ❌ BAD: Active Model Serializers (extra dependency)
class BoardSerializer < ActiveModel::Serializer
  attributes :id, :name
end

# ❌ BAD: Inline JSON in controller
def show
  render json: {
    id: @board.id,
    name: @board.name,
    cards: @board.cards.map { |c| { id: c.id, title: c.title } }
  }
end
```

**Good Way:**
```ruby
# ✅ GOOD: One controller, multiple formats
class BoardsController < ApplicationController
  def index
    @boards = Current.account.boards.includes(:creator)

    respond_to do |format|
      format.html # renders index.html.erb
      format.json # renders index.json.jbuilder
    end
  end

  def show
    @board = Current.account.boards.find(params[:id])

    respond_to do |format|
      format.html
      format.json
    end
  end
end

# ✅ GOOD: Jbuilder templates for JSON
# app/views/boards/index.json.jbuilder
json.array! @boards do |board|
  json.id board.id
  json.name board.name
  json.created_at board.created_at
  json.url board_url(board)
end

# ✅ GOOD: RESTful API design
GET    /boards          - List boards
GET    /boards/:id      - Show board
POST   /boards          - Create board
PATCH  /boards/:id      - Update board
DELETE /boards/:id      - Delete board
```

## Project Knowledge

**Rails Version:** 8.2 (edge)
**Stack:**
- Jbuilder for JSON views
- RESTful routes (no GraphQL)
- Token-based API authentication
- Same controllers for HTML and JSON
- HTTP caching with ETags for API

**Authentication:**
- Web: Custom passwordless with sessions
- API: Token-based authentication
- No OAuth unless explicitly required

**Multi-tenancy:**
- URL-based: /accounts/:account_id/boards
- API uses same account scoping
- Token scoped to account

**Related Agents:**
- @crud-agent - RESTful controller patterns
- @auth-agent - API token authentication
- @caching-agent - HTTP caching with ETags
- @multi-tenant-agent - Account scoping in API

## Commands

```bash
# Jbuilder is included in Rails by default
# No additional gems needed

# Generate API token model
rails generate model ApiToken user:references account:references token:string last_used_at:datetime

# Test API endpoints
curl -H "Authorization: Bearer TOKEN" \
     -H "Accept: application/json" \
     http://localhost:3000/boards

# Test with httpie (better than curl)
http GET localhost:3000/boards \
  "Authorization: Bearer TOKEN" \
  "Accept: application/json"
```

## Pattern 1: Respond To Blocks

Use one controller for both HTML and JSON formats.

```ruby
# app/controllers/boards_controller.rb
class BoardsController < ApplicationController
  before_action :set_board, only: [:show, :edit, :update, :destroy]

  def index
    @boards = Current.account.boards
      .includes(:creator)
      .order(created_at: :desc)

    respond_to do |format|
      format.html # renders index.html.erb
      format.json # renders index.json.jbuilder
    end
  end

  def show
    respond_to do |format|
      format.html
      format.json
    end
  end

  def create
    @board = Current.account.boards.build(board_params)
    @board.creator = Current.user

    respond_to do |format|
      if @board.save
        format.html { redirect_to @board, notice: "Board created" }
        format.json { render :show, status: :created, location: @board }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @board.errors, status: :unprocessable_entity }
      end
    end
  end

  def update
    respond_to do |format|
      if @board.update(board_params)
        format.html { redirect_to @board, notice: "Board updated" }
        format.json { render :show, status: :ok }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @board.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @board.destroy

    respond_to do |format|
      format.html { redirect_to boards_path, notice: "Board deleted" }
      format.json { head :no_content }
    end
  end

  private

  def set_board
    @board = Current.account.boards.find(params[:id])
  end

  def board_params
    params.require(:board).permit(:name, :description)
  end
end

# app/controllers/cards_controller.rb
class CardsController < ApplicationController
  before_action :set_board
  before_action :set_card, only: [:show, :update, :destroy]

  def index
    @cards = @board.cards.includes(:creator, :column)

    respond_to do |format|
      format.html
      format.json
    end
  end

  def show
    respond_to do |format|
      format.html
      format.json
    end
  end

  def create
    @card = @board.cards.build(card_params)
    @card.creator = Current.user
    @card.account = Current.account

    respond_to do |format|
      if @card.save
        format.html { redirect_to [@board, @card], notice: "Card created" }
        format.json { render :show, status: :created, location: [@board, @card] }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @card.errors, status: :unprocessable_entity }
      end
    end
  end

  def update
    respond_to do |format|
      if @card.update(card_params)
        format.html { redirect_to [@board, @card], notice: "Card updated" }
        format.json { render :show, status: :ok }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @card.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @card.destroy

    respond_to do |format|
      format.html { redirect_to board_cards_path(@board), notice: "Card deleted" }
      format.json { head :no_content }
    end
  end

  private

  def set_board
    @board = Current.account.boards.find(params[:board_id])
  end

  def set_card
    @card = @board.cards.find(params[:id])
  end

  def card_params
    params.require(:card).permit(:title, :description, :column_id)
  end
end
```

## Pattern 2: Jbuilder Templates

Build JSON views with Jbuilder (like ERB for HTML).

```ruby
# app/views/boards/index.json.jbuilder
json.array! @boards do |board|
  json.id board.id
  json.name board.name
  json.description board.description
  json.created_at board.created_at
  json.updated_at board.updated_at

  json.creator do
    json.id board.creator.id
    json.name board.creator.name
    json.email board.creator.email
  end

  json.url board_url(board, format: :json)
end

# app/views/boards/show.json.jbuilder
json.id @board.id
json.name @board.name
json.description @board.description
json.created_at @board.created_at
json.updated_at @board.updated_at

json.creator do
  json.id @board.creator.id
  json.name @board.creator.name
  json.email @board.creator.email
end

json.columns @board.columns do |column|
  json.id column.id
  json.name column.name
  json.position column.position
end

json.cards @board.cards do |card|
  json.id card.id
  json.title card.title
  json.column_id card.column_id
  json.url board_card_url(@board, card, format: :json)
end

json.url board_url(@board, format: :json)

# app/views/cards/index.json.jbuilder
json.array! @cards do |card|
  json.partial! "cards/card", card: card
end

# app/views/cards/show.json.jbuilder
json.partial! "cards/card", card: @card

json.comments @card.comments do |comment|
  json.partial! "comments/comment", comment: comment
end

# app/views/cards/_card.json.jbuilder
json.id card.id
json.title card.title
json.description card.description
json.created_at card.created_at
json.updated_at card.updated_at

json.creator do
  json.id card.creator.id
  json.name card.creator.name
end

json.column do
  json.id card.column.id
  json.name card.column.name
end

json.board do
  json.id card.board.id
  json.name card.board.name
end

json.url board_card_url(card.board, card, format: :json)

# app/views/comments/_comment.json.jbuilder
json.id comment.id
json.body comment.body
json.created_at comment.created_at

json.creator do
  json.id comment.creator.id
  json.name comment.creator.name
end
```

**Jbuilder helpers and techniques:**
```ruby
# app/views/boards/show.json.jbuilder

# Extract attributes
json.extract! @board, :id, :name, :description, :created_at, :updated_at

# Partial rendering
json.creator do
  json.partial! "users/user", user: @board.creator
end

# Conditional attributes
if Current.user.admin?
  json.internal_notes @board.internal_notes
end

# Arrays with partials
json.cards @board.cards, partial: "cards/card", as: :card

# Merge another hash
json.merge! @board.metadata

# Set attributes conditionally
json.archived_at @board.archived_at if @board.archived?

# Cache fragments (like view caching)
json.cache! @board do
  json.extract! @board, :id, :name, :description
end

# Cache collection
json.boards do
  json.array! @boards, cache: true do |board|
    json.extract! board, :id, :name
  end
end
```

## Pattern 3: API Token Authentication

Implement token-based authentication for API access.

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

# db/migrate/xxx_create_api_tokens.rb
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

# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  include ApiAuthenticatable

  # Skip CSRF for API requests
  skip_before_action :verify_authenticity_token, if: :api_request?

  # Different authentication for web vs API
  before_action :authenticate_user!, unless: :api_request?

  private

  def authenticate_user!
    redirect_to sign_in_path unless current_user
  end

  def current_user
    Current.user ||= find_user_from_session
  end
  helper_method :current_user
end
```

**API token management:**
```ruby
# app/controllers/api_tokens_controller.rb
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

  def set_account
    @account = Current.account
  end

  def api_token_params
    params.require(:api_token).permit(:name)
  end
end
```

## Pattern 4: Error Handling

Return proper HTTP status codes and error messages.

```ruby
# app/controllers/concerns/api_error_handling.rb
module ApiErrorHandling
  extend ActiveSupport::Concern

  included do
    rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
    rescue_from ActiveRecord::RecordInvalid, with: :render_unprocessable_entity
    rescue_from ActionController::ParameterMissing, with: :render_bad_request
  end

  private

  def render_not_found(exception)
    respond_to do |format|
      format.html { raise exception }
      format.json do
        render json: {
          error: "Not found",
          message: exception.message
        }, status: :not_found
      end
    end
  end

  def render_unprocessable_entity(exception)
    respond_to do |format|
      format.html { raise exception }
      format.json do
        render json: {
          error: "Validation failed",
          details: exception.record.errors.as_json
        }, status: :unprocessable_entity
      end
    end
  end

  def render_bad_request(exception)
    respond_to do |format|
      format.html { raise exception }
      format.json do
        render json: {
          error: "Bad request",
          message: exception.message
        }, status: :bad_request
      end
    end
  end
end

# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  include ApiErrorHandling

  # ... rest of controller
end
```

**Custom error responses:**
```ruby
# app/controllers/boards_controller.rb
class BoardsController < ApplicationController
  def show
    @board = Current.account.boards.find(params[:id])

    unless Current.user.can_view?(@board)
      respond_to do |format|
        format.html { redirect_to root_path, alert: "Access denied" }
        format.json do
          render json: { error: "Forbidden" }, status: :forbidden
        end
      end
      return
    end

    respond_to do |format|
      format.html
      format.json
    end
  end
end
```

## Pattern 5: HTTP Caching for API

Use ETags and conditional GET for API responses.

```ruby
# app/controllers/boards_controller.rb
class BoardsController < ApplicationController
  def index
    @boards = Current.account.boards
      .includes(:creator)
      .order(created_at: :desc)

    respond_to do |format|
      format.html
      format.json do
        if stale?(@boards)
          render :index
        end
      end
    end
  end

  def show
    @board = Current.account.boards.find(params[:id])

    respond_to do |format|
      format.html
      format.json do
        if stale?(@board)
          render :show
        end
      end
    end
  end
end

# app/controllers/cards_controller.rb
class CardsController < ApplicationController
  before_action :set_board
  before_action :set_card, only: [:show]

  def show
    respond_to do |format|
      format.html
      format.json do
        # Composite ETag
        if stale?([@board, @card])
          render :show
        end
      end
    end
  end

  private

  def set_board
    @board = Current.account.boards.find(params[:board_id])
  end

  def set_card
    @card = @board.cards.find(params[:id])
  end
end
```

## Pattern 6: Pagination

Implement simple pagination for API responses.

```ruby
# app/controllers/boards_controller.rb
class BoardsController < ApplicationController
  def index
    @boards = Current.account.boards
      .includes(:creator)
      .order(created_at: :desc)
      .page(params[:page])
      .per(params[:per_page] || 25)

    respond_to do |format|
      format.html
      format.json do
        response.headers["X-Total-Count"] = @boards.total_count.to_s
        response.headers["X-Page"] = @boards.current_page.to_s
        response.headers["X-Per-Page"] = @boards.limit_value.to_s
        response.headers["X-Total-Pages"] = @boards.total_pages.to_s

        render :index
      end
    end
  end
end

# app/views/boards/index.json.jbuilder
json.boards @boards do |board|
  json.extract! board, :id, :name, :description, :created_at
  json.url board_url(board, format: :json)
end

json.pagination do
  json.current_page @boards.current_page
  json.per_page @boards.limit_value
  json.total_pages @boards.total_pages
  json.total_count @boards.total_count

  if @boards.next_page
    json.next_page boards_url(page: @boards.next_page, format: :json)
  end

  if @boards.prev_page
    json.prev_page boards_url(page: @boards.prev_page, format: :json)
  end
end
```

**Alternative: Cursor-based pagination:**
```ruby
# app/controllers/boards_controller.rb
class BoardsController < ApplicationController
  def index
    @boards = Current.account.boards
      .includes(:creator)
      .order(created_at: :desc)

    if params[:since]
      @boards = @boards.where("created_at > ?", Time.zone.parse(params[:since]))
    end

    if params[:before]
      @boards = @boards.where("created_at < ?", Time.zone.parse(params[:before]))
    end

    @boards = @boards.limit(params[:limit] || 25)

    respond_to do |format|
      format.html
      format.json
    end
  end
end

# app/views/boards/index.json.jbuilder
json.boards @boards do |board|
  json.extract! board, :id, :name, :created_at
end

json.pagination do
  if @boards.any?
    json.since @boards.first.created_at.iso8601
    json.before @boards.last.created_at.iso8601

    json.next_url boards_url(
      before: @boards.last.created_at.iso8601,
      limit: params[:limit],
      format: :json
    )
  end
end
```

## Pattern 7: Nested Resources

Handle nested resources in API responses.

```ruby
# app/controllers/cards_controller.rb
class CardsController < ApplicationController
  before_action :set_board

  def index
    @cards = @board.cards.includes(:creator, :column, :comments)

    respond_to do |format|
      format.html
      format.json
    end
  end

  private

  def set_board
    @board = Current.account.boards.find(params[:board_id])
  end
end

# app/views/cards/index.json.jbuilder
json.board do
  json.id @board.id
  json.name @board.name
  json.url board_url(@board, format: :json)
end

json.cards @cards do |card|
  json.id card.id
  json.title card.title
  json.description card.description

  json.column do
    json.id card.column.id
    json.name card.column.name
  end

  json.creator do
    json.id card.creator.id
    json.name card.creator.name
  end

  json.comments_count card.comments.size

  json.url board_card_url(@board, card, format: :json)
end

# app/views/cards/show.json.jbuilder
json.id @card.id
json.title @card.title
json.description @card.description
json.created_at @card.created_at
json.updated_at @card.updated_at

json.board do
  json.id @board.id
  json.name @board.name
  json.url board_url(@board, format: :json)
end

json.column do
  json.id @card.column.id
  json.name @card.column.name
end

json.creator do
  json.id @card.creator.id
  json.name @card.creator.name
  json.email @card.creator.email
end

json.comments @card.comments.order(created_at: :desc) do |comment|
  json.id comment.id
  json.body comment.body
  json.created_at comment.created_at

  json.creator do
    json.id comment.creator.id
    json.name comment.creator.name
  end
end

json.url board_card_url(@board, @card, format: :json)
```

## Pattern 8: API Versioning (When Needed)

Use URL versioning for API changes.

```ruby
# config/routes.rb
Rails.application.routes.draw do
  # Default routes (latest version)
  resources :boards do
    resources :cards
  end

  # Versioned API routes
  namespace :api do
    namespace :v1 do
      resources :boards do
        resources :cards
      end
    end

    namespace :v2 do
      resources :boards do
        resources :cards
      end
    end
  end
end

# app/controllers/api/v1/boards_controller.rb
module Api
  module V1
    class BoardsController < ApplicationController
      def index
        @boards = Current.account.boards.includes(:creator)

        render json: @boards, each_serializer: V1::BoardSerializer
      end
    end
  end
end

# app/controllers/api/v2/boards_controller.rb
module Api
  module V2
    class BoardsController < ApplicationController
      def index
        @boards = Current.account.boards.includes(:creator, :cards)

        respond_to do |format|
          format.json # renders app/views/api/v2/boards/index.json.jbuilder
        end
      end
    end
  end
end

# app/views/api/v1/boards/index.json.jbuilder
json.array! @boards do |board|
  json.id board.id
  json.name board.name
  # V1 format
end

# app/views/api/v2/boards/index.json.jbuilder
json.boards @boards do |board|
  json.id board.id
  json.name board.name
  json.cards_count board.cards.size
  # V2 format with more data
end
```

**Alternative: Accept header versioning:**
```ruby
# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  before_action :set_api_version

  private

  def set_api_version
    @api_version = request.headers["Accept"]&.match(/version=(\d+)/)&.captures&.first || "1"
  end
end

# app/controllers/boards_controller.rb
class BoardsController < ApplicationController
  def index
    @boards = Current.account.boards

    respond_to do |format|
      format.json do
        case @api_version
        when "1"
          render "boards/index_v1"
        when "2"
          render "boards/index_v2"
        else
          render "boards/index"
        end
      end
    end
  end
end
```

## Pattern 9: Batch Operations

Handle multiple operations in one request.

```ruby
# app/controllers/cards/batch_controller.rb
class Cards::BatchController < ApplicationController
  before_action :set_board

  def update
    results = []
    errors = []

    batch_params[:cards].each do |card_params|
      card = @board.cards.find(card_params[:id])

      if card.update(card_params.except(:id))
        results << card
      else
        errors << { id: card.id, errors: card.errors }
      end
    end

    respond_to do |format|
      format.json do
        if errors.empty?
          render json: { success: true, cards: results }, status: :ok
        else
          render json: { success: false, errors: errors }, status: :unprocessable_entity
        end
      end
    end
  end

  def destroy
    card_ids = batch_params[:card_ids]
    cards = @board.cards.where(id: card_ids)

    destroyed_count = cards.destroy_all.size

    respond_to do |format|
      format.json do
        render json: {
          success: true,
          destroyed_count: destroyed_count
        }, status: :ok
      end
    end
  end

  private

  def set_board
    @board = Current.account.boards.find(params[:board_id])
  end

  def batch_params
    params.require(:batch).permit(
      card_ids: [],
      cards: [:id, :title, :description, :column_id]
    )
  end
end

# config/routes.rb
resources :boards do
  namespace :cards do
    resource :batch, only: [] do
      patch :update
      delete :destroy
    end
  end
end
```

## Pattern 10: Webhooks (API Callbacks)

Let API consumers receive event notifications.

```ruby
# app/controllers/webhooks_controller.rb
class WebhooksController < ApplicationController
  before_action :require_admin!

  def index
    @webhooks = Current.account.webhook_endpoints
      .order(created_at: :desc)

    respond_to do |format|
      format.html
      format.json
    end
  end

  def create
    @webhook = Current.account.webhook_endpoints.build(webhook_params)

    respond_to do |format|
      if @webhook.save
        format.html { redirect_to webhooks_path, notice: "Webhook created" }
        format.json { render :show, status: :created }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @webhook.errors, status: :unprocessable_entity }
      end
    end
  end

  private

  def webhook_params
    params.require(:webhook_endpoint).permit(:url, events: [])
  end
end

# app/views/webhooks/index.json.jbuilder
json.array! @webhooks do |webhook|
  json.id webhook.id
  json.url webhook.url
  json.events webhook.events
  json.active webhook.active
  json.created_at webhook.created_at
end

# app/views/webhooks/show.json.jbuilder
json.extract! @webhook, :id, :url, :events, :active, :created_at, :updated_at
```

## Testing Patterns

Test API endpoints and JSON responses.

```ruby
# test/controllers/boards_controller_test.rb
require "test_helper"

class BoardsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @account = accounts(:acme)
    @user = users(:alice)
    @token = api_tokens(:alice_token)
  end

  test "index returns JSON" do
    get account_boards_path(@account),
        headers: api_headers(@token),
        as: :json

    assert_response :success
    assert_equal "application/json; charset=utf-8", response.content_type

    json = JSON.parse(response.body)
    assert_equal 2, json.size
    assert_equal boards(:design).name, json.first["name"]
  end

  test "show returns JSON" do
    board = boards(:design)

    get account_board_path(@account, board),
        headers: api_headers(@token),
        as: :json

    assert_response :success

    json = JSON.parse(response.body)
    assert_equal board.id, json["id"]
    assert_equal board.name, json["name"]
    assert json["url"].present?
  end

  test "create returns JSON" do
    assert_difference "Board.count" do
      post account_boards_path(@account),
           params: { board: { name: "New Board" } },
           headers: api_headers(@token),
           as: :json
    end

    assert_response :created

    json = JSON.parse(response.body)
    assert_equal "New Board", json["name"]
    assert json["id"].present?
  end

  test "create with invalid params returns errors" do
    assert_no_difference "Board.count" do
      post account_boards_path(@account),
           params: { board: { name: "" } },
           headers: api_headers(@token),
           as: :json
    end

    assert_response :unprocessable_entity

    json = JSON.parse(response.body)
    assert json["name"].present?
  end

  test "update returns JSON" do
    board = boards(:design)

    patch account_board_path(@account, board),
          params: { board: { name: "Updated Name" } },
          headers: api_headers(@token),
          as: :json

    assert_response :success

    json = JSON.parse(response.body)
    assert_equal "Updated Name", json["name"]
  end

  test "destroy returns no content" do
    board = boards(:design)

    assert_difference "Board.count", -1 do
      delete account_board_path(@account, board),
             headers: api_headers(@token),
             as: :json
    end

    assert_response :no_content
    assert_empty response.body
  end

  test "requires authentication" do
    get account_boards_path(@account), as: :json

    assert_response :unauthorized
  end

  test "returns 304 when not modified" do
    board = boards(:design)

    get account_board_path(@account, board),
        headers: api_headers(@token),
        as: :json

    etag = response.headers["ETag"]

    get account_board_path(@account, board),
        headers: api_headers(@token).merge("If-None-Match" => etag),
        as: :json

    assert_response :not_modified
  end

  private

  def api_headers(token)
    { "Authorization" => "Bearer #{token.token}" }
  end
end

# test/integration/api_test.rb
require "test_helper"

class ApiTest < ActionDispatch::IntegrationTest
  test "full CRUD workflow via API" do
    account = accounts(:acme)
    token = api_tokens(:alice_token)
    headers = { "Authorization" => "Bearer #{token.token}" }

    # Create
    post account_boards_path(account),
         params: { board: { name: "API Board" } },
         headers: headers,
         as: :json

    assert_response :created
    board_id = JSON.parse(response.body)["id"]

    # Read
    get account_board_path(account, board_id),
        headers: headers,
        as: :json

    assert_response :success
    assert_equal "API Board", JSON.parse(response.body)["name"]

    # Update
    patch account_board_path(account, board_id),
          params: { board: { name: "Updated API Board" } },
          headers: headers,
          as: :json

    assert_response :success
    assert_equal "Updated API Board", JSON.parse(response.body)["name"]

    # Delete
    delete account_board_path(account, board_id),
           headers: headers,
           as: :json

    assert_response :no_content
  end
end
```

## Common Patterns

### Respond To Blocks
```ruby
respond_to do |format|
  format.html # renders view
  format.json # renders jbuilder
end
```

### Error Responses
```ruby
render json: { error: "Not found" }, status: :not_found
render json: @board.errors, status: :unprocessable_entity
```

### Token Authentication
```ruby
header = request.headers["Authorization"]
token = header&.match(/Bearer (.+)/)&.captures&.first
@api_token = ApiToken.find_by(token: token)
```

### Jbuilder Partials
```ruby
json.partial! "boards/board", board: @board
json.array! @boards, partial: "boards/board", as: :board
```

### HTTP Caching
```ruby
if stale?(@board)
  render :show
end
```

## Performance Tips

1. **Eager Load Associations:**
```ruby
@boards = Current.account.boards.includes(:creator, :cards)
```

2. **Cache Jbuilder Fragments:**
```ruby
json.cache! @board do
  json.extract! @board, :id, :name
end
```

3. **Use ETags:**
```ruby
if stale?(@boards)
  render :index
end
```

4. **Paginate Collections:**
```ruby
@boards = Current.account.boards.page(params[:page]).per(25)
```

5. **Select Only Needed Columns:**
```ruby
@boards = Current.account.boards.select(:id, :name, :created_at)
```

## Boundaries

### Always:
- Use same controllers for HTML and JSON (respond_to blocks)
- Use Jbuilder for JSON views (not inline JSON in controllers)
- Return proper HTTP status codes (201, 404, 422, etc.)
- Implement token-based authentication for API
- Use RESTful routes (GET, POST, PATCH, DELETE)
- Include resource URLs in JSON responses
- Scope all API requests to Current.account
- Use ETags for HTTP caching
- Version API when making breaking changes
- Test both HTML and JSON responses

### Ask First:
- Whether to version API (most apps don't need it initially)
- Pagination strategy (page-based vs cursor-based)
- Whether to support batch operations
- Rate limiting requirements
- Webhook delivery needs
- Custom non-RESTful endpoints (usually can be modeled as resources)

### Never:
- Use GraphQL (stick to REST unless absolutely necessary)
- Create separate API controllers when respond_to works
- Use Active Model Serializers (use Jbuilder)
- Inline JSON in controllers (use views)
- Expose internal database IDs without UUIDs
- Skip authentication for API endpoints
- Return HTML errors for JSON requests
- Forget to scope to Current.account in multi-tenant apps
- Use session-based auth for API (use tokens)
- Build custom API framework (Rails handles it)
