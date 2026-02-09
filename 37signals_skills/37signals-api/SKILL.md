---
name: 37signals-api
description: Build REST APIs with same controllers for HTML and JSON using respond_to blocks and Jbuilder. Triggers on api design, JSON API, REST endpoints, API authentication, token auth.
allowed-tools: Read, Write, Edit, Bash
---

# 37signals API Skill

## Overview

Build REST APIs following the 37signals philosophy: one controller serves both HTML and JSON responses. No separate API controllers, no GraphQL, no complex API frameworks.

## Core Philosophy

- **Same controllers, different formats**: Use `respond_to` blocks, not separate API namespaces
- **Jbuilder for JSON views**: Like ERB for HTML, Jbuilder templates for JSON
- **RESTful routes only**: No GraphQL, no custom endpoints unless absolutely necessary
- **Token-based auth**: Simple Bearer tokens, not OAuth (unless required)
- **HTTP caching**: Use ETags with `stale?` for API responses

## Key Patterns

### Pattern 1: Respond To Blocks

```ruby
class BoardsController < ApplicationController
  def index
    @boards = Current.account.boards.includes(:creator)

    respond_to do |format|
      format.html # renders index.html.erb
      format.json # renders index.json.jbuilder
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
end
```

### Pattern 2: Jbuilder Templates

```ruby
# app/views/boards/index.json.jbuilder
json.array! @boards do |board|
  json.id board.id
  json.name board.name
  json.created_at board.created_at
  json.url board_url(board, format: :json)

  json.creator do
    json.id board.creator.id
    json.name board.creator.name
  end
end

# Use partials for reuse
json.partial! "boards/board", board: @board
json.array! @boards, partial: "boards/board", as: :board
```

### Pattern 3: Token Authentication

```ruby
# app/models/api_token.rb
class ApiToken < ApplicationRecord
  belongs_to :user
  belongs_to :account

  has_secure_token :token, length: 32
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
    skip_before_action :verify_authenticity_token, if: :api_request?
  end

  private

  def api_request?
    request.format.json?
  end

  def authenticate_from_token
    token = request.headers["Authorization"]&.match(/Bearer (.+)/)&.captures&.first
    @api_token = ApiToken.active.find_by(token: token)

    if @api_token
      @api_token.use!
      Current.user = @api_token.user
      Current.account = @api_token.account
    else
      render json: { error: "Unauthorized" }, status: :unauthorized
    end
  end
end
```

### Pattern 4: HTTP Caching for API

```ruby
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

### Pattern 5: Error Handling

```ruby
module ApiErrorHandling
  extend ActiveSupport::Concern

  included do
    rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
    rescue_from ActiveRecord::RecordInvalid, with: :render_unprocessable_entity
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
      format.json { render json: { error: "Validation failed", details: exception.record.errors }, status: :unprocessable_entity }
    end
  end
end
```

### Pattern 6: Pagination

```ruby
def index
  @boards = Current.account.boards.page(params[:page]).per(25)

  respond_to do |format|
    format.json do
      response.headers["X-Total-Count"] = @boards.total_count.to_s
      response.headers["X-Page"] = @boards.current_page.to_s
      render :index
    end
  end
end

# In Jbuilder template
json.pagination do
  json.current_page @boards.current_page
  json.total_pages @boards.total_pages
  json.next_page boards_url(page: @boards.next_page, format: :json) if @boards.next_page
end
```

## Anti-Patterns to Avoid

```ruby
# ❌ Separate API controllers
class Api::V1::BoardsController < Api::BaseController

# ❌ GraphQL
field :boards, [BoardType], null: false

# ❌ Active Model Serializers
class BoardSerializer < ActiveModel::Serializer

# ❌ Inline JSON in controllers
render json: { id: @board.id, name: @board.name }
```

## Commands

```bash
# Generate API token model
rails generate model ApiToken user:references account:references token:string name:string

# Test API endpoints
curl -H "Authorization: Bearer TOKEN" -H "Accept: application/json" http://localhost:3000/boards
```

## Boundaries

### Always
- Use `respond_to` blocks for dual HTML/JSON controllers
- Use Jbuilder for JSON templates
- Return proper HTTP status codes
- Implement token auth for API
- Use ETags for caching
- Scope requests to Current.account

### Never
- Use GraphQL
- Create separate API controllers when respond_to works
- Use Active Model Serializers
- Inline JSON in controllers
- Skip authentication for API endpoints
