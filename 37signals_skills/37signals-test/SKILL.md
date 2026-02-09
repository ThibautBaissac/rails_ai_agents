---
name: 37signals-test
description: Write Minitest tests with fixtures, not RSpec with factories. Triggers on test, testing, Minitest, fixtures, system test.
allowed-tools: Read, Write, Edit, Bash
---

# 37signals Test Skill

## Overview

Write tests using Minitest (not RSpec) and fixtures (not factories). Integration tests over unit tests. Fast, readable tests that verify behavior.

## Core Philosophy

- **Minitest over RSpec**: Plain Ruby, no DSL to learn
- **Fixtures over factories**: 10-100x faster, loaded once
- **Test behavior, not implementation**: What it does, not how

## Fixture Patterns

### Basic Fixtures

```yaml
# test/fixtures/cards.yml
logo:
  id: d0f1c2e3-4b5a-6789-0123-456789abcdef
  account: acme
  board: projects
  column: backlog
  creator: david
  title: "Design new logo"
  status: published
  created_at: <%= 2.days.ago %>

draft_card:
  account: acme
  board: projects
  column: backlog
  creator: david
  title: "Draft card"
  status: draft
```

### Fixture Associations

```yaml
# Use names, not IDs
logo:
  creator: david  # References users(:david)
  board: projects # References boards(:projects)
```

### YAML Anchors for DRY

```yaml
card_defaults: &card_defaults
  account: acme
  board: projects
  creator: david
  status: published

card_one:
  <<: *card_defaults
  title: "Card One"

card_two:
  <<: *card_defaults
  title: "Card Two"
```

## Model Tests

```ruby
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

  test "validates title presence" do
    @card.title = nil
    assert_not @card.valid?
    assert_includes @card.errors[:title], "can't be blank"
  end
end
```

## Controller Tests

```ruby
class CardsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @card = cards(:logo)
    sign_in_as users(:david)
  end

  test "should get index" do
    get board_cards_path(@card.board)
    assert_response :success
  end

  test "should create card" do
    assert_difference -> { Card.count }, 1 do
      post board_cards_path(@card.board), params: {
        card: { title: "New card", column_id: @card.column_id }
      }
    end
    assert_redirected_to card_path(Card.last)
  end

  test "scopes to current account" do
    other_card = cards(:other_account_card)
    get card_path(other_card)
    assert_response :not_found
  end
end
```

### Turbo Stream Tests

```ruby
test "create returns turbo stream" do
  post card_comments_path(@card),
    params: { comment: { body: "Test" } },
    as: :turbo_stream

  assert_response :success
  assert_equal "text/vnd.turbo-stream.html", response.media_type
end
```

## System Tests

```ruby
class CardsTest < ApplicationSystemTestCase
  setup do
    @card = cards(:logo)
    sign_in_as users(:david)
  end

  test "creating a card" do
    visit board_path(@card.board)
    click_link "New Card"
    fill_in "Title", with: "New feature"
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
end
```

## Job Tests

```ruby
class NotifyRecipientsJobTest < ActiveJob::TestCase
  test "creates notifications" do
    comment = comments(:logo_comment)

    assert_difference -> { Notification.count }, 2 do
      NotifyRecipientsJob.perform_now(comment)
    end
  end

  test "job is enqueued" do
    comment = comments(:logo_comment)

    assert_enqueued_with job: NotifyRecipientsJob do
      comment.notify_recipients_later
    end
  end
end
```

## Mailer Tests

```ruby
class MagicLinkMailerTest < ActionMailer::TestCase
  test "sign in email" do
    magic_link = magic_links(:david_sign_in)
    email = MagicLinkMailer.sign_in_instructions(magic_link)

    assert_emails 1 do
      email.deliver_now
    end

    assert_equal [magic_link.identity.email_address], email.to
    assert_match magic_link.code, email.body.to_s
  end
end
```

## Test Helpers

```ruby
# test/test_helper.rb
class ActionDispatch::IntegrationTest
  def sign_in_as(user)
    session = user.identity.sessions.create!
    cookies.signed[:session_token] = session.token
    Current.user = user
  end

  def sign_out
    cookies.delete(:session_token)
    Current.reset
  end
end
```

## Common Assertions

```ruby
# Record changes
assert_difference -> { Card.count }, 1 do
  Card.create!(...)
end

# State changes
assert @card.closed?
assert_equal @user, @card.closed_by

# Collections
assert_includes Card.open, @card
refute_includes Card.closed, @card

# Errors
assert_raises ActiveRecord::RecordInvalid do
  Card.create!(title: nil)
end

# Responses
assert_response :success
assert_redirected_to card_path(@card)

# DOM
assert_select "h1", "Cards"
assert_text "Card created"
```

## Commands

```bash
bin/rails test                        # Run all tests
bin/rails test test/models/card_test.rb  # Run file
bin/rails test test/models/card_test.rb:14  # Run line
bin/rails test:system                 # System tests only
```

## Boundaries

### Always
- Use Minitest (never RSpec)
- Use fixtures (never factories)
- Test behavior, not implementation
- Write integration tests for features
- Use descriptive test names

### Never
- Use RSpec or FactoryBot
- Test Rails functionality
- Create unnecessary test data
- Test private methods
- Skip tests before committing
