---
name: rails-presenter
description: >-
  Creates presenter objects for view formatting using SimpleDelegator pattern
  with TDD. Use when extracting view logic from models, formatting data for
  display, creating badges/labels, or when user mentions presenters, view
  models, formatting, or display helpers.
license: MIT
compatibility: Ruby 3.3+, Rails 8.1+, RSpec
metadata:
  author: ThibautBaissac
  version: "1.0"
---

# Rails Presenter Generator (TDD)

Creates presenters that wrap models for view-specific formatting with specs first.

## Quick Start

1. Write failing spec in `spec/presenters/`
2. Run spec to confirm RED
3. Implement presenter extending `BasePresenter`
4. Run spec to confirm GREEN

## Project Conventions

Presenters in this project:
- Extend `BasePresenter < SimpleDelegator`
- Include ActionView helpers for formatting
- Delegate model methods via SimpleDelegator
- Return HTML-safe strings for badges/formatted output
- Use I18n for all user-facing text

## BasePresenter (Already Exists)

```ruby
# app/presenters/base_presenter.rb
class BasePresenter < SimpleDelegator
  include ActionView::Helpers::NumberHelper
  include ActionView::Helpers::DateHelper
  include ActionView::Helpers::UrlHelper
  include ActionView::Helpers::TagHelper
  include ActionView::Helpers::TextHelper

  def initialize(model, view_context = nil)
    super(model)
    @view_context = view_context
  end

  def model
    __getobj__
  end

  alias_method :object, :model
end
```

## TDD Workflow

### Step 1: Create Presenter Spec (RED)

```ruby
# spec/presenters/[resource]_presenter_spec.rb
RSpec.describe [Resource]Presenter do
  let(:resource) { create(:resource, name: "Test", status: :active) }
  let(:presenter) { described_class.new(resource) }

  describe "delegation" do
    it "delegates to the model" do
      expect(presenter.name).to eq("Test")
    end

    it "responds to model methods" do
      expect(presenter).to respond_to(:name, :status, :created_at)
    end

    it "exposes the underlying model" do
      expect(presenter.model).to eq(resource)
    end
  end

  describe "#display_name" do
    it "returns the formatted name" do
      expect(presenter.display_name).to eq("Test")
    end
  end

  describe "#formatted_date" do
    context "when date is present" do
      before { resource.update(event_date: Date.new(2026, 7, 15)) }

      it "returns formatted date in French" do
        I18n.with_locale(:fr) do
          expect(presenter.formatted_date).to include("2026")
        end
      end
    end

    context "when date is nil" do
      before { resource.update(event_date: nil) }

      it "returns placeholder span" do
        result = presenter.formatted_date
        expect(result).to include("text-slate-400")
        expect(result).to include("italic")
      end
    end
  end

  describe "#status_badge" do
    it "returns HTML-safe string" do
      expect(presenter.status_badge).to be_html_safe
    end

    it "includes status text" do
      expect(presenter.status_badge).to include("Active")
    end

    it "uses correct color classes for active" do
      resource.update(status: :active)
      expect(presenter.status_badge).to include("bg-green-100")
    end

    it "uses correct color classes for inactive" do
      resource.update(status: :inactive)
      expect(presenter.status_badge).to include("bg-red-100")
    end
  end

  describe "#formatted_currency" do
    it "formats cents as euros" do
      resource.update(amount_cents: 15000)
      expect(presenter.formatted_amount).to eq("150,00 EUR")
    end
  end
end
```

### Step 2: Run Spec (Confirm RED)

```bash
bundle exec rspec spec/presenters/[resource]_presenter_spec.rb
```

### Step 3: Implement Presenter (GREEN)

```ruby
# app/presenters/[resource]_presenter.rb
class [Resource]Presenter < BasePresenter
  # Color mapping for Open/Closed Principle
  STATUS_COLORS = {
    active: "bg-green-100 text-green-800",
    inactive: "bg-red-100 text-red-800",
    pending: "bg-yellow-100 text-yellow-800"
  }.freeze

  DEFAULT_COLOR = "bg-slate-100 text-slate-800"

  def display_name
    name
  end

  def formatted_date
    return not_specified_span if event_date.nil?
    I18n.l(event_date, format: :long)
  end

  def status_badge
    tag.span(
      status_text,
      class: "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium #{status_color}"
    )
  end

  def formatted_amount
    return "0,00 EUR" if amount_cents.nil? || amount_cents.zero?
    number_to_currency(
      amount_cents / 100.0,
      unit: "EUR",
      separator: ",",
      delimiter: " ",
      format: "%n %u"
    )
  end

  private

  def status_text
    I18n.t("activerecord.attributes.[resource].statuses.#{status}", default: status.to_s.humanize)
  end

  def status_color
    STATUS_COLORS.fetch(status.to_sym, DEFAULT_COLOR)
  end

  def not_specified_span
    tag.span(
      I18n.t("presenters.common.not_specified"),
      class: "text-slate-400 italic"
    )
  end
end
```

### Step 4: Run Spec (Confirm GREEN)

```bash
bundle exec rspec spec/presenters/[resource]_presenter_spec.rb
```

## Common Presenter Methods

### Date Formatting

```ruby
def formatted_event_date
  return not_specified_span if event_date.nil?
  I18n.l(event_date, format: :long)
end

def short_date
  return "—" if event_date.nil?
  event_date.strftime("%d/%m/%Y")
end

def days_until
  return nil if event_date.nil?
  days = (event_date - Date.today).to_i
  case days
  when 0 then I18n.t("presenters.event.today")
  when 1 then I18n.t("presenters.event.tomorrow")
  when 2..7 then I18n.t("presenters.event.days_from_now", count: days)
  else distance_of_time_in_words_to_now(event_date)
  end
end
```

### Currency Formatting

```ruby
def formatted_budget
  return not_specified_span if budget_cents.nil?
  number_to_currency(
    budget_cents / 100.0,
    unit: "EUR",
    separator: ",",
    delimiter: " ",
    format: "%n %u",
    precision: 0
  )
end
```

### Badge/Tag Generation

```ruby
def type_badge
  tag.span(
    display_type,
    class: "inline-flex items-center px-2 py-1 rounded text-xs font-medium #{type_color}"
  )
end

def display_tags
  return not_specified_span if tags.blank?
  safe_join(
    tags.split(",").map(&:strip).map do |tag_text|
      tag.span(tag_text, class: "inline-block bg-slate-100 px-2 py-1 rounded text-xs mr-1")
    end
  )
end
```

### Contact Links

```ruby
def display_email
  return not_specified_span if email.blank?
  mail_to(email, email, class: "text-blue-600 hover:underline")
end

def display_phone
  return not_specified_span if phone.blank?
  link_to(phone, "tel:#{phone}", class: "text-blue-600 hover:underline")
end
```

## Usage in Controllers

```ruby
# Single resource
@event = EventPresenter.new(@event)

# Collection
@events = events.map { |e| EventPresenter.new(e) }

# With view context (for route helpers)
@event = EventPresenter.new(@event, view_context)
```

## Checklist

- [ ] Spec written first (RED)
- [ ] Extends `BasePresenter`
- [ ] Delegation tested
- [ ] HTML output is `html_safe`
- [ ] Uses I18n for all text
- [ ] Currency stored in cents, displayed in euros
- [ ] Color mappings use constants (Open/Closed)
- [ ] `not_specified_span` for nil values
- [ ] All specs GREEN
