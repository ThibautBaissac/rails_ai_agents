# Magic Links Reference

## Magic link model

```ruby
# Migration
class CreateMagicLinks < ActiveRecord::Migration[8.2]
  def change
    create_table :magic_links, id: :uuid do |t|
      t.references :identity, null: false, type: :uuid
      t.string :code, null: false
      t.string :purpose, default: "sign_in"
      t.datetime :expires_at, null: false
      t.datetime :used_at
      t.timestamps
    end
    add_index :magic_links, :code, unique: true
    add_index :magic_links, [:identity_id, :purpose]
  end
end

# app/models/magic_link.rb
class MagicLink < ApplicationRecord
  CODE_LENGTH = 6

  belongs_to :identity

  before_create :set_code
  before_create :set_expiration

  scope :unused, -> { where(used_at: nil) }
  scope :active, -> { unused.where("expires_at > ?", Time.current) }

  def self.authenticate(code)
    active.find_by(code: code.upcase)&.tap do |magic_link|
      magic_link.update!(used_at: Time.current)
    end
  end

  def expired?
    expires_at < Time.current
  end

  def used?
    used_at.present?
  end

  def valid_for_use?
    !expired? && !used?
  end

  private

  def set_code
    self.code = SecureRandom.alphanumeric(CODE_LENGTH).upcase
  end

  def set_expiration
    self.expires_at = 15.minutes.from_now
  end
end
```

## Flow diagram

```
1. User enters email on /session/new
2. SessionsController#create finds Identity, calls identity.send_magic_link
3. MagicLink record created (6-char code, expires in 15 min)
4. MagicLinkMailer sends email with link containing code
5. User clicks link -> Sessions::MagicLinksController#show
6. MagicLink.authenticate(code) verifies: active + unused
7. If valid: marks used_at, starts new session, redirects to app
8. If invalid/expired: redirects to sign-in with alert
```

## Security properties

### One-time use
The `authenticate` class method atomically finds and marks the link as used:

```ruby
def self.authenticate(code)
  active.find_by(code: code.upcase)&.tap do |magic_link|
    magic_link.update!(used_at: Time.current)  # Immediately consumed
  end
end
```

### Short expiration
15 minutes is short enough to be secure, long enough for email delivery:

```ruby
def set_expiration
  self.expires_at = 15.minutes.from_now
end
```

### Code format
6-character alphanumeric uppercase -- easy to type manually if needed:

```ruby
def set_code
  self.code = SecureRandom.alphanumeric(CODE_LENGTH).upcase
end
# Example codes: "A7K2M9", "X3P8W1"
```

## Mailer template

```erb
<%# app/views/magic_link_mailer/sign_in_instructions.html.erb %>
<h1>Sign in to <%= app_name %></h1>
<p>Click the link below to sign in:</p>
<p><%= link_to "Sign in now", @url %></p>
<p>Or enter this code: <strong><%= @magic_link.code %></strong></p>
<p>This link expires in 15 minutes.</p>
<p>If you didn't request this, you can safely ignore this email.</p>
```

## Multiple purposes

Magic links support different purposes beyond sign-in:

```ruby
# Sign in (default)
identity.send_magic_link(purpose: "sign_in")

# Email verification after signup
identity.send_magic_link(purpose: "verify_email")

# Account recovery
identity.send_magic_link(purpose: "recover_account")
```

## Testing magic links

```ruby
class MagicLinkTest < ActiveSupport::TestCase
  test "generates 6-character code" do
    magic_link = MagicLink.create!(identity: identities(:david))
    assert_equal 6, magic_link.code.length
    assert_match /\A[A-Z0-9]+\z/, magic_link.code
  end

  test "expires after 15 minutes" do
    magic_link = MagicLink.create!(identity: identities(:david))
    assert magic_link.valid_for_use?

    travel 16.minutes do
      assert magic_link.expired?
      assert_not magic_link.valid_for_use?
    end
  end

  test "authenticates with valid code" do
    magic_link = MagicLink.create!(identity: identities(:david))
    authenticated = MagicLink.authenticate(magic_link.code)
    assert_equal magic_link, authenticated
    assert authenticated.used?
  end

  test "doesn't authenticate used codes" do
    magic_link = MagicLink.create!(identity: identities(:david))
    MagicLink.authenticate(magic_link.code)
    assert_nil MagicLink.authenticate(magic_link.code)
  end
end

class Sessions::MagicLinksControllerTest < ActionDispatch::IntegrationTest
  test "authenticates with valid magic link" do
    magic_link = magic_links(:david_sign_in)
    get session_magic_link_path(code: magic_link.code)
    assert_redirected_to root_path
    assert_present cookies[:session_token]
  end

  test "rejects expired magic link" do
    magic_link = magic_links(:david_expired)
    get session_magic_link_path(code: magic_link.code)
    assert_redirected_to new_session_path
    assert_equal "Invalid or expired link", flash[:alert]
  end
end
```

## Fixture examples

```yaml
# test/fixtures/magic_links.yml
david_sign_in:
  identity: david
  code: "ABC123"
  purpose: sign_in
  expires_at: <%= 10.minutes.from_now %>
  used_at: null

david_expired:
  identity: david
  code: "XYZ789"
  purpose: sign_in
  expires_at: <%= 1.hour.ago %>
  used_at: null

david_used:
  identity: david
  code: "DEF456"
  purpose: sign_in
  expires_at: <%= 10.minutes.from_now %>
  used_at: <%= 5.minutes.ago %>
```
