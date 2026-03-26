# Controller / Integration Tests Reference

## Basic CRUD integration tests

```ruby
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
        card: { title: "New card", body: "Card body", column_id: @card.column_id }
      }
    end
    assert_redirected_to card_path(Card.last)
    assert_equal "Card created", flash[:notice]
  end

  test "should update card" do
    patch card_path(@card), params: { card: { title: "Updated title" } }
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

## Turbo Stream response tests

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

  delete card_comment_path(@card, comment), as: :turbo_stream

  assert_response :success
  assert_match /turbo-stream action="remove"/, response.body
end
```

## Authentication tests

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

## JSON API tests

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

## Filter and scoping tests

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

## Job test patterns

```ruby
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
    NotifyRecipientsJob.perform_now(comment)
    refute Notification.exists?(recipient_id: comment.creator_id, notifiable: comment)
  end
end
```

## Mailer test patterns

```ruby
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
  end
end
```

## Testing concerns

```ruby
class CloseableTest < ActiveSupport::TestCase
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

## Performance / N+1 tests

```ruby
test "active scope is efficient" do
  assert_queries(1) do
    Card.active.load
  end
end

test "n+1 query prevention" do
  assert_queries(2) do
    cards = Card.includes(:comments).limit(10)
    cards.each { |card| card.comments.count }
  end
end
```
