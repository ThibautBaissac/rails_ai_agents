---
name: rails-controller
description: >-
  Creates Rails controllers with TDD approach - request spec first, then
  implementation. Use when creating new controllers, adding controller actions,
  implementing CRUD operations, or when user mentions controllers, routes,
  or API endpoints.
license: MIT
compatibility: Ruby 3.3+, Rails 8.1+, RSpec
metadata:
  author: ThibautBaissac
  version: "1.0"
---

# Rails Controller Generator (TDD)

Creates RESTful controllers following project conventions with request specs first.

## Quick Start

1. Write failing request spec in `spec/requests/`
2. Run spec to confirm RED
3. Implement controller action
4. Run spec to confirm GREEN
5. Refactor if needed

## Project Conventions

This project uses:
- **Pundit** for authorization (`authorize @resource`, `policy_scope(Model)`)
- **Pagy** for pagination
- **Presenters** for view formatting
- **Multi-tenancy** via `current_account`
- **Turbo Stream** responses for dynamic updates

## TDD Workflow

### Step 1: Create Request Spec (RED)

```ruby
# spec/requests/[resources]_spec.rb
RSpec.describe "[Resources]", type: :request do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }

  before { sign_in user, scope: :user }

  describe "GET /[resources]" do
    let!(:resource) { create(:[resource], account: user.account) }
    let!(:other_resource) { create(:[resource], account: other_user.account) }

    it "returns http success" do
      get [resources]_path
      expect(response).to have_http_status(:success)
    end

    it "shows only current_user's resources (multi-tenant)" do
      get [resources]_path
      expect(response.body).to include(resource.name)
      expect(response.body).not_to include(other_resource.name)
    end
  end

  describe "GET /[resources]/:id" do
    let!(:resource) { create(:[resource], account: user.account) }

    it "returns http success" do
      get [resource]_path(resource)
      expect(response).to have_http_status(:success)
    end
  end

  describe "POST /[resources]" do
    let(:valid_params) { { [resource]: attributes_for(:[resource]) } }

    it "creates a new resource" do
      expect {
        post [resources]_path, params: valid_params
      }.to change([Resource], :count).by(1)
    end

    it "assigns to current_account" do
      post [resources]_path, params: valid_params
      expect([Resource].last.account).to eq(user.account)
    end
  end

  describe "authorization" do
    let!(:other_resource) { create(:[resource], account: other_user.account) }

    it "returns 404 for unauthorized access" do
      get [resource]_path(other_resource)
      expect(response).to have_http_status(:not_found)
    end
  end
end
```

### Step 2: Run Spec (Confirm RED)

```bash
bundle exec rspec spec/requests/[resources]_spec.rb
```

### Step 3: Implement Controller (GREEN)

```ruby
# app/controllers/[resources]_controller.rb
class [Resources]Controller < ApplicationController
  before_action :set_[resource], only: [:show, :edit, :update, :destroy]

  def index
    authorize [Resource], :index?
    @pagy, resources = pagy(policy_scope([Resource]).order(created_at: :desc))
    @[resources] = resources.map { |r| [Resource]Presenter.new(r) }
  end

  def show
    authorize @[resource]
    @[resource] = [Resource]Presenter.new(@[resource])
  end

  def new
    @[resource] = current_account.[resources].build
    authorize @[resource]
  end

  def create
    @[resource] = current_account.[resources].build([resource]_params)
    authorize @[resource]

    if @[resource].save
      redirect_to [resources]_path, notice: "[Resource] created successfully"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @[resource]
  end

  def update
    authorize @[resource]

    if @[resource].update([resource]_params)
      redirect_to @[resource], notice: "[Resource] updated successfully"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @[resource]
    @[resource].destroy
    redirect_to [resources]_path, notice: "[Resource] deleted successfully"
  end

  private

  def set_[resource]
    @[resource] = policy_scope([Resource]).find(params[:id])
  end

  def [resource]_params
    params.require(:[resource]).permit(:name, :field1, :field2)
  end
end
```

### Step 4: Run Spec (Confirm GREEN)

```bash
bundle exec rspec spec/requests/[resources]_spec.rb
```

## Namespaced Controllers

For nested routes like `settings/accounts`:

```ruby
# app/controllers/settings/accounts_controller.rb
module Settings
  class AccountsController < ApplicationController
    before_action :set_account

    def show
      authorize @account
    end

    private

    def set_account
      @account = current_account
    end
  end
end
```

## Turbo Stream Response Pattern

```ruby
def create
  @resource = current_account.resources.build(resource_params)
  authorize @resource

  if @resource.save
    respond_to do |format|
      format.html { redirect_to resources_path, notice: "Created" }
      format.turbo_stream do
        flash.now[:notice] = "Created"
        @pagy, @resources = pagy(policy_scope(Resource).order(created_at: :desc))
        render turbo_stream: [
          turbo_stream.replace("resources-list", partial: "resources/list"),
          turbo_stream.update("modal", "")
        ]
      end
    end
  else
    render :new, status: :unprocessable_entity
  end
end
```

## Checklist

- [ ] Request spec written first (RED)
- [ ] Multi-tenant isolation tested
- [ ] Authorization tested (404 for unauthorized)
- [ ] Controller uses `authorize` on every action
- [ ] Controller uses `policy_scope` for queries
- [ ] Presenter wraps models for views
- [ ] Strong parameters defined
- [ ] All specs GREEN
