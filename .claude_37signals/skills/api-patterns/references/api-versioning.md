# API Versioning Reference

## When to Version

Most apps do not need API versioning initially. Version only when making
**breaking changes** to existing endpoints. Non-breaking changes (adding new
fields, new endpoints) do not require a new version.

## Strategy 1: URL Prefix (Preferred)

Use namespaced routes when versioning becomes necessary:

```ruby
# config/routes.rb
Rails.application.routes.draw do
  # Default routes (latest version, serves HTML + JSON)
  resources :boards do
    resources :cards
  end

  # Versioned API routes (JSON only)
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
```

### V1 Controller

```ruby
module Api
  module V1
    class BoardsController < ApplicationController
      def index
        @boards = Current.account.boards.includes(:creator)
        render :index  # renders app/views/api/v1/boards/index.json.jbuilder
      end
    end
  end
end

# app/views/api/v1/boards/index.json.jbuilder
json.array! @boards do |board|
  json.id board.id
  json.name board.name
  # V1 format: flat array
end
```

### V2 Controller

```ruby
module Api
  module V2
    class BoardsController < ApplicationController
      def index
        @boards = Current.account.boards.includes(:creator, :cards)
        render :index  # renders app/views/api/v2/boards/index.json.jbuilder
      end
    end
  end
end

# app/views/api/v2/boards/index.json.jbuilder
json.boards @boards do |board|
  json.id board.id
  json.name board.name
  json.cards_count board.cards.size
  # V2 format: wrapped object with more data
end
```

## Strategy 2: Accept Header Versioning

Version via the `Accept` header without changing URLs:

```ruby
# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  before_action :set_api_version

  private

  def set_api_version
    @api_version = request.headers["Accept"]
      &.match(/version=(\d+)/)&.captures&.first || "1"
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

Client usage:

```bash
# Request V1
curl -H "Accept: application/json; version=1" \
     -H "Authorization: Bearer TOKEN" \
     http://localhost:3000/boards

# Request V2
curl -H "Accept: application/json; version=2" \
     -H "Authorization: Bearer TOKEN" \
     http://localhost:3000/boards
```

## Deprecation

When deprecating an old API version:

1. Add deprecation headers to old version responses
2. Log usage of deprecated endpoints
3. Communicate timeline to API consumers
4. Remove after grace period

```ruby
module Api
  module V1
    class BoardsController < ApplicationController
      before_action :add_deprecation_headers

      private

      def add_deprecation_headers
        response.headers["Deprecation"] = "true"
        response.headers["Sunset"] = "2025-06-01"
        response.headers["Link"] = '<https://docs.example.com/api/v2>; rel="successor-version"'
      end
    end
  end
end
```

## Backwards Compatibility

When adding fields to existing versions, always add -- never remove or rename:

```ruby
# GOOD: Adding new field (backwards compatible)
# V1 originally had: id, name
# V1 now has: id, name, description (new field)
json.array! @boards do |board|
  json.id board.id
  json.name board.name
  json.description board.description  # New field, safe to add
end

# BAD: Renaming field (breaking change)
# json.title board.name  # Was "name", now "title" -- breaks clients
```

Rules for non-breaking changes:
- Adding new fields to responses
- Adding new endpoints
- Adding optional query parameters
- Making required parameters optional

Rules for breaking changes (require new version):
- Removing or renaming fields
- Changing field types
- Changing response structure (array to object)
- Removing endpoints
- Making optional parameters required
