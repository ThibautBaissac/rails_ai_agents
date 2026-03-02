# Views and Testing

## View Integration

### Conditional Display in ERB

```erb
<%# app/views/events/show.html.erb %>
<h1><%= @event.name %></h1>

<% if policy(@event).edit? %>
  <%= link_to t("common.edit"), edit_event_path(@event) %>
<% end %>

<% if policy(@event).destroy? %>
  <%= button_to t("common.delete"), @event, method: :delete,
                data: { confirm: t("common.confirm_delete") } %>
<% end %>

<% if policy(@event).publish? %>
  <%= button_to t(".publish"), publish_event_path(@event), method: :post %>
<% end %>
```

### In ViewComponents

```ruby
# app/components/event_actions_component.rb
class EventActionsComponent < ApplicationComponent
  include Pundit::Authorization

  def initialize(event:, user:)
    @event = event
    @user = user
  end

  def can_edit?
    policy.edit?
  end

  def can_delete?
    policy.destroy?
  end

  def can_publish?
    policy.publish?
  end

  private

  def policy
    @policy ||= EventPolicy.new(@user, @event)
  end
end
```

## Policy Spec

```ruby
# spec/policies/event_policy_spec.rb
require 'rails_helper'

RSpec.describe EventPolicy, type: :policy do
  subject { described_class }

  let(:account) { create(:account) }
  let(:user) { create(:user, account: account) }
  let(:other_user) { create(:user) }  # Different account
  let(:event) { create(:event, account: account) }

  permissions :index? do
    it "permits any authenticated user" do
      expect(subject).to permit(user, Event)
    end
  end

  permissions :show? do
    it "permits user from same account" do
      expect(subject).to permit(user, event)
    end

    it "denies user from different account" do
      expect(subject).not_to permit(other_user, event)
    end
  end

  permissions :create? do
    it "permits user from same account" do
      expect(subject).to permit(user, Event.new(account: account))
    end
  end

  permissions :update?, :destroy? do
    it "permits user from same account" do
      expect(subject).to permit(user, event)
    end

    it "denies user from different account" do
      expect(subject).not_to permit(other_user, event)
    end
  end

  describe "Scope" do
    let!(:own_event) { create(:event, account: account) }
    let!(:other_event) { create(:event) }  # Different account

    it "returns events for user's account only" do
      scope = described_class::Scope.new(user, Event).resolve

      expect(scope).to include(own_event)
      expect(scope).not_to include(other_event)
    end
  end
end
```

## Using pundit-matchers Gem

```ruby
# Gemfile
gem 'pundit-matchers', group: :test

# spec/rails_helper.rb
require 'pundit/matchers'

# spec/policies/event_policy_spec.rb
RSpec.describe EventPolicy, type: :policy do
  subject { described_class.new(user, event) }

  let(:account) { create(:account) }
  let(:user) { create(:user, account: account) }
  let(:event) { create(:event, account: account) }

  context "user owns the event" do
    it { is_expected.to permit_actions([:show, :edit, :update, :destroy]) }
  end

  context "user from different account" do
    let(:user) { create(:user) }

    it { is_expected.to forbid_actions([:show, :edit, :update, :destroy]) }
  end
end
```

## Controller/Request Spec

```ruby
# spec/requests/events_spec.rb
RSpec.describe "Events", type: :request do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }
  let(:event) { create(:event, account: user.account) }
  let(:other_event) { create(:event, account: other_user.account) }

  before { sign_in user }

  describe "GET /events/:id" do
    it "allows access to own events" do
      get event_path(event)
      expect(response).to have_http_status(:ok)
    end

    it "denies access to other's events" do
      get event_path(other_event)
      expect(response).to redirect_to(root_path)
    end
  end

  describe "DELETE /events/:id" do
    it "allows deletion of own events" do
      delete event_path(event)
      expect(response).to redirect_to(events_path)
      expect(Event.exists?(event.id)).to be false
    end

    it "denies deletion of other's events" do
      delete event_path(other_event)
      expect(response).to redirect_to(root_path)
      expect(Event.exists?(other_event.id)).to be true
    end
  end
end
```

## Error Messages (I18n)

```yaml
# config/locales/en.yml
en:
  pundit:
    not_authorized: You are not authorized to perform this action.
    event_policy:
      show?: You cannot view this event.
      update?: You cannot edit this event.
      destroy?: You cannot delete this event.
      publish?: This event cannot be published.
```

```ruby
# Custom error handling with scoped messages
rescue_from Pundit::NotAuthorizedError do |exception|
  policy_name = exception.policy.class.to_s.underscore
  message = t("#{policy_name}.#{exception.query}", scope: "pundit", default: :default)
  redirect_back(fallback_location: root_path, alert: message)
end
```
