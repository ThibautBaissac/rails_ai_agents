# System Tests Reference

## Setup

```ruby
# test/application_system_test_case.rb
require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [1400, 1000]

  def sign_in_as(user)
    visit new_session_path
    fill_in "Email", with: user.identity.email_address
    click_button "Send magic link"

    # Use magic link directly in test
    magic_link = user.identity.magic_links.last
    visit session_magic_link_path(code: magic_link.code)
  end
end
```

## Full-stack feature tests

```ruby
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
end
```

## Real-time update tests

```ruby
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
```

## JavaScript interaction tests

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

## Drag and drop tests

```ruby
test "reordering cards" do
  visit board_path(@card.board)

  first_card = find(".card:first-child")
  second_card = find(".card:nth-child(2)")

  first_card.drag_to(second_card)

  within ".card:first-child" do
    assert_text second_card.text
  end
end
```

## Common Capybara assertions

```ruby
# Text presence
assert_text "Expected text"
assert_no_text "Unexpected text"

# Element presence
assert_selector ".card"
assert_no_selector ".card--deleted"
assert_selector ".card", count: 3
assert_selector ".card", text: "Logo"

# Within scoped element
within ".sidebar" do
  assert_text "Navigation"
end

within "##{dom_id(@card)}" do
  assert_selector ".card__title", text: @card.title
end

# Form interactions
fill_in "Title", with: "New title"
select "Published", from: "Status"
check "Featured"
uncheck "Featured"
choose "Option A"
attach_file "Avatar", Rails.root.join("test/fixtures/files/avatar.jpg")

# Buttons and links
click_button "Save"
click_link "Edit"
click_on "Submit"  # Clicks either button or link

# Waiting (Capybara auto-waits by default)
assert_text "Loading complete"  # Waits up to Capybara.default_max_wait_time
```

## Tips

1. **System tests are slow** -- Use them only for critical user workflows, not edge cases
2. **Auto-waiting** -- Capybara waits for elements to appear; don't add manual sleeps
3. **Headless Chrome** -- Use `driven_by :selenium, using: :headless_chrome` for CI
4. **`using_session`** -- Test multi-user real-time scenarios with separate browser sessions
5. **Test Turbo behavior** -- System tests naturally verify Turbo Streams/Frames work correctly
6. **Avoid `page.driver`** -- Use Capybara's public API for portability

## Coverage and CI

```ruby
# test/test_helper.rb
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
