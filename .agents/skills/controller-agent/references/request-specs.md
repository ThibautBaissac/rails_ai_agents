# Controller Request Specs

## Basic Request Spec

```ruby
# spec/requests/restaurants_spec.rb
require 'rails_helper'

RSpec.describe "Restaurants", type: :request do
  let(:user) { create(:user) }

  describe "GET /restaurants" do
    it "returns http success" do
      get restaurants_path
      expect(response).to have_http_status(:success)
    end

    it "displays all restaurants" do
      restaurant = create(:restaurant)
      get restaurants_path
      expect(response.body).to include(restaurant.name)
    end
  end

  describe "GET /restaurants/:id" do
    let(:restaurant) { create(:restaurant) }

    it "returns http success" do
      get restaurant_path(restaurant)
      expect(response).to have_http_status(:success)
    end

    it "displays restaurant details" do
      get restaurant_path(restaurant)
      expect(response.body).to include(restaurant.name)
      expect(response.body).to include(restaurant.description)
    end
  end

  describe "POST /restaurants" do
    context "when user is authenticated" do
      before { sign_in user }

      context "with valid parameters" do
        let(:valid_params) do
          { restaurant: { name: "New Restaurant", description: "Great food", address: "123 Main St" } }
        end

        it "creates a new restaurant" do
          expect {
            post restaurants_path, params: valid_params
          }.to change(Restaurant, :count).by(1)
        end

        it "redirects to the created restaurant" do
          post restaurants_path, params: valid_params
          expect(response).to redirect_to(restaurant_path(Restaurant.last))
        end
      end

      context "with invalid parameters" do
        let(:invalid_params) do
          { restaurant: { name: "" } }
        end

        it "does not create a restaurant" do
          expect {
            post restaurants_path, params: invalid_params
          }.not_to change(Restaurant, :count)
        end

        it "renders the new template" do
          post restaurants_path, params: invalid_params
          expect(response).to have_http_status(:unprocessable_entity)
        end
      end
    end

    context "when user is not authenticated" do
      it "redirects to sign in" do
        post restaurants_path, params: { restaurant: { name: "Test" } }
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe "PATCH /restaurants/:id" do
    let(:restaurant) { create(:restaurant, user: user) }

    before { sign_in user }

    context "with valid parameters" do
      let(:new_attributes) { { name: "Updated Name" } }

      it "updates the restaurant" do
        patch restaurant_path(restaurant), params: { restaurant: new_attributes }
        restaurant.reload
        expect(restaurant.name).to eq("Updated Name")
      end

      it "redirects to the restaurant" do
        patch restaurant_path(restaurant), params: { restaurant: new_attributes }
        expect(response).to redirect_to(restaurant_path(restaurant))
      end
    end
  end

  describe "DELETE /restaurants/:id" do
    let!(:restaurant) { create(:restaurant, user: user) }

    before { sign_in user }

    it "destroys the restaurant" do
      expect {
        delete restaurant_path(restaurant)
      }.to change(Restaurant, :count).by(-1)
    end

    it "redirects to restaurants list" do
      delete restaurant_path(restaurant)
      expect(response).to redirect_to(restaurants_path)
    end
  end
end
```

## API Request Spec

```ruby
# spec/requests/api/v1/restaurants_spec.rb
require 'rails_helper'

RSpec.describe "Api::V1::Restaurants", type: :request do
  let(:user) { create(:user) }
  let(:headers) { auth_headers_for(user) }

  describe "GET /api/v1/restaurants" do
    it "returns restaurants as JSON" do
      restaurant = create(:restaurant)

      get api_v1_restaurants_path, headers: headers

      expect(response).to have_http_status(:ok)
      expect(response.content_type).to match(a_string_including("application/json"))

      json = JSON.parse(response.body)
      expect(json.size).to eq(1)
      expect(json[0]["name"]).to eq(restaurant.name)
    end
  end

  describe "POST /api/v1/restaurants" do
    context "with valid parameters" do
      let(:valid_params) do
        { restaurant: { name: "API Restaurant", description: "Test" } }
      end

      it "creates a restaurant" do
        expect {
          post api_v1_restaurants_path, params: valid_params, headers: headers
        }.to change(Restaurant, :count).by(1)
      end

      it "returns created status" do
        post api_v1_restaurants_path, params: valid_params, headers: headers
        expect(response).to have_http_status(:created)
      end

      it "returns the created restaurant as JSON" do
        post api_v1_restaurants_path, params: valid_params, headers: headers

        json = JSON.parse(response.body)
        expect(json["name"]).to eq("API Restaurant")
      end
    end

    context "with invalid parameters" do
      let(:invalid_params) do
        { restaurant: { name: "" } }
      end

      it "returns unprocessable entity status" do
        post api_v1_restaurants_path, params: invalid_params, headers: headers
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "returns error messages" do
        post api_v1_restaurants_path, params: invalid_params, headers: headers

        json = JSON.parse(response.body)
        expect(json).to have_key("errors")
      end
    end
  end
end
```
