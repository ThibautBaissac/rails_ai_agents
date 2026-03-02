# Testing Action Cable Channels

## Channel Spec

```ruby
# spec/channels/notifications_channel_spec.rb
require "rails_helper"

RSpec.describe NotificationsChannel, type: :channel do
  let(:user) { create(:user) }

  before do
    stub_connection(current_user: user)
  end

  describe "#subscribed" do
    it "successfully subscribes" do
      subscribe
      expect(subscription).to be_confirmed
    end

    it "streams for the current user" do
      subscribe
      expect(subscription).to have_stream_for(user)
    end
  end

  describe ".notify" do
    let(:notification) { create(:notification, user: user) }

    it "broadcasts to the user" do
      expect {
        described_class.notify(user, notification)
      }.to have_broadcasted_to(user).with(hash_including(type: "notification"))
    end
  end
end
```

## Channel with Authorization

```ruby
# spec/channels/events_channel_spec.rb
require "rails_helper"

RSpec.describe EventsChannel, type: :channel do
  let(:user) { create(:user) }
  let(:event) { create(:event, account: user.account) }
  let(:other_event) { create(:event) }

  before do
    stub_connection(current_user: user)
  end

  describe "#subscribed" do
    context "with authorized event" do
      it "subscribes successfully" do
        subscribe(event_id: event.id)
        expect(subscription).to be_confirmed
        expect(subscription).to have_stream_for(event)
      end
    end

    context "with unauthorized event" do
      it "rejects subscription" do
        subscribe(event_id: other_event.id)
        expect(subscription).to be_rejected
      end
    end
  end
end
```

## Integration Test

```ruby
# spec/system/chat_spec.rb
require "rails_helper"

RSpec.describe "Chat", type: :system, js: true do
  let(:user) { create(:user) }
  let(:room) { create(:chat_room, users: [user]) }

  before { sign_in user }

  it "sends and receives messages in real-time" do
    visit chat_room_path(room)

    fill_in "message", with: "Hello, world!"
    click_button "Send"

    expect(page).to have_content("Hello, world!")
  end
end
```
