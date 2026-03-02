# Pundit Testing and Controller Usage Reference

## Pundit Matchers Setup

```ruby
# spec/support/pundit_matchers.rb
require "pundit/rspec"

RSpec.configure do |config|
  config.include Pundit::RSpec::Matchers, type: :policy
end
```

## Complete Policy Test (EntityPolicy)

```ruby
# spec/policies/entity_policy_spec.rb
require "rails_helper"

RSpec.describe EntityPolicy, type: :policy do
  subject(:policy) { described_class.new(user, entity) }

  let(:entity) { create(:entity, user: owner) }
  let(:owner) { create(:user) }

  context "unauthenticated visitor" do
    let(:user) { nil }

    it { is_expected.to permit_action(:index) }
    it { is_expected.to permit_action(:show) }
    it { is_expected.to forbid_action(:create) }
    it { is_expected.to forbid_action(:new) }
    it { is_expected.to forbid_action(:update) }
    it { is_expected.to forbid_action(:edit) }
    it { is_expected.to forbid_action(:destroy) }
  end

  context "authenticated user (non-owner)" do
    let(:user) { create(:user) }

    it { is_expected.to permit_action(:index) }
    it { is_expected.to permit_action(:show) }
    it { is_expected.to permit_action(:create) }
    it { is_expected.to permit_action(:new) }
    it { is_expected.to forbid_action(:update) }
    it { is_expected.to forbid_action(:edit) }
    it { is_expected.to forbid_action(:destroy) }
  end

  context "entity owner" do
    let(:user) { owner }

    it { is_expected.to permit_actions(:index, :show, :create, :new, :update, :edit, :destroy) }
  end

  describe "Scope" do
    subject(:scope) { described_class::Scope.new(user, Entity.all).resolve }

    let!(:published_entity) { create(:entity, published: true) }
    let!(:unpublished_entity) { create(:entity, published: false) }

    context "visitor" do
      let(:user) { nil }

      it "returns only published entities" do
        expect(scope).to include(published_entity)
        expect(scope).not_to include(unpublished_entity)
      end
    end
  end

  describe "#permitted_attributes" do
    context "owner" do
      let(:user) { owner }

      it "allows all attributes" do
        expect(policy.permitted_attributes).to include(
          :name, :description, :address, :phone, :email
        )
      end
    end

    context "non-owner" do
      let(:user) { create(:user) }

      it "allows no attributes" do
        expect(policy.permitted_attributes).to be_empty
      end
    end
  end
end
```

## Test with Roles (SubmissionPolicy)

```ruby
# spec/policies/submission_policy_spec.rb
require "rails_helper"

RSpec.describe SubmissionPolicy, type: :policy do
  subject(:policy) { described_class.new(user, submission) }

  let(:author) { create(:user) }
  let(:entity_owner) { create(:user) }
  let(:admin) { create(:user, role: :admin) }
  let(:entity) { create(:entity, user: entity_owner) }
  let(:submission) { create(:submission, user: author, entity: entity) }

  describe "#destroy?" do
    context "submission author" do
      let(:user) { author }
      it { is_expected.to permit_action(:destroy) }
    end

    context "entity owner" do
      let(:user) { entity_owner }
      it { is_expected.to permit_action(:destroy) }
    end

    context "administrator" do
      let(:user) { admin }
      it { is_expected.to permit_action(:destroy) }
    end

    context "regular user" do
      let(:user) { create(:user) }
      it { is_expected.to forbid_action(:destroy) }
    end
  end

  describe "#moderate?" do
    context "entity owner" do
      let(:user) { entity_owner }
      it { is_expected.to permit_action(:moderate) }
    end

    context "administrator" do
      let(:user) { admin }
      it { is_expected.to permit_action(:moderate) }
    end

    context "submission author" do
      let(:user) { author }
      it { is_expected.to forbid_action(:moderate) }
    end
  end

  describe "#create?" do
    let(:user) { create(:user) }
    let(:submission) { build(:submission, user: user, entity: entity) }

    context "first submission for this entity" do
      it { is_expected.to permit_action(:create) }
    end

    context "already submitted" do
      before { create(:submission, user: user, entity: entity) }
      it { is_expected.to forbid_action(:create) }
    end
  end
end
```

## Test with Complex Conditions (BookingPolicy)

```ruby
# spec/policies/booking_policy_spec.rb
require "rails_helper"

RSpec.describe BookingPolicy, type: :policy do
  subject(:policy) { described_class.new(user, booking) }

  let(:customer) { create(:user) }
  let(:entity_owner) { create(:user) }
  let(:entity) { create(:entity, user: entity_owner) }

  describe "#cancel?" do
    let(:user) { customer }

    context "booking in the future (>4h)" do
      let(:booking) do
        create(:booking,
               user: customer,
               entity: entity,
               booking_datetime: 6.hours.from_now)
      end

      it { is_expected.to permit_action(:cancel) }
    end

    context "booking in less than 4h" do
      let(:booking) do
        create(:booking,
               user: customer,
               entity: entity,
               booking_datetime: 2.hours.from_now)
      end

      it { is_expected.to forbid_action(:cancel) }
    end

    context "booking in the past" do
      let(:booking) do
        create(:booking,
               user: customer,
               entity: entity,
               booking_datetime: 2.hours.ago)
      end

      it { is_expected.to forbid_action(:cancel) }
    end

    context "entity owner (regardless of time)" do
      let(:user) { entity_owner }
      let(:booking) do
        create(:booking,
               user: customer,
               entity: entity,
               booking_datetime: 1.hour.from_now)
      end

      it { is_expected.to permit_action(:cancel) }
    end
  end
end
```

## Controller with Authorization

```ruby
# app/controllers/entities_controller.rb
class EntitiesController < ApplicationController
  before_action :set_entity, only: [:show, :edit, :update, :destroy]

  def index
    @entities = policy_scope(Entity)
  end

  def show
    authorize @entity
  end

  def new
    @entity = Entity.new
    authorize @entity
  end

  def create
    @entity = current_user.entities.build(entity_params)
    authorize @entity

    if @entity.save
      redirect_to @entity, notice: "Entity created"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @entity
  end

  def update
    authorize @entity

    if @entity.update(permitted_attributes(@entity))
      redirect_to @entity, notice: "Entity updated"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @entity
    @entity.destroy
    redirect_to entities_path, notice: "Entity deleted"
  end

  private

  def set_entity
    @entity = Entity.find(params[:id])
  end

  def entity_params
    params.require(:entity).permit(policy(@entity || Entity).permitted_attributes)
  end
end
```

## Error Handling in ApplicationController

```ruby
# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  include Pundit::Authorization

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  private

  def user_not_authorized
    flash[:alert] = "You are not authorized to perform this action."
    redirect_back(fallback_location: root_path)
  end
end
```

## Custom Actions in Controllers

```ruby
# app/controllers/submissions_controller.rb
class SubmissionsController < ApplicationController
  def moderate
    @submission = Submission.find(params[:id])
    authorize @submission, :moderate?

    @submission.update(status: params[:status])
    redirect_to @submission.entity
  end

  def flag
    @submission = Submission.find(params[:id])
    authorize @submission, :flag?

    @submission.flags.create(user: current_user, reason: params[:reason])
    redirect_back(fallback_location: @submission.entity)
  end
end
```

## Policy Checks in Views

```erb
<%# app/views/entities/show.html.erb %>
<h1><%= @entity.name %></h1>

<% if policy(@entity).update? %>
  <%= link_to "Edit", edit_entity_path(@entity), class: "button" %>
<% end %>

<% if policy(@entity).destroy? %>
  <%= button_to "Delete", entity_path(@entity),
                method: :delete,
                data: { confirm: "Are you sure?" },
                class: "button is-danger" %>
<% end %>

<% if policy(Submission).create? %>
  <%= link_to "Submit content", new_entity_submission_path(@entity), class: "button" %>
<% end %>
```
