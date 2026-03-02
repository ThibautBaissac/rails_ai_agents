# Form Object Testing and View Integration

## RSpec Tests: Basic Form

```ruby
# spec/forms/entity_registration_form_spec.rb
require "rails_helper"

RSpec.describe EntityRegistrationForm do
  describe "#save" do
    subject(:form) { described_class.new(attributes) }

    let(:owner) { create(:user) }
    let(:attributes) do
      {
        name: "Test Entity",
        description: "An excellent test entity",
        address: "123 Main Street",
        phone: "1234567890",
        email: "contact@example.com",
        owner_id: owner.id
      }
    end

    context "with valid attributes" do
      it "is valid" do
        expect(form).to be_valid
      end

      it "creates an entity" do
        expect { form.save }.to change(Entity, :count).by(1)
      end

      it "creates contact information" do
        form.save
        expect(form.entity.contact_info).to be_present
        expect(form.entity.contact_info.email).to eq("contact@example.com")
      end

      it "sends a confirmation email" do
        expect {
          form.save
        }.to have_enqueued_job(ActionMailer::MailDeliveryJob)
      end

      it "returns true" do
        expect(form.save).to be true
      end
    end

    context "with missing name" do
      let(:attributes) { super().merge(name: "") }

      it "is not valid" do
        expect(form).not_to be_valid
      end

      it "does not create an entity" do
        expect { form.save }.not_to change(Entity, :count)
      end

      it "returns false" do
        expect(form.save).to be false
      end

      it "adds an error to name" do
        form.valid?
        expect(form.errors[:name]).to include("can't be blank")
      end
    end

    context "with invalid email" do
      let(:attributes) { super().merge(email: "invalid") }

      it "is not valid" do
        expect(form).not_to be_valid
        expect(form.errors[:email]).to be_present
      end
    end

    context "with non-existent owner_id" do
      let(:attributes) { super().merge(owner_id: 99999) }

      it "is not valid" do
        expect(form).not_to be_valid
        expect(form.errors[:owner_id]).to include("does not exist")
      end
    end
  end
end
```

## RSpec Tests: Nested Associations

```ruby
# spec/forms/entity_with_items_form_spec.rb
require "rails_helper"

RSpec.describe EntityWithItemsForm do
  describe "#save" do
    subject(:form) { described_class.new(attributes) }

    let(:owner) { create(:user) }
    let(:attributes) do
      {
        name: "Test Entity",
        description: "Test description",
        owner_id: owner.id,
        items: [
          { name: "Item One", description: "With details", price: "18.50", category: "category_a" },
          { name: "Item Two", description: "Another one", price: "7.00", category: "category_b" }
        ]
      }
    end

    context "with valid items" do
      it "creates the entity with items" do
        expect { form.save }.to change(Entity, :count).by(1)
                                .and change(Item, :count).by(2)
      end

      it "correctly associates the items" do
        form.save
        expect(form.entity.items.count).to eq(2)
        expect(form.entity.items.pluck(:name)).to contain_exactly(
          "Item One", "Item Two"
        )
      end
    end

    context "with invalid price" do
      let(:attributes) do
        super().merge(
          items: [{ name: "Test", price: "-5", category: "category_a" }]
        )
      end

      it "is not valid" do
        expect(form).not_to be_valid
        expect(form.errors[:base]).to include(/price.*must be positive/)
      end
    end
  end
end
```

## Controller Usage

```ruby
# app/controllers/entities_controller.rb
class EntitiesController < ApplicationController
  def new
    @form = EntityRegistrationForm.new(owner_id: current_user.id)
  end

  def create
    @form = EntityRegistrationForm.new(registration_params)

    if @form.save
      redirect_to @form.entity, notice: "Entity created successfully"
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def registration_params
    params.require(:entity_registration_form).permit(
      :name, :description, :address, :phone, :email, :owner_id
    )
  end
end
```

## ERB View: Classic Form

```erb
<%# app/views/entities/new.html.erb %>
<%= form_with model: @form, url: entities_path, local: true do |f| %>
  <%= render "shared/error_messages", object: @form %>

  <%= f.hidden_field :owner_id %>

  <div class="field">
    <%= f.label :name %>
    <%= f.text_field :name, class: "input" %>
  </div>

  <div class="field">
    <%= f.label :description %>
    <%= f.text_area :description, class: "textarea" %>
  </div>

  <div class="field">
    <%= f.label :address %>
    <%= f.text_field :address, class: "input" %>
  </div>

  <div class="field">
    <%= f.label :phone %>
    <%= f.telephone_field :phone, class: "input" %>
  </div>

  <div class="field">
    <%= f.label :email %>
    <%= f.email_field :email, class: "input" %>
  </div>

  <%= f.submit "Create Entity", class: "button is-primary" %>
<% end %>
```

## ERB View: Nested Form with Stimulus

```erb
<%# app/views/entities/new_with_items.html.erb %>
<%= form_with model: @form, url: entities_path,
              data: { controller: "nested-form" } do |f| %>

  <%= f.text_field :name %>
  <%= f.text_area :description %>

  <div data-nested-form-target="container">
    <h3>Items</h3>

    <template data-nested-form-target="template">
      <div class="item">
        <%= f.fields_for :items, OpenStruct.new do |item_f| %>
          <%= item_f.text_field :name, placeholder: "Item name" %>
          <%= item_f.text_area :description, placeholder: "Description" %>
          <%= item_f.number_field :price, step: 0.01, placeholder: "Price" %>
          <%= item_f.select :category, %w[category_a category_b category_c category_d] %>
          <button type="button" data-action="nested-form#remove">Remove</button>
        <% end %>
      </div>
    </template>
  </div>

  <button type="button" data-action="nested-form#add">
    Add Item
  </button>

  <%= f.submit "Create" %>
<% end %>
```
