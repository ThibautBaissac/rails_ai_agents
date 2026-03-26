# Fixture Patterns Reference

## Basic fixture structure

```yaml
# test/fixtures/cards.yml
logo:
  id: d0f1c2e3-4b5a-6789-0123-456789abcdef
  account: 37s
  board: projects
  column: backlog
  creator: david
  title: "Design new logo"
  body: "Need a fresh logo for the homepage"
  status: published
  position: 1
  created_at: <%= 2.days.ago %>
  updated_at: <%= 1.day.ago %>

shipping:
  account: 37s
  board: projects
  column: in_progress
  creator: jason
  title: "Shipping feature"
  body: "Implement shipping calculations"
  status: published
  position: 2

draft_card:
  account: 37s
  board: projects
  column: backlog
  creator: david
  title: "Draft card"
  status: draft
  position: 3
```

## Fixture associations (use names, not IDs)

```yaml
# test/fixtures/users.yml
david:
  identity: david
  account: 37s
  full_name: "David Heinemeier Hansson"
  timezone: "America/Chicago"

jason:
  identity: jason
  account: 37s
  full_name: "Jason Fried"
  timezone: "America/Chicago"

# test/fixtures/identities.yml
david:
  email_address: "david@myapp.com"
  password_digest: <%= BCrypt::Password.create('password', cost: 4) %>

jason:
  email_address: "jason@myapp.com"
  password_digest: <%= BCrypt::Password.create('password', cost: 4) %>

# test/fixtures/accounts.yml
37s:
  name: "myapp"
  timezone: "America/Chicago"
```

Key rule: Reference associated fixtures by their label name (`creator: david`), not by ID.

## ERB in fixtures

```yaml
# Dynamic dates
recent_card:
  created_at: <%= 1.hour.ago %>
  updated_at: <%= 30.minutes.ago %>

# Calculations
expensive_item:
  price: <%= 100 * 1.5 %>

# Conditional data
<% if ENV['FULL_FIXTURES'] %>
extra_card:
  title: "Extra fixture"
<% end %>
```

## YAML anchors (fixture inheritance)

```yaml
# Base template
card_defaults: &card_defaults
  account: 37s
  board: projects
  creator: david
  status: published

# Inherit and override
card_one:
  <<: *card_defaults
  title: "Card One"
  position: 1

card_two:
  <<: *card_defaults
  title: "Card Two"
  position: 2
  creator: jason  # Override
```

## UUID fixtures

Fixtures auto-generate UUIDs based on fixture name. Use explicit UUIDs only when cross-referencing:

```yaml
# Let Rails auto-generate (preferred)
shipping:
  account: 37s
  title: "Shipping feature"

# Explicit UUID when needed
logo:
  id: d0f1c2e3-4b5a-6789-0123-456789abcdef
  account: 37s
  title: "Design new logo"
```

## State record fixtures

```yaml
# test/fixtures/closures.yml
logo_closure:
  account: 37s
  card: logo
  user: david
  created_at: <%= 1.hour.ago %>

# test/fixtures/magic_links.yml
david_sign_in:
  identity: david
  code: "ABC123"
  purpose: sign_in
  expires_at: <%= 10.minutes.from_now %>

david_expired:
  identity: david
  code: "XYZ789"
  purpose: sign_in
  expires_at: <%= 1.hour.ago %>
```

## Best practices

### 1. Name fixtures by what they represent

```yaml
# Good
active_card:
closed_card:
golden_card:

# Bad
card_1:
card_2:
```

### 2. Use realistic data

```yaml
# Good
david:
  full_name: "David Heinemeier Hansson"
  email_address: "david@myapp.com"

# Bad
user_1:
  full_name: "Test User"
  email_address: "test@test.com"
```

### 3. Keep fixtures minimal

```yaml
# Only include what's necessary
# Let defaults handle the rest
logo:
  title: "Design new logo"
  creator: david
  board: projects
  # Rails sets timestamps, IDs, etc.
```

### 4. Fixture helper methods

```ruby
# test/test_helper.rb
class ActiveSupport::TestCase
  fixtures :all

  def reload_fixtures
    ActiveRecord::FixtureSet.reset_cache
    ActiveRecord::FixtureSet.create_fixtures(
      "test/fixtures",
      ActiveRecord::FixtureSet.fixture_table_names
    )
  end
end
```
