# Rails Validation Patterns Reference

## Standard Validations

### Presence

```ruby
validates :name, presence: true
validates :email, presence: { message: "is required" }
```

**Spec:**
```ruby
it { is_expected.to validate_presence_of(:name) }
```

### Uniqueness

```ruby
validates :email, uniqueness: true
validates :email, uniqueness: { case_sensitive: false }
validates :slug, uniqueness: { scope: :organization_id }
validates :email, uniqueness: { conditions: -> { where(deleted_at: nil) } }
```

**Spec:**
```ruby
it { is_expected.to validate_uniqueness_of(:email).case_insensitive }
it { is_expected.to validate_uniqueness_of(:slug).scoped_to(:organization_id) }
```

### Length

```ruby
validates :name, length: { maximum: 100 }
validates :bio, length: { minimum: 10, maximum: 500 }
validates :pin, length: { is: 4 }
validates :tags, length: { in: 1..5 }
```

**Spec:**
```ruby
it { is_expected.to validate_length_of(:name).is_at_most(100) }
it { is_expected.to validate_length_of(:bio).is_at_least(10).is_at_most(500) }
it { is_expected.to validate_length_of(:pin).is_equal_to(4) }
```

### Format

```ruby
validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }
validates :phone, format: { with: /\A\+?[\d\s-]+\z/ }
validates :slug, format: { with: /\A[a-z0-9-]+\z/, message: "only allows lowercase letters, numbers, and hyphens" }
```

**Spec:**
```ruby
it { is_expected.to allow_value('test@example.com').for(:email) }
it { is_expected.not_to allow_value('invalid-email').for(:email) }
```

### Numericality

```ruby
validates :age, numericality: { only_integer: true, greater_than: 0 }
validates :price, numericality: { greater_than_or_equal_to: 0 }
validates :quantity, numericality: { only_integer: true, in: 1..100 }
```

**Spec:**
```ruby
it { is_expected.to validate_numericality_of(:age).only_integer.is_greater_than(0) }
it { is_expected.to validate_numericality_of(:price).is_greater_than_or_equal_to(0) }
```

### Inclusion/Exclusion

```ruby
validates :status, inclusion: { in: %w[draft published archived] }
validates :role, inclusion: { in: :allowed_roles }
validates :username, exclusion: { in: %w[admin root system] }
```

**Spec:**
```ruby
it { is_expected.to validate_inclusion_of(:status).in_array(%w[draft published archived]) }
it { is_expected.to validate_exclusion_of(:username).in_array(%w[admin root system]) }
```

### Acceptance

```ruby
validates :terms, acceptance: true
validates :terms, acceptance: { accept: ['yes', 'true', '1'] }
```

### Confirmation

```ruby
validates :password, confirmation: true
# Requires :password_confirmation attribute in form
```

## Conditional Validations

### With If/Unless

```ruby
validates :phone, presence: true, if: :requires_phone?
validates :company, presence: true, unless: :individual?
validates :bio, length: { minimum: 50 }, if: -> { featured? }
```

**Spec:**
```ruby
context 'when requires_phone? is true' do
  before { allow(subject).to receive(:requires_phone?).and_return(true) }
  it { is_expected.to validate_presence_of(:phone) }
end
```

### With On (Context)

```ruby
validates :password, presence: true, on: :create
validates :reason, presence: true, on: :archive
```

**Spec:**
```ruby
it { is_expected.to validate_presence_of(:password).on(:create) }
```

## Custom Validations

### Custom Method

```ruby
class User < ApplicationRecord
  validate :email_domain_allowed

  private

  def email_domain_allowed
    return if email.blank?

    domain = email.split('@').last
    unless allowed_domains.include?(domain)
      errors.add(:email, "domain is not allowed")
    end
  end
end
```

**Spec:**
```ruby
describe '#email_domain_allowed' do
  context 'with allowed domain' do
    subject { build(:user, email: 'test@allowed.com') }
    it { is_expected.to be_valid }
  end

  context 'with disallowed domain' do
    subject { build(:user, email: 'test@blocked.com') }
    it { is_expected.not_to be_valid }
    it 'adds error message' do
      subject.valid?
      expect(subject.errors[:email]).to include('domain is not allowed')
    end
  end
end
```

### Custom Validator Class

```ruby
# app/validators/email_domain_validator.rb
class EmailDomainValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    return if value.blank?

    domain = value.split('@').last
    unless options[:allowed].include?(domain)
      record.errors.add(attribute, options[:message] || "domain not allowed")
    end
  end
end

# Usage in model:
validates :email, email_domain: { allowed: %w[company.com], message: "must be company email" }
```

## Association Validations

```ruby
validates :organization, presence: true
validates_associated :profile  # Validates the associated record too

# With nested attributes
accepts_nested_attributes_for :addresses, allow_destroy: true
validates :addresses, length: { minimum: 1, message: "must have at least one address" }
```

## Database-Level Constraints

Always pair validations with database constraints:

```ruby
# Migration
add_column :users, :email, :string, null: false
add_index :users, :email, unique: true
add_check_constraint :users, 'age >= 0', name: 'age_non_negative'

# Model
validates :email, presence: true, uniqueness: true
validates :age, numericality: { greater_than_or_equal_to: 0 }
```

## Common Email Regex Patterns

```ruby
# Simple (recommended for most cases)
URI::MailTo::EMAIL_REGEXP

# More permissive
/\A[^@\s]+@[^@\s]+\z/

# Strict RFC 5322
/\A(?=[a-z0-9@.!#$%&'*+\/=?^_'{|}~-]{6,254}\z).../ # (very long)
```

## Performance Tips

1. **Order validations by cost**: Put cheap validations first
2. **Use `on:` to skip validations**: Don't validate password on every save
3. **Avoid N+1 in custom validations**: Cache lookups
4. **Use database constraints**: They're faster than Rails validations
