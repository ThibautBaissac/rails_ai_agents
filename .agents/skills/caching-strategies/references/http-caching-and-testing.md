# Caching Strategies: HTTP Caching and Testing

## HTTP Caching

### Conditional GET (ETag/Last-Modified)

```ruby
class EventsController < ApplicationController
  def show
    @event = Event.find(params[:id])

    # Returns 304 Not Modified if unchanged
    if stale?(@event)
      respond_to do |format|
        format.html
        format.json { render json: @event }
      end
    end
  end

  def index
    @events = current_account.events.recent

    # With custom ETag
    if stale?(etag: @events, last_modified: @events.maximum(:updated_at))
      render :index
    end
  end
end
```

### Cache-Control Headers

```ruby
class Api::EventsController < Api::BaseController
  def show
    @event = Event.find(params[:id])

    # Public caching (CDN can cache)
    expires_in 1.hour, public: true

    # Private caching (browser only)
    expires_in 15.minutes, private: true

    render json: @event
  end
end
```

## Testing Caching

### Spec Configuration

```ruby
# spec/rails_helper.rb
RSpec.configure do |config|
  config.around(:each, :caching) do |example|
    caching = ActionController::Base.perform_caching
    ActionController::Base.perform_caching = true
    Rails.cache.clear
    example.run
    ActionController::Base.perform_caching = caching
  end
end
```

### Testing Cached Views

```ruby
RSpec.describe "Events", type: :request, :caching do
  it "caches the event show page" do
    event = create(:event)

    # First request - cache miss
    get event_path(event)
    expect(response.body).to include(event.name)

    # Update event
    event.update!(name: "New Name")

    # Second request - should show new name (cache invalidated)
    get event_path(event)
    expect(response.body).to include("New Name")
  end
end
```

### Testing Cache Invalidation

```ruby
RSpec.describe DashboardStatsService do
  describe "#invalidate" do
    it "clears the cache" do
      account = create(:account)
      service = described_class.new

      # Prime cache
      service.call(account: account)

      # Invalidate
      service.invalidate(account: account)

      # Verify cache miss
      expect(Rails.cache.exist?("dashboard_stats/#{account.id}")).to be false
    end
  end
end
```

## Performance Monitoring

### Cache Hit/Miss Logging

```ruby
# config/environments/production.rb
config.action_controller.enable_fragment_cache_logging = true
```

### Custom Instrumentation

```ruby
# Subscribe to cache events
ActiveSupport::Notifications.subscribe("cache_read.active_support") do |*args|
  event = ActiveSupport::Notifications::Event.new(*args)
  Rails.logger.info "Cache #{event.payload[:hit] ? 'HIT' : 'MISS'}: #{event.payload[:key]}"
end
```
