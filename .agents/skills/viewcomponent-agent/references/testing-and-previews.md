# ViewComponent Testing and Previews Reference

## Complete RSpec Test Structure

```ruby
# spec/components/profile_card_component_spec.rb
require "rails_helper"

RSpec.describe ProfileCardComponent, type: :component do
  let(:profile) { create(:profile, first_name: "Jane", last_name: "Doe", email: "jane@example.com", active: true) }

  describe "rendering" do
    context "with minimal parameters" do
      it "renders the profile name" do
        render_inline(described_class.new(profile: profile))

        expect(page).to have_css(".profile-card__name", text: "Jane Doe")
      end

      it "does not show details by default" do
        render_inline(described_class.new(profile: profile))

        expect(page).not_to have_css(".profile-card__details")
      end

      it "renders default variant classes" do
        render_inline(described_class.new(profile: profile))

        expect(page).to have_css(".profile-card.profile-card--default")
      end
    end

    context "with show_details: true" do
      it "displays the profile details" do
        render_inline(described_class.new(profile: profile, show_details: true))

        expect(page).to have_css(".profile-card__details", text: "jane@example.com")
      end
    end

    context "with variant: :compact" do
      it "applies compact variant classes" do
        render_inline(described_class.new(profile: profile, variant: :compact))

        expect(page).to have_css(".profile-card.profile-card--compact")
      end
    end

    context "with custom HTML attributes" do
      it "merges custom attributes" do
        render_inline(described_class.new(
          profile: profile,
          id: "custom-id",
          data: { action: "click->modal#open" }
        ))

        expect(page).to have_css("#custom-id[data-action='click->modal#open']")
      end
    end
  end

  describe "slots" do
    context "with avatar slot" do
      it "renders custom avatar content" do
        render_inline(described_class.new(profile: profile)) do |component|
          component.with_avatar do
            "<img src='/avatar.jpg' alt='Avatar'>".html_safe
          end
        end

        expect(page).to have_css("img[src='/avatar.jpg']")
      end
    end

    context "without avatar slot" do
      it "renders placeholder with initials" do
        render_inline(described_class.new(profile: profile))

        expect(page).to have_css(".profile-card__avatar-placeholder", text: profile.initials)
      end
    end

    context "with badge slot" do
      it "renders the badge" do
        render_inline(described_class.new(profile: profile)) do |component|
          component.with_badge do
            "<span class='badge'>Premium</span>".html_safe
          end
        end

        expect(page).to have_css(".profile-card__badge .badge", text: "Premium")
      end
    end

    context "with actions slot" do
      it "renders multiple actions" do
        render_inline(described_class.new(profile: profile)) do |component|
          component.with_action(text: "Edit", url: "/profiles/1/edit")
          component.with_action(text: "Delete", url: "/profiles/1", method: :delete)
        end

        expect(page).to have_link("Edit", href: "/profiles/1/edit")
        expect(page).to have_link("Delete", href: "/profiles/1")
      end
    end

    context "without actions slot" do
      it "does not render actions section" do
        render_inline(described_class.new(profile: profile))

        expect(page).not_to have_css(".profile-card__actions")
      end
    end
  end

  describe "#render?" do
    context "when profile is active" do
      it "renders the component" do
        render_inline(described_class.new(profile: profile))

        assert_component_rendered
        expect(page).to have_css(".profile-card")
      end
    end

    context "when profile is inactive" do
      let(:inactive_profile) { create(:profile, active: false) }

      it "does not render the component" do
        render_inline(described_class.new(profile: inactive_profile))

        refute_component_rendered
        expect(page).not_to have_css(".profile-card")
      end
    end

    context "when profile is nil" do
      it "does not render the component" do
        render_inline(described_class.new(profile: nil))

        refute_component_rendered
      end
    end
  end

  describe "helpers integration" do
    it "has access to Rails helpers" do
      render_inline(described_class.new(profile: profile)) do |component|
        component.with_action(text: "View", url: profile_path(profile))
      end

      expect(page).to have_link("View", href: "/profiles/#{profile.id}")
    end
  end

  describe "private methods" do
    subject(:component) { described_class.new(profile: profile, variant: :compact) }

    describe "#card_classes" do
      it "returns correct classes for variant" do
        expect(component.send(:card_classes)).to eq("profile-card profile-card--compact")
      end
    end
  end
end
```

## Collection Test

```ruby
# spec/components/item_card_component_spec.rb
RSpec.describe ItemCardComponent, type: :component do
  describe "collection rendering" do
    let(:items) { create_list(:item, 3) }

    it "renders all items" do
      render_inline(described_class.with_collection(items))

      expect(page).to have_css(".item-card", count: 3)
    end

    it "marks first item as featured" do
      render_inline(described_class.with_collection(items))

      expect(page).to have_css(".item-card--featured", count: 1)
    end
  end
end
```

## Lookbook Previews

```ruby
# spec/components/previews/profile_card_component_preview.rb
class ProfileCardComponentPreview < ViewComponent::Preview
  # @label Default
  def default
    profile = Profile.new(
      first_name: "Jane",
      last_name: "Doe",
      email: "jane@example.com",
      active: true
    )

    render(ProfileCardComponent.new(profile: profile))
  end

  # @label Compact
  def compact
    profile = Profile.new(first_name: "John", last_name: "Smith", active: true)
    render(ProfileCardComponent.new(profile: profile, variant: :compact))
  end

  # @label With Details
  def with_details
    profile = Profile.new(
      first_name: "Alice",
      last_name: "Johnson",
      email: "alice@example.com",
      active: true
    )

    render(ProfileCardComponent.new(profile: profile, show_details: true))
  end

  # @label With Custom Avatar
  def with_avatar
    profile = Profile.new(first_name: "Bob", last_name: "Wilson", active: true)

    render(ProfileCardComponent.new(profile: profile)) do |component|
      component.with_avatar do
        tag.img(src: "https://i.pravatar.cc/150?img=3", alt: "Avatar", class: "rounded-full w-12 h-12")
      end
    end
  end

  # @label Complete Card
  def with_all_slots
    profile = Profile.new(
      first_name: "Sarah",
      last_name: "Connor",
      email: "sarah@example.com",
      active: true
    )

    render(ProfileCardComponent.new(profile: profile, show_details: true)) do |component|
      component.with_avatar do
        tag.img(src: "https://i.pravatar.cc/150?img=5", alt: "Avatar", class: "rounded-full w-12 h-12")
      end

      component.with_badge do
        tag.span("Premium", class: "badge badge-primary")
      end

      component.with_action(text: "View Profile", url: "#")
      component.with_action(text: "Send Message", url: "#")
    end
  end

  # @label Dynamic
  def dynamic(first_name: "Dynamic", last_name: "Profile", show_details: false)
    profile = Profile.new(
      first_name: first_name,
      last_name: last_name,
      email: "#{first_name.downcase}@example.com",
      active: true
    )

    render(ProfileCardComponent.new(profile: profile, show_details: show_details))
  end

  def with_template
    render_with_template(locals: {
      profiles: [
        Profile.new(first_name: "Profile", last_name: "One", active: true),
        Profile.new(first_name: "Profile", last_name: "Two", active: true),
        Profile.new(first_name: "Profile", last_name: "Three", active: true)
      ]
    })
  end
end
```

```erb
<%# spec/components/previews/profile_card_component_preview/with_template.html.erb %>
<div class="grid grid-cols-1 md:grid-cols-3 gap-4">
  <% profiles.each do |profile| %>
    <%= render(ProfileCardComponent.new(profile: profile, show_details: true)) %>
  <% end %>
</div>
```
