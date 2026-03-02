# Active Storage: Testing Attachments

## Model Spec

```ruby
# spec/models/user_spec.rb
require 'rails_helper'

RSpec.describe User, type: :model do
  describe "avatar attachment" do
    let(:user) { create(:user) }

    it "attaches an avatar" do
      user.avatar.attach(
        io: File.open(Rails.root.join("spec/fixtures/files/avatar.jpg")),
        filename: "avatar.jpg",
        content_type: "image/jpeg"
      )

      expect(user.avatar).to be_attached
    end

    it "generates variants" do
      user.avatar.attach(
        io: File.open(Rails.root.join("spec/fixtures/files/avatar.jpg")),
        filename: "avatar.jpg",
        content_type: "image/jpeg"
      )

      expect(user.avatar.variant(:thumb)).to be_present
    end
  end
end
```

## Factory with Attachments

```ruby
# spec/factories/users.rb
FactoryBot.define do
  factory :user do
    name { Faker::Name.name }

    trait :with_avatar do
      after(:build) do |user|
        user.avatar.attach(
          io: File.open(Rails.root.join("spec/fixtures/files/avatar.jpg")),
          filename: "avatar.jpg",
          content_type: "image/jpeg"
        )
      end
    end
  end
end

# Usage
create(:user, :with_avatar)
```

## Request Spec

```ruby
# spec/requests/users_spec.rb
RSpec.describe "Users", type: :request do
  describe "PATCH /users/:id" do
    let(:user) { create(:user) }
    let(:avatar) { fixture_file_upload("avatar.jpg", "image/jpeg") }

    before { sign_in user }

    it "uploads avatar" do
      patch user_path(user), params: { user: { avatar: avatar } }

      expect(user.reload.avatar).to be_attached
    end
  end
end
```
