# HTTP Caching Reference

## ETags and Conditional GET

Rails automatically generates ETags from rendered content. Use `fresh_when` and
`stale?` to send 304 Not Modified when content has not changed.

### fresh_when (HTML controllers)

Returns 304 if the ETag matches the request's `If-None-Match` header. The
controller action still runs, but Rails skips rendering the view.

```ruby
# Single resource
def show
  @board = Current.account.boards.find(params[:id])
  fresh_when @board
end

# Collection
def index
  @boards = Current.account.boards.includes(:creator)
  fresh_when @boards
end

# Composite ETag from multiple objects
def show
  fresh_when [@board, @card, Current.user]
end

# Custom ETag with parameters
def activity
  @report_date = params[:date]&.to_date || Date.current
  @activities = Current.account.activities
    .where(created_at: @report_date.beginning_of_day..@report_date.end_of_day)

  fresh_when etag: [@activities, @report_date, Current.user.timezone]
end

# Composite ETag from multiple collections
def dashboard
  @boards = Current.account.boards.includes(:cards)
  @recent_activity = Current.account.activities.recent

  fresh_when etag: [
    @boards.maximum(:updated_at),
    @recent_activity.maximum(:updated_at),
    Current.user.preferences_updated_at
  ]
end
```

### stale? (API controllers)

Use `stale?` when you need to conditionally render -- it sets both ETag and
Last-Modified headers and returns `true` if the client needs a fresh response.

```ruby
# API: Set both ETag and Last-Modified
def show
  @board = Current.account.boards.find(params[:id])
  if stale?(@board)
    render json: @board
  end
end

# API: Custom cache key for collections
def index
  @boards = Current.account.boards.order(updated_at: :desc)
  if stale?(etag: @boards, last_modified: @boards.maximum(:updated_at))
    render json: @boards
  end
end

# Combined with respond_to
def show
  @board = Current.account.boards.find(params[:id])
  respond_to do |format|
    format.html { fresh_when @board }
    format.json do
      if stale?(@board)
        render :show
      end
    end
  end
end
```

### Cache Headers

Rails sets these headers automatically:

- **ETag**: Hash of the rendered content (weak ETag by default)
- **Last-Modified**: From `updated_at` of the record
- **Cache-Control**: `max-age=0, private, must-revalidate` (default)

Custom cache control:

```ruby
# Set public caching for CDN
expires_in 5.minutes, public: true

# Set private caching with custom max-age
expires_in 1.hour, private: true

# No caching at all
expires_now
```

### How ETags Work

1. First request: Rails renders response, computes ETag, sends it in response header
2. Second request: Browser sends `If-None-Match: "etag-value"` header
3. Rails computes new ETag, compares with request header
4. If match: returns 304 Not Modified (no body, saves bandwidth)
5. If different: returns 200 with full response

### Testing HTTP Caching

```ruby
test "returns 304 when board unchanged" do
  board = boards(:design)

  get board_url(board)
  assert_response :success
  etag = response.headers["ETag"]

  get board_url(board), headers: { "If-None-Match" => etag }
  assert_response :not_modified
end

test "returns 200 when board updated" do
  board = boards(:design)

  get board_url(board)
  etag = response.headers["ETag"]

  board.touch

  get board_url(board), headers: { "If-None-Match" => etag }
  assert_response :success
end

test "conditional GET with Last-Modified" do
  board = boards(:design)

  get board_url(board)
  last_modified = response.headers["Last-Modified"]

  board.update!(name: "New name")

  get board_url(board), headers: { "If-Modified-Since" => last_modified }
  assert_response :success
end
```
