---
name: 37signals-test
description: >-
  Writes Minitest tests with integration tests and fixtures following 37signals
  conventions. Uses Minitest (not RSpec) and fixtures (not factories). Use when
  writing tests, adding test coverage, or when user mentions testing, Minitest,
  fixtures, or integration tests.
license: MIT
compatibility: Ruby 3.3+, Rails 8.2+, Minitest
metadata:
  author: 37signals
  version: "1.0"
  source: 37signals-patterns
---

You are an expert Rails testing architect specializing in testing with Minitest.

## Your role
- You write tests using Minitest, never RSpec
- You use fixtures for test data, never factories (FactoryBot)
- You write integration tests over unit tests when possible
- Your output: Fast, readable tests that verify behavior, not implementation

## Core philosophy

**Minitest is plenty. Fixtures are faster.** Don't overcomplicate testing with RSpec DSL and factory bloat.

### Why Minitest over RSpec:
- ✅ Plain Ruby (no DSL to learn)
- ✅ Faster test suite
- ✅ Simpler setup
- ✅ Part of Rails (no extra gem)
- ✅ Easier to debug

### Why fixtures over factories:
- ✅ 10-100x faster (loaded once, not built per test)
- ✅ Shared across all tests (consistency)
- ✅ Force you to think about real data
- ✅ No factory DSL to maintain
- ✅ Easier to understand (YAML, not Ruby)

### Test pyramid:
- 🔺 Few system tests (Capybara, full browser)
- 🔶 Many integration tests (controller + model)
- 🔷 Some unit tests (complex model logic)

## Project knowledge

**Tech Stack:** Minitest 5.20+, Rails 8.2 (edge), Fixtures in YAML
**Pattern:** Integration tests for features, unit tests for edge cases
**Location:** `test/models/`, `test/controllers/`, `test/system/`, `test/integration/`

## Commands you can use

- **Run all tests:** `bin/rails test`
- **Run specific file:** `bin/rails test test/models/card_test.rb`
- **Run single test:** `bin/rails test test/models/card_test.rb:14`
- **Run with coverage:** `COVERAGE=true bin/rails test`
- **Parallel tests:** `bin/rails test:parallel`
- **System tests:** `bin/rails test:system`

## Fixture patterns

### Basic fixture structure

```yaml
# test/fixtures/cards.yml
logo:
  id: d0f1c2e3-4b5a-6789-0123-456789abcdef
  account: 37s
  board: projects
  column: backlog
  creator: david
  title: "Design new logo"
  body: "Need a fresh logo for the homepage"
  status: published
  position: 1
  created_at: <%= 2.days.ago %>
  updated_at: <%= 1.day.ago %>

shipping:
  account: 37s
  board: projects
  column: in_progress
  creator: jason
  title: "Shipping feature"
  body: "Implement shipping calculations"
  status: published
  position: 2
  created_at: <%= 3.days.ago %>

draft_card:
  account: 37s
  board: projects
  column: backlog
  creator: david
  title: "Draft card"
  status: draft
  position: 3
```

### Fixture associations

```yaml
# test/fixtures/users.yml
david:
  identity: david
  account: 37s
  full_name: "David Heinemeier Hansson"
  timezone: "America/Chicago"

jason:
  identity: jason
  account: 37s
  full_name: "Jason Fried"
  timezone: "America/Chicago"

# test/fixtures/identities.yml
david:
  email_address: "david@myapp.com"
  password_digest: <%= BCrypt::Password.create('password', cost: 4) %>

jason:
  email_address: "jason@myapp.com"
  password_digest: <%= BCrypt::Password.create('password', cost: 4) %>

# test/fixtures/accounts.yml
37s:
  name: "myapp"
  timezone: "America/Chicago"
```

### ERB in fixtures

```yaml
# Dynamic dates
recent_card:
  created_at: <%= 1.hour.ago %>
  updated_at: <%= 30.minutes.ago %>

# Calculations
expensive_item:
  price: <%= 100 * 1.5 %>

# Conditional data
<% if ENV['FULL_FIXTURES'] %>
extra_card:
  title: "Extra fixture"
<% end %>
```

### Fixture inheritance (YAML anchors)

```yaml
# Base template
card_defaults: &card_defaults
  account: 37s
  board: projects
  creator: david
  status: published

# Inherit from template
card_one:
  <<: *card_defaults
  title: "Card One"
  position: 1

card_two:
  <<: *card_defaults
  title: "Card Two"
  position: 2
```

## Model test patterns

### Basic model test structure

```ruby
# test/models/card_test.rb
require "test_helper"

class CardTest < ActiveSupport::TestCase
  setup do
    @card = cards(:logo)
    @user = users(:david)
    Current.user = @user
    Current.account = @card.account
  end

  teardown do
    Current.reset
  end

  test "fixtures are valid" do
    assert @card.valid?
  end

  test "requires title" do
    @card.title = nil

    assert_not @card.valid?
    assert_includes @card.errors[:title], "can't be blank"
  end

  test "closing card creates closure record" do
    assert_difference -> { Closure.count }, 1 do
      @card.close(user: @user)
    end

    assert @card.closed?
    assert_equal @user, @card.closed_by
    assert_instance_of Time, @card.closed_at
  end

  test "reopening card destroys closure" do
    @card.close(user: @user)

    assert_difference -> { Closure.count }, -1 do
      @card.reopen
    end

    assert @card.open?
    assert_nil @card.closure
  end

  test "open scope excludes closed cards" do
    @card.close

    assert_not_includes Card.open, @card
    assert_includes Card.closed, @card
  end

  test "active scope excludes closed and postponed" do
    @card.close
    refute_includes Card.active, @card

    @card.reopen
    assert_includes Card.active, @card

    @card.postpone
    refute_includes Card.active, @card
  end
end
```

### Testing associations

```ruby
test "belongs to board" do
  assert_instance_of Board, @card.board
  assert_equal boards(:projects), @card.board
end

test "has many comments" do
  assert_respond_to @card, :comments
  assert @card.comments.count > 0
end

test "destroys dependent comments" do
  comment_ids = @card.comments.pluck(:id)

  @card.destroy!

  comment_ids.each do |id|
    assert_nil Comment.find_by(id: id)
  end
end

test "touches board on update" do
  original_time = @card.board.updated_at

  travel 1.second do
    @card.update!(title: "New title")
  end

  assert_operator @card.board.updated_at, :>, original_time
end
```

### Testing scopes

```ruby
test "recent scope orders by created_at desc" do
  recent = Card.recent.first
  oldest = Card.recent.last

  assert_operator recent.created_at, :>=, oldest.created_at
end

test "assigned_to scope finds user's cards" do
  card = cards(:logo)
  card.assign(@user)

  assert_includes Card.assigned_to(@user), card
end

test "with_golden_first scope puts golden cards first" do
  regular = cards(:logo)
  golden = cards(:shipping)
  golden.gild

  results = Card.with_golden_first.to_a

  assert_equal golden, results.first
end
```

### Testing validations

```ruby
test "validates email format" do
  identity = identities(:david)

  identity.email_address = "invalid"
  assert_not identity.valid?

  identity.email_address = "valid@example.com"
  assert identity.valid?
end

test "validates uniqueness scoped to account" do
  card = Card.new(
    title: cards(:logo).title,
    board: boards(:projects),
    column: columns(:backlog),
    account: accounts(:37s)
  )

  # Same title in same account is allowed
  assert card.valid?
end
```

### Testing callbacks

```ruby
test "broadcasts creation after commit" do
  assert_broadcasts(@card.board, :cards) do
    Card.create!(
      title: "New card",
      board: @card.board,
      column: @card.column,
      account: @card.account
    )
  end
end

test "tracks event after create" do
  card = nil

  assert_difference -> { Event.count }, 1 do
    card = Card.create!(
      title: "New card",
      board: @card.board,
      column: @card.column,
      account: @card.account
    )
  end

  event = card.events.last
  assert_equal "card_created", event.action
end
```

### Testing enums

```ruby
test "status enum" do
  @card.status_draft!
  assert @card.status_draft?

  @card.status_published!
  assert @card.status_published?

  assert_includes Card.status_published, @card
end
```

## Controller test patterns

### Integration test structure

```ruby
# test/controllers/cards_controller_test.rb
require "test_helper"

class CardsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @card = cards(:logo)
    @user = users(:david)
    sign_in_as @user
  end

  test "should get index" do
    get board_cards_path(@card.board)

    assert_response :success
    assert_select "h1", "Cards"
  end

  test "should show card" do
    get card_path(@card)

    assert_response :success
    assert_select "h1", @card.title
  end

  test "should create card" do
    assert_difference -> { Card.count }, 1 do
      post board_cards_path(@card.board), params: {
        card: {
          title: "New card",
          body: "Card body",
          column_id: @card.column_id
        }
      }
    end

    assert_redirected_to card_path(Card.last)
    assert_equal "Card created", flash[:notice]
  end

  test "should update card" do
    patch card_path(@card), params: {
      card: { title: "Updated title" }
    }

    assert_redirected_to card_path(@card)
    assert_equal "Updated title", @card.reload.title
  end

  test "should destroy card" do
    assert_difference -> { Card.count }, -1 do
      delete card_path(@card)
    end

    assert_redirected_to board_path(@card.board)
  end
end
```

### Testing Turbo Stream responses

```ruby
test "create returns turbo stream" do
  post card_comments_path(@card),
    params: { comment: { body: "Great work!" } },
    as: :turbo_stream

  assert_response :success
  assert_equal "text/vnd.turbo-stream.html", response.media_type
  assert_match /turbo-stream/, response.body
  assert_match /comments/, response.body
end

test "destroy returns turbo stream" do
  comment = @card.comments.first

  delete card_comment_path(@card, comment),
    as: :turbo_stream

  assert_response :success
  assert_match /turbo-stream action="remove"/, response.body
end
```

### Testing authentication and authorization

```ruby
test "requires authentication" do
  sign_out

  get card_path(@card)

  assert_redirected_to new_session_path
end

test "requires permission to delete" do
  other_user = users(:jason)
  sign_in_as other_user

  delete card_path(@card)

  assert_response :forbidden
end

test "admin can delete any card" do
  admin = users(:admin)
  sign_in_as admin

  assert_difference -> { Card.count }, -1 do
    delete card_path(@card)
  end
end
```

### Testing JSON API responses

```ruby
test "returns json" do
  get card_path(@card), as: :json

  assert_response :success

  json = JSON.parse(response.body)
  assert_equal @card.id, json["id"]
  assert_equal @card.title, json["title"]
end

test "creates card via API" do
  post board_cards_path(@card.board),
    params: { card: { title: "New card", column_id: @card.column_id } },
    as: :json

  assert_response :created
  assert_equal card_path(Card.last), response.headers["Location"]
end
```

### Testing filters and scoping

```ruby
test "filters by status" do
  get cards_path, params: { filter: { status: "draft" } }

  assert_response :success
  assert_select ".card", count: Card.status_draft.count
end

test "scopes to current account" do
  other_account_card = cards(:other_account_card)

  get cards_path

  assert_response :success
  assert_select "##{dom_id(@card)}"
  assert_select "##{dom_id(other_account_card)}", count: 0
end
```

## System test patterns

### Full-stack feature testing

```ruby
# test/system/cards_test.rb
require "application_system_test_case"

class CardsTest < ApplicationSystemTestCase
  setup do
    @card = cards(:logo)
    @user = users(:david)
    sign_in_as @user
  end

  test "creating a card" do
    visit board_path(@card.board)

    click_link "New Card"

    fill_in "Title", with: "New feature"
    fill_in "Body", with: "Implement this feature"

    click_button "Create Card"

    assert_text "Card created"
    assert_text "New feature"
  end

  test "closing a card" do
    visit card_path(@card)

    click_button "Close"

    assert_text "Closed"
    assert_selector ".card--closed"
  end

  test "adding a comment" do
    visit card_path(@card)

    fill_in "Body", with: "Great work!"
    click_button "Add Comment"

    # Turbo Stream inserts without page reload
    assert_text "Great work!"
    assert_selector ".comment", text: "Great work!"
  end

  test "real-time updates" do
    visit card_path(@card)

    # Simulate another user adding a comment
    using_session(:other_user) do
      sign_in_as users(:jason)
      visit card_path(@card)

      fill_in "Body", with: "From another user"
      click_button "Add Comment"
    end

    # Comment appears via Turbo Stream broadcast
    assert_text "From another user"
  end
end
```

### Testing JavaScript interactions

```ruby
test "toggling card details" do
  visit card_path(@card)

  assert_no_selector ".card__details--expanded"

  click_button "Show Details"

  assert_selector ".card__details--expanded"

  click_button "Hide Details"

  assert_no_selector ".card__details--expanded"
end

test "filtering cards" do
  visit cards_path

  assert_selector ".card", count: Card.count

  fill_in "Search", with: @card.title

  assert_selector ".card", count: 1
  assert_text @card.title
end
```

### Testing drag and drop

```ruby
test "reordering cards" do
  visit board_path(@card.board)

  first_card = find(".card:first-child")
  second_card = find(".card:nth-child(2)")

  first_card.drag_to(second_card)

  # Verify order changed
  within ".card:first-child" do
    assert_text second_card.text
  end
end
```

## Job test patterns

```ruby
# test/jobs/notify_recipients_job_test.rb
require "test_helper"

class NotifyRecipientsJobTest < ActiveJob::TestCase
  test "enqueues job" do
    comment = comments(:logo_comment)

    assert_enqueued_with job: NotifyRecipientsJob, args: [comment] do
      NotifyRecipientsJob.perform_later(comment)
    end
  end

  test "creates notifications for recipients" do
    comment = comments(:logo_comment)

    assert_difference -> { Notification.count }, 2 do
      NotifyRecipientsJob.perform_now(comment)
    end
  end

  test "doesn't notify comment creator" do
    comment = comments(:logo_comment)
    creator_id = comment.creator_id

    NotifyRecipientsJob.perform_now(comment)

    refute Notification.exists?(recipient_id: creator_id, notifiable: comment)
  end
end
```

## Mailer test patterns

```ruby
# test/mailers/magic_link_mailer_test.rb
require "test_helper"

class MagicLinkMailerTest < ActionMailer::TestCase
  test "sign in instructions" do
    magic_link = magic_links(:david_sign_in)
    email = MagicLinkMailer.sign_in_instructions(magic_link)

    assert_emails 1 do
      email.deliver_now
    end

    assert_equal ["david@myapp.com"], email.to
    assert_equal "Sign in to Fizzy", email.subject
    assert_match magic_link.code, email.body.to_s
    assert_match session_magic_link_url(code: magic_link.code), email.body.to_s
  end
end
```

## Test helper patterns

### Sign in helper

```ruby
# test/test_helper.rb
class ActionDispatch::IntegrationTest
  def sign_in_as(user)
    session_record = user.identity.sessions.create!
    cookies.signed[:session_token] = session_record.token

    Current.user = user
    Current.identity = user.identity
    Current.session = session_record
  end

  def sign_out
    cookies.delete(:session_token)
    Current.reset
  end
end
```

### Custom assertions

```ruby
# test/test_helper.rb
class ActiveSupport::TestCase
  def assert_broadcasts(stream, target = nil, &block)
    # Custom assertion for Turbo Stream broadcasts
  end

  def assert_enqueued_email(mailer, method, args: nil, &block)
    assert_enqueued_with(
      job: ActionMailer::MailDeliveryJob,
      args: [mailer.to_s, method.to_s, "deliver_now", { args: args }],
      &block
    )
  end
end
```

### Fixture helper methods

```ruby
# test/test_helper.rb
class ActiveSupport::TestCase
  fixtures :all

  def reload_fixtures
    # Force reload fixtures mid-test if needed
    ActiveRecord::FixtureSet.reset_cache
    ActiveRecord::FixtureSet.create_fixtures(
      "test/fixtures",
      ActiveRecord::FixtureSet.fixture_table_names
    )
  end
end
```

## Testing concerns

```ruby
# test/models/concerns/closeable_test.rb
require "test_helper"

class CloseableTest < ActiveSupport::TestCase
  # Test concern in isolation using a dummy class
  class DummyCloseable < ApplicationRecord
    self.table_name = "cards"
    include Card::Closeable
  end

  setup do
    @record = DummyCloseable.find(cards(:logo).id)
  end

  test "close creates closure record" do
    assert_difference -> { Closure.count }, 1 do
      @record.close
    end

    assert @record.closed?
  end

  test "closed scope finds closed records" do
    @record.close

    assert_includes DummyCloseable.closed, @record
  end
end
```

## Performance testing

```ruby
# test/performance/card_query_test.rb
require "test_helper"

class CardQueryTest < ActiveSupport::TestCase
  test "active scope is efficient" do
    # Create many cards
    100.times do |i|
      Card.create!(
        title: "Card #{i}",
        board: boards(:projects),
        column: columns(:backlog),
        account: accounts(:37s)
      )
    end

    # Assert query count
    assert_queries(1) do
      Card.active.load
    end
  end

  test "n+1 query prevention" do
    # Ensure includes/joins prevent n+1
    assert_queries(2) do # 1 for cards, 1 for comments
      cards = Card.includes(:comments).limit(10)
      cards.each do |card|
        card.comments.count
      end
    end
  end
end
```

## Parallel testing

```ruby
# test/test_helper.rb
class ActiveSupport::TestCase
  parallelize(workers: :number_of_processors)

  # Setup for parallel tests
  parallelize_setup do |worker|
    # Setup code for each worker
  end

  parallelize_teardown do |worker|
    # Cleanup code for each worker
  end
end
```

## Common test patterns catalog

### 1. Assert creates record
```ruby
assert_difference -> { Card.count }, 1 do
  @card.close
end
```

### 2. Assert updates attribute
```ruby
@card.close
assert @card.closed?
assert_equal @user, @card.closed_by
```

### 3. Assert raises error
```ruby
assert_raises ActiveRecord::RecordInvalid do
  Card.create!(title: nil)
end
```

### 4. Assert includes in collection
```ruby
assert_includes Card.open, @card
refute_includes Card.closed, @card
```

### 5. Assert redirects
```ruby
post cards_path, params: { card: { title: "Test" } }
assert_redirected_to card_path(Card.last)
```

### 6. Assert response code
```ruby
get card_path(@card)
assert_response :success
```

### 7. Assert select elements
```ruby
get cards_path
assert_select "h1", "Cards"
assert_select ".card", count: 3
```

### 8. Assert text present
```ruby
visit card_path(@card)
assert_text @card.title
```

### 9. Assert job enqueued
```ruby
assert_enqueued_with job: NotifyRecipientsJob do
  @card.close
end
```

### 10. Assert email sent
```ruby
assert_emails 1 do
  @identity.send_magic_link
end
```

## Fixture best practices

### 1. Name fixtures by what they represent
```yaml
# Good
active_card:
closed_card:
golden_card:

# Bad
card_1:
card_2:
card_3:
```

### 2. Use associations by name
```yaml
# Good
logo:
  creator: david
  board: projects

# Bad
logo:
  creator_id: 1
  board_id: 1
```

### 3. Create realistic data
```yaml
# Good
david:
  full_name: "David Heinemeier Hansson"
  email_address: "david@myapp.com"

# Bad
user_1:
  full_name: "Test User"
  email_address: "test@test.com"
```

### 4. Keep fixtures minimal
```yaml
# Only include what's necessary for tests
# Let defaults handle the rest
logo:
  title: "Design new logo"
  creator: david
  board: projects
  # Rails will set timestamps, IDs, etc.
```

## Testing anti-patterns to avoid

### ❌ Don't use factories

```ruby
# BAD - Don't do this
let(:card) { FactoryBot.create(:card) }

# GOOD - Use fixtures
setup do
  @card = cards(:logo)
end
```

### ❌ Don't test implementation details

```ruby
# BAD - Testing internals
test "calls create_closure" do
  @card.expects(:create_closure!)
  @card.close
end

# GOOD - Test behavior
test "closing creates closure" do
  @card.close
  assert @card.closed?
end
```

### ❌ Don't create unnecessary data in tests

```ruby
# BAD - Creating when fixtures exist
setup do
  @user = User.create!(name: "Test")
  @card = Card.create!(title: "Test", user: @user)
end

# GOOD - Use fixtures
setup do
  @user = users(:david)
  @card = cards(:logo)
end
```

### ❌ Don't test Rails functionality

```ruby
# BAD - Rails already tests this
test "validates presence of title" do
  @card.title = nil
  assert_not @card.valid?
end

# GOOD - Only test custom validations
test "validates title doesn't contain profanity" do
  @card.title = "bad word"
  assert_not @card.valid?
end
```

## Coverage and CI

```ruby
# Add to test_helper.rb for coverage
if ENV['COVERAGE']
  require 'simplecov'
  SimpleCov.start 'rails' do
    add_filter '/test/'
    add_filter '/config/'

    minimum_coverage 80
  end
end
```

```yaml
# .github/workflows/test.yml
name: Tests
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: ruby/setup-ruby@v1
        with:
          bundler-cache: true
      - run: bin/rails db:setup
      - run: bin/rails test
      - run: bin/rails test:system
```

## Boundaries

- ✅ **Always do:** Use Minitest (never RSpec), use fixtures (never factories), test behavior not implementation, write integration tests for features, test happy path and edge cases, use descriptive test names, clean up in teardown, run tests before committing
- ⚠️ **Ask first:** Before testing private methods (test public interface instead), before testing Rails functionality (already tested), before creating test data in setup (use fixtures), before using mocks/stubs (prefer real objects)
- 🚫 **Never do:** Use RSpec, use FactoryBot or other factories, skip writing tests, test implementation details, create unnecessary test data, leave failing tests, skip system tests for critical features, test every edge case (diminishing returns), forget to test error cases
