---
name: api-patterns
description: >-
  Builds REST APIs using respond_to blocks with Jbuilder templates following
  the 37signals same-controllers-different-formats philosophy. Use when adding
  API endpoints, JSON responses, token authentication, pagination, or when
  user mentions API, JSON, REST, or Jbuilder.
  WHEN NOT: For HTML-only controllers (use crud-patterns), for webhook delivery
  (use event-tracking).
license: MIT
compatibility: Ruby 3.3+, Rails 8.0+, Jbuilder
---

# API Patterns

## Philosophy: Same Controllers, Different Formats

- One controller serves both HTML (web) and JSON (API)
- Use `respond_to` blocks for format-specific responses
- RESTful routes only (no GraphQL, no custom endpoints unless necessary)
- Jbuilder for JSON templates (like ERB for HTML)
- HTTP status codes for success/errors
- Token-based authentication for API (not OAuth unless required)

## Project Knowledge

**Stack:** Jbuilder for JSON views, RESTful routes, token-based API auth,
same controllers for HTML and JSON, HTTP caching with ETags for API.

**Multi-tenancy:** API uses same account scoping (`/accounts/:account_id/...`),
token scoped to account.

**Commands:**
```bash
# Generate API token model
rails generate model ApiToken user:references account:references \
  token:string last_used_at:datetime

# Test API endpoints
curl -H "Authorization: Bearer TOKEN" \
     -H "Accept: application/json" \
     http://localhost:3000/boards
```

## Pattern 1: Respond To Blocks

```ruby
class BoardsController < ApplicationController
  before_action :set_board, only: [:show, :edit, :update, :destroy]

  def index
    @boards = Current.account.boards.includes(:creator).order(created_at: :desc)

    respond_to do |format|
      format.html  # renders index.html.erb
      format.json  # renders index.json.jbuilder
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
```

## Pattern 2: Jbuilder Templates

See @references/jbuilder-templates.md for full details.

```ruby
# app/views/boards/index.json.jbuilder
json.array! @boards do |board|
  json.extract! board, :id, :name, :description, :created_at, :updated_at
  json.creator do
    json.extract! board.creator, :id, :name, :email
  end
  json.url board_url(board, format: :json)
end

# app/views/boards/show.json.jbuilder
json.extract! @board, :id, :name, :description, :created_at, :updated_at
json.creator do
  json.extract! @board.creator, :id, :name, :email
end
json.cards @board.cards, partial: "cards/card", as: :card
json.url board_url(@board, format: :json)

# app/views/cards/_card.json.jbuilder
json.extract! card, :id, :title, :description, :created_at, :updated_at
json.creator do
  json.extract! card.creator, :id, :name
end
json.url board_card_url(card.board, card, format: :json)
```

## Pattern 3: API Token Authentication

See @references/api-auth.md for full details.

```ruby
# app/models/api_token.rb
class ApiToken < ApplicationRecord
  belongs_to :user
  belongs_to :account

  has_secure_token :token, length: 32

  validates :name, presence: true
  validates :token, presence: true, uniqueness: true

  scope :active, -> { where(active: true) }

  def use!
    touch(:last_used_at)
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
    token = request.headers["Authorization"]
      &.match(/Bearer (.+)/)&.captures&.first

    if token
      @api_token = ApiToken.active.find_by(token: token)
      if @api_token
        @api_token.use!
        Current.user = @api_token.user
        Current.account = @api_token.account
      else
        render json: { error: "Unauthorized" }, status: :unauthorized
      end
    else
      render json: { error: "Unauthorized" }, status: :unauthorized
    end
  end
end

# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  include ApiAuthenticatable

  skip_before_action :verify_authenticity_token, if: :api_request?
  before_action :authenticate_user!, unless: :api_request?
end
```

## Pattern 4: Error Handling

```ruby
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
      format.json { render json: { error: "Not found" }, status: :not_found }
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
        render json: { error: "Bad request", message: exception.message },
               status: :bad_request
      end
    end
  end
end
```

## Pattern 5: HTTP Caching for API

```ruby
def index
  @boards = Current.account.boards.includes(:creator).order(created_at: :desc)

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
```

## Pattern 6: Pagination

See @references/api-versioning.md for versioning details.

```ruby
def index
  @boards = Current.account.boards.includes(:creator)
    .order(created_at: :desc)
    .page(params[:page])
    .per(params[:per_page] || 25)

  respond_to do |format|
    format.html
    format.json do
      response.headers["X-Total-Count"] = @boards.total_count.to_s
      response.headers["X-Page"] = @boards.current_page.to_s
      response.headers["X-Per-Page"] = @boards.limit_value.to_s
      render :index
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
  json.next_page boards_url(page: @boards.next_page, format: :json) if @boards.next_page
  json.prev_page boards_url(page: @boards.prev_page, format: :json) if @boards.prev_page
end
```

Cursor-based alternative:

```ruby
def index
  @boards = Current.account.boards.order(created_at: :desc)
  @boards = @boards.where("created_at < ?", Time.zone.parse(params[:before])) if params[:before]
  @boards = @boards.limit(params[:limit] || 25)

  respond_to do |format|
    format.html
    format.json
  end
end
```

## Pattern 7: Batch Operations

```ruby
class Cards::BatchController < ApplicationController
  before_action :set_board

  def update
    results, errors = [], []

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
end
```

## Boundaries

### Always
- Use same controllers for HTML and JSON (`respond_to` blocks)
- Use Jbuilder for JSON views (not inline JSON in controllers)
- Return proper HTTP status codes (201, 404, 422, etc.)
- Implement token-based authentication for API
- Include resource URLs in JSON responses
- Scope all API requests to `Current.account`
- Use ETags for HTTP caching
- Test both HTML and JSON responses

### Ask First
- Whether to version API (most apps don't need it initially)
- Pagination strategy (page-based vs cursor-based)
- Whether to support batch operations
- Rate limiting requirements

### Never
- Use GraphQL (stick to REST)
- Create separate API controllers when `respond_to` works
- Use Active Model Serializers (use Jbuilder)
- Inline JSON in controllers (use views)
- Skip authentication for API endpoints
- Return HTML errors for JSON requests
- Use session-based auth for API (use tokens)
