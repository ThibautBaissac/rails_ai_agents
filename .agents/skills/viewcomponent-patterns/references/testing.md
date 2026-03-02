# ViewComponent Patterns: Testing

## Basic Spec Structure

```ruby
RSpec.describe BadgeComponent, type: :component do
  describe "variants" do
    it "renders success variant" do
      render_inline(described_class.new(text: "Active", variant: :success))
      expect(page).to have_css(".bg-green-100")
    end

    it "renders error variant" do
      render_inline(described_class.new(text: "Failed", variant: :error))
      expect(page).to have_css(".bg-red-100")
    end

    it "defaults to neutral" do
      render_inline(described_class.new(text: "Unknown"))
      expect(page).to have_css(".bg-slate-100")
    end
  end
end
```

## Testing a Component with Optional Arguments

```ruby
# spec/components/card_component_spec.rb
require "rails_helper"

RSpec.describe CardComponent, type: :component do
  let(:component) { described_class.new(title: "Test Title") }

  describe "rendering" do
    it "renders the title" do
      render_inline(component)
      expect(page).to have_css("h3", text: "Test Title")
    end

    it "renders content block" do
      render_inline(component) { "Card content" }
      expect(page).to have_text("Card content")
    end
  end

  describe "with optional subtitle" do
    let(:component) { described_class.new(title: "Title", subtitle: "Subtitle") }

    it "renders subtitle" do
      render_inline(component)
      expect(page).to have_css("p", text: "Subtitle")
    end
  end

  describe "without subtitle" do
    it "does not render subtitle element" do
      render_inline(component)
      expect(page).not_to have_css(".subtitle")
    end
  end
end
```

## Testing Slots

```ruby
RSpec.describe CardComponent, type: :component do
  it "renders header slot" do
    render_inline(described_class.new) do |card|
      card.with_header { "Custom Header" }
    end

    expect(page).to have_text("Custom Header")
  end

  it "renders multiple action slots" do
    render_inline(described_class.new) do |card|
      card.with_action { "Action 1" }
      card.with_action { "Action 2" }
    end

    expect(page).to have_text("Action 1")
    expect(page).to have_text("Action 2")
  end
end
```

## Testing Collections

```ruby
RSpec.describe EventCardComponent, type: :component do
  let(:events) { create_list(:event, 3) }

  it "renders collection" do
    render_inline(described_class.with_collection(events))
    expect(page).to have_css(".event-card", count: 3)
  end
end
```

## Previews (Development)

```ruby
# spec/components/previews/badge_component_preview.rb
class BadgeComponentPreview < ViewComponent::Preview
  def success
    render BadgeComponent.new(text: "Active", variant: :success)
  end

  def error
    render BadgeComponent.new(text: "Failed", variant: :error)
  end

  def with_long_text
    render BadgeComponent.new(text: "Very long status text here", variant: :info)
  end
end
```

Access at: `http://localhost:3000/rails/view_components`
