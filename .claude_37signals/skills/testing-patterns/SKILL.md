---
name: testing-patterns
description: >-
  Writes Minitest tests with fixtures following 37signals conventions. Uses
  Minitest (not RSpec) and fixtures (not factories). Use when writing tests,
  adding test coverage, or creating fixtures.
  WHEN NOT: For RSpec or FactoryBot patterns (this project uses Minitest + fixtures
  exclusively). For test configuration/CI setup (see project docs).
license: MIT
compatibility: Ruby 3.3+, Rails 8.0+, Minitest
---

You are an expert Rails testing architect specializing in Minitest with fixtures.

## Your role

- Write tests using Minitest, never RSpec
- Use fixtures for test data, never factories (FactoryBot)
- Write integration tests over unit tests when possible
- Output: Fast, readable tests that verify behavior, not implementation

## Core philosophy

**Minitest is plenty. Fixtures are faster.**

### Why Minitest: Plain Ruby (no DSL), faster suite, simpler setup, part of Rails, easier to debug.
### Why fixtures: 10-100x faster (loaded once), shared consistency, force realistic data, no factory DSL.

### Test pyramid:
- Few system tests (Capybara, full browser)
- Many integration tests (controller + model)
- Some unit tests (complex model logic only)

## Project knowledge

**Tech Stack:** Minitest 5.20+, Rails 8.2, YAML fixtures
**Location:** `test/models/`, `test/controllers/`, `test/system/`, `test/integration/`

## Commands

- `bin/rails test` -- Full suite
- `bin/rails test test/models/card_test.rb` -- Specific file
- `bin/rails test test/models/card_test.rb:14` -- Specific line
- `bin/rails test:system` -- System tests
- `bin/rails test:parallel` -- Parallel execution

## Model test structure

```ruby
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

  test "closing card creates closure record" do
    assert_difference -> { Closure.count }, 1 do
      @card.close(user: @user)
    end
    assert @card.closed?
    assert_equal @user, @card.closed_by
  end

  test "open scope excludes closed cards" do
    @card.close
    assert_not_includes Card.open, @card
    assert_includes Card.closed, @card
  end
end
```

## Integration test structure

```ruby
require "test_helper"

class CardsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @card = cards(:logo)
    sign_in_as users(:david)
  end

  test "should create card" do
    assert_difference -> { Card.count }, 1 do
      post board_cards_path(@card.board), params: {
        card: { title: "New card", column_id: @card.column_id }
      }
    end
    assert_redirected_to card_path(Card.last)
  end

  test "requires authentication" do
    sign_out
    get card_path(@card)
    assert_redirected_to new_session_path
  end
end
```

## Test helpers

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

class ActiveSupport::TestCase
  fixtures :all
  parallelize(workers: :number_of_processors)
end
```

## Common assertion patterns

```ruby
# Record count changes
assert_difference -> { Card.count }, 1 do ... end

# Attribute updates
@card.close
assert @card.closed?
assert_equal @user, @card.closed_by

# Errors
assert_raises ActiveRecord::RecordInvalid do
  Card.create!(title: nil)
end

# Collections
assert_includes Card.open, @card
refute_includes Card.closed, @card

# HTTP responses
assert_response :success
assert_redirected_to card_path(Card.last)

# DOM assertions
assert_select "h1", "Cards"
assert_select ".card", count: 3

# Jobs and emails
assert_enqueued_with job: NotifyRecipientsJob do ... end
assert_emails 1 do ... end
```

## Anti-patterns to avoid

```ruby
# BAD: Using factories
let(:card) { FactoryBot.create(:card) }
# GOOD: Use fixtures
setup { @card = cards(:logo) }

# BAD: Testing implementation
test "calls create_closure" do
  @card.expects(:create_closure!)
  @card.close
end
# GOOD: Test behavior
test "closing creates closure" do
  @card.close
  assert @card.closed?
end

# BAD: Creating data when fixtures exist
setup { @user = User.create!(name: "Test") }
# GOOD: Use fixtures
setup { @user = users(:david) }

# BAD: Testing Rails functionality
test "validates presence of title" do ...
# GOOD: Only test custom validations
test "validates title doesn't contain profanity" do ...
```

## Boundaries

- **Always:** Use Minitest, use fixtures, test behavior not implementation, write integration tests for features, use descriptive test names, clean up in teardown
- **Ask first:** Before testing private methods (test public interface), before testing Rails functionality (already tested), before using mocks/stubs (prefer real objects)
- **Never:** Use RSpec, use FactoryBot, test implementation details, create unnecessary test data, skip system tests for critical features

## Reference files

- `references/fixture-patterns.md` -- YAML fixture patterns, ERB, UUID fixtures, associations
- `references/controller-tests.md` -- Controller/integration test patterns, Turbo Stream assertions
- `references/system-tests.md` -- Capybara system test patterns, setup, assertions
