# Turbo Testing Reference

## Testing Turbo Stream Responses

```ruby
# spec/requests/resources_spec.rb
require 'rails_helper'

RSpec.describe "Resources", type: :request do
  let(:user) { create(:user) }

  before { sign_in user }

  describe "POST /resources" do
    context "with valid params" do
      let(:valid_params) { { resource: { name: "Test Resource" } } }

      it "creates resource and returns turbo stream" do
        post resources_path, params: valid_params,
             headers: { "Accept" => "text/vnd.turbo-stream.html" }

        expect(response).to have_http_status(:ok)
        expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      end

      it "includes prepend action in response" do
        post resources_path, params: valid_params,
             headers: { "Accept" => "text/vnd.turbo-stream.html" }

        expect(response.body).to include('turbo-stream action="prepend"')
        expect(response.body).to include('target="resources"')
      end

      it "falls back to HTML redirect" do
        post resources_path, params: valid_params

        expect(response).to redirect_to(Resource.last)
      end
    end

    context "with invalid params" do
      let(:invalid_params) { { resource: { name: "" } } }

      it "returns turbo stream with form errors" do
        post resources_path, params: invalid_params,
             headers: { "Accept" => "text/vnd.turbo-stream.html" }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include('turbo-stream action="replace"')
      end
    end
  end

  describe "DELETE /resources/:id" do
    let!(:resource) { create(:resource, user: user) }

    it "removes resource via turbo stream" do
      delete resource_path(resource),
             headers: { "Accept" => "text/vnd.turbo-stream.html" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('turbo-stream action="remove"')
      expect(response.body).to include("resource_#{resource.id}")
    end
  end
end
```

## Testing Turbo Frames

```ruby
# spec/requests/resources_spec.rb
describe "GET /resources/:id/edit" do
  let(:resource) { create(:resource, user: user) }

  it "returns frame content for turbo frame request" do
    get edit_resource_path(resource),
        headers: { "Turbo-Frame" => dom_id(resource) }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("turbo-frame")
    expect(response.body).to include(dom_id(resource))
  end
end
```

## Custom Turbo Stream Matchers

```ruby
# spec/support/turbo_stream_matchers.rb
RSpec::Matchers.define :have_turbo_stream do |action, target|
  match do |response|
    response.body.include?("turbo-stream action=\"#{action}\"") &&
      response.body.include?("target=\"#{target}\"")
  end

  failure_message do |response|
    "expected turbo stream with action='#{action}' and target='#{target}'"
  end
end

# Usage in specs
expect(response).to have_turbo_stream(:prepend, "resources")
expect(response).to have_turbo_stream(:remove, dom_id(resource))
```

## Debugging Turbo

### Browser DevTools

1. **Network Tab:** Filter by `turbo-stream` or check Accept headers
2. **Console:** `Turbo.session` shows current state
3. **Elements:** Look for `<turbo-frame>` and `<turbo-stream>` elements

### Turbo Events for Debugging

```javascript
document.addEventListener("turbo:load", (event) => {
  console.log("Turbo: Page loaded", event)
})

document.addEventListener("turbo:frame-load", (event) => {
  console.log("Turbo: Frame loaded", event.target.id)
})

document.addEventListener("turbo:before-stream-render", (event) => {
  console.log("Turbo: Stream rendering", event.detail)
})

document.addEventListener("turbo:submit-start", (event) => {
  console.log("Turbo: Form submitting", event.detail)
})
```

### Common Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| Frame not updating | Mismatched IDs | Ensure source and target frames have same ID |
| Full page reload | Missing Turbo | Check `@hotwired/turbo-rails` is imported |
| Form errors not showing | Wrong response format | Return `turbo_stream` with `replace` action |
| Flash not appearing | Missing target | Ensure `#flash` container exists |
| History broken | Frame navigation | Use `data-turbo-action="advance"` |
