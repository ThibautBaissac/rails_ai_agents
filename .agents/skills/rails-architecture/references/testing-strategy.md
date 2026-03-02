# Testing Strategy by Layer

## Test Pyramid

```
        /\
       /  \  System Specs (few)
      /----\
     /      \  Request Specs (moderate)
    /--------\
   /          \  Unit Specs (many)
  --------------
  Models, Services, Queries, Presenters
```

## Unit Tests

### Model Specs

Test validations, scopes, and instance methods:

```ruby
# spec/models/event_spec.rb
RSpec.describe Event, type: :model do
  describe "validations" do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:event_date) }
  end

  describe "associations" do
    it { is_expected.to belong_to(:account) }
    it { is_expected.to have_many(:vendors).through(:event_vendors) }
  end

  describe "scopes" do
    describe ".upcoming" do
      let!(:past_event) { create(:event, event_date: 1.day.ago) }
      let!(:future_event) { create(:event, event_date: 1.day.from_now) }

      it "returns only future events" do
        expect(described_class.upcoming).to contain_exactly(future_event)
      end
    end
  end

  describe "#days_until" do
    it "returns days until event" do
      event = build(:event, event_date: 5.days.from_now)
      expect(event.days_until).to eq(5)
    end
  end
end
```

### Service Specs

Test business logic and error handling:

```ruby
# spec/services/orders/create_service_spec.rb
RSpec.describe Orders::CreateService do
  subject(:service) { described_class.new }

  let(:user) { create(:user) }
  let(:product) { create(:product, inventory: 10) }

  describe "#call" do
    context "with valid params" do
      let(:params) { { user: user, items: [{ product_id: product.id, quantity: 2 }] } }

      it "returns success" do
        expect(service.call(**params)).to be_success
      end

      it "creates an order" do
        expect { service.call(**params) }.to change(Order, :count).by(1)
      end

      it "returns the order" do
        result = service.call(**params)
        expect(result.data).to be_a(Order)
      end
    end

    context "with empty items" do
      let(:params) { { user: user, items: [] } }

      it "returns failure" do
        expect(service.call(**params)).to be_failure
      end

      it "returns error code" do
        expect(service.call(**params).code).to eq(:empty_cart)
      end

      it "does not create order" do
        expect { service.call(**params) }.not_to change(Order, :count)
      end
    end

    context "with insufficient inventory" do
      let(:params) { { user: user, items: [{ product_id: product.id, quantity: 100 }] } }

      it "returns failure with code" do
        result = service.call(**params)
        expect(result).to be_failure
        expect(result.code).to eq(:out_of_stock)
      end
    end
  end
end
```

### Query Specs

Test query results and tenant isolation:

```ruby
# spec/queries/active_events_query_spec.rb
RSpec.describe ActiveEventsQuery do
  subject(:query) { described_class.new(account: account) }

  let(:account) { create(:account) }
  let(:other_account) { create(:account) }

  describe "#call" do
    let!(:active_event) { create(:event, account: account, status: :active) }
    let!(:inactive_event) { create(:event, account: account, status: :cancelled) }
    let!(:other_event) { create(:event, account: other_account, status: :active) }

    it "returns active events for account" do
      expect(query.call).to include(active_event)
    end

    it "excludes inactive events" do
      expect(query.call).not_to include(inactive_event)
    end

    it "excludes other account events (tenant isolation)" do
      expect(query.call).not_to include(other_event)
    end
  end
end
```

### Presenter Specs

Test formatting and HTML output:

```ruby
# spec/presenters/event_presenter_spec.rb
RSpec.describe EventPresenter do
  let(:event) { create(:event, name: "Test Event", status: :confirmed) }
  let(:presenter) { described_class.new(event) }

  describe "delegation" do
    it "delegates to model" do
      expect(presenter.name).to eq("Test Event")
    end
  end

  describe "#status_badge" do
    it "returns HTML-safe string" do
      expect(presenter.status_badge).to be_html_safe
    end

    it "includes status text" do
      expect(presenter.status_badge).to include("Confirmed")
    end

    it "uses correct color for confirmed" do
      expect(presenter.status_badge).to include("bg-green")
    end
  end

  describe "#formatted_date" do
    context "when date present" do
      before { event.update(event_date: Date.new(2026, 7, 15)) }

      it "formats date" do
        expect(presenter.formatted_date).to include("2026")
      end
    end

    context "when date nil" do
      before { event.update(event_date: nil) }

      it "returns placeholder" do
        expect(presenter.formatted_date).to include("text-slate-400")
      end
    end
  end
end
```

## Integration Tests

### Request Specs

Test HTTP flow and response:

```ruby
# spec/requests/events_spec.rb
RSpec.describe "Events", type: :request do
  let(:user) { create(:user) }
  let(:account) { user.account }

  before { sign_in user }

  describe "GET /events" do
    let!(:event) { create(:event, account: account) }
    let!(:other_event) { create(:event) } # Different account

    it "returns success" do
      get events_path
      expect(response).to have_http_status(:ok)
    end

    it "shows user's events" do
      get events_path
      expect(response.body).to include(event.name)
    end

    it "does not show other accounts' events" do
      get events_path
      expect(response.body).not_to include(other_event.name)
    end
  end

  describe "POST /events" do
    let(:valid_params) { { event: { name: "New Event", event_date: 1.week.from_now } } }

    it "creates event" do
      expect {
        post events_path, params: valid_params
      }.to change(Event, :count).by(1)
    end

    it "redirects to event" do
      post events_path, params: valid_params
      expect(response).to redirect_to(Event.last)
    end

    context "with invalid params" do
      let(:invalid_params) { { event: { name: "" } } }

      it "renders form with errors" do
        post events_path, params: invalid_params
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end
end
```

### Policy Specs

Test authorization rules:

```ruby
# spec/policies/event_policy_spec.rb
RSpec.describe EventPolicy do
  subject { described_class.new(user, event) }

  let(:account) { create(:account) }
  let(:event) { create(:event, account: account) }

  context "user owns event" do
    let(:user) { create(:user, account: account) }

    it { is_expected.to permit_actions([:show, :edit, :update, :destroy]) }
  end

  context "user from different account" do
    let(:user) { create(:user) }

    it { is_expected.to forbid_actions([:show, :edit, :update, :destroy]) }
  end

  describe "Scope" do
    let(:user) { create(:user, account: account) }
    let!(:own_event) { create(:event, account: account) }
    let!(:other_event) { create(:event) }

    it "returns only own events" do
      scope = described_class::Scope.new(user, Event).resolve
      expect(scope).to include(own_event)
      expect(scope).not_to include(other_event)
    end
  end
end
```

## System Tests

Test critical user journeys:

```ruby
# spec/system/create_event_spec.rb
RSpec.describe "Creating an event", type: :system do
  let(:user) { create(:user) }

  before { sign_in user }

  it "creates event successfully" do
    visit new_event_path

    fill_in "Name", with: "Company Party"
    fill_in "Event date", with: 1.month.from_now
    select "Corporate", from: "Event type"

    click_button "Create Event"

    expect(page).to have_content("Event was successfully created")
    expect(page).to have_content("Company Party")
  end

  it "shows validation errors" do
    visit new_event_path

    click_button "Create Event"

    expect(page).to have_content("Name can't be blank")
  end
end
```

## Component Specs

Test ViewComponents:

```ruby
# spec/components/event_card_component_spec.rb
RSpec.describe EventCardComponent, type: :component do
  let(:event) { create(:event, name: "Test Event") }

  it "renders event name" do
    render_inline(described_class.new(event: event))
    expect(page).to have_content("Test Event")
  end

  it "renders status badge" do
    render_inline(described_class.new(event: event))
    expect(page).to have_css(".badge")
  end

  context "with upcoming event" do
    let(:event) { create(:event, event_date: 3.days.from_now) }

    it "shows days until" do
      render_inline(described_class.new(event: event))
      expect(page).to have_content("3 days")
    end
  end
end
```

## Test Helpers

### Shared Examples

```ruby
# spec/support/shared_examples/tenant_isolation.rb
RSpec.shared_examples "tenant isolated" do
  it "excludes other tenant data" do
    other_account = create(:account)
    other_record = create(factory, account: other_account)

    expect(subject).not_to include(other_record)
  end
end

# Usage
RSpec.describe ActiveEventsQuery do
  subject { described_class.new(account: account).call }
  let(:account) { create(:account) }
  let(:factory) { :event }

  it_behaves_like "tenant isolated"
end
```

### Factory Traits

```ruby
# spec/factories/events.rb
FactoryBot.define do
  factory :event do
    account
    name { Faker::Company.name }
    event_date { 1.month.from_now }
    status { :draft }

    trait :confirmed do
      status { :confirmed }
    end

    trait :past do
      event_date { 1.month.ago }
    end

    trait :with_vendors do
      after(:create) do |event|
        create_list(:event_vendor, 3, event: event)
      end
    end
  end
end
```

## Coverage Requirements

| Layer | Minimum Coverage |
|-------|-----------------|
| Models | 90% |
| Services | 95% |
| Queries | 90% |
| Controllers | 80% |
| Overall | 85% |

## Checklist

- [ ] Unit tests for all models
- [ ] Service specs cover success/failure paths
- [ ] Query specs test tenant isolation
- [ ] Request specs for all endpoints
- [ ] Policy specs for authorization
- [ ] System specs for critical flows
- [ ] Component specs for ViewComponents
- [ ] Shared examples for common patterns
- [ ] Factory traits for common states
