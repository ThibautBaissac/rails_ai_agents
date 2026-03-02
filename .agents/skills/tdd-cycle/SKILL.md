---
name: tdd-cycle
description: >-
  Guides Test-Driven Development workflow with Red-Green-Refactor cycle.
  Use when the user wants to implement a feature using TDD, write tests first,
  follow test-driven practices, or mentions red-green-refactor.
license: MIT
compatibility: Ruby 3.3+, Rails 8.1+, RSpec
metadata:
  author: ThibautBaissac
  version: "1.0"
---

# TDD Cycle Skill

## Overview

This skill guides you through the Test-Driven Development cycle:
1. **RED**: Write a failing test that describes desired behavior
2. **GREEN**: Write minimal code to pass the test
3. **REFACTOR**: Improve code while keeping tests green

## Workflow Checklist

Copy and track progress:

```
TDD Progress:
- [ ] Step 1: Understand the requirement
- [ ] Step 2: Choose test type (unit/request/system)
- [ ] Step 3: Write failing spec (RED)
- [ ] Step 4: Verify spec fails correctly
- [ ] Step 5: Implement minimal code (GREEN)
- [ ] Step 6: Verify spec passes
- [ ] Step 7: Refactor if needed
- [ ] Step 8: Verify specs still pass
```

## Step 1: Requirement Analysis

Before writing any code, understand:
- What is the expected input?
- What is the expected output/behavior?
- What are the edge cases?
- What errors should be handled?

Ask clarifying questions if requirements are ambiguous.

## Step 2: Choose Test Type

| Test Type | Use For | Location | Example |
|-----------|---------|----------|---------|
| Model spec | Validations, scopes, instance methods | `spec/models/` | Testing `User#full_name` |
| Request spec | API endpoints, HTTP responses | `spec/requests/` | Testing `POST /api/users` |
| System spec | Full user flows with JavaScript | `spec/system/` | Testing login flow |
| Service spec | Business logic, complex operations | `spec/services/` | Testing `CreateOrderService` |
| Job spec | Background job behavior | `spec/jobs/` | Testing `SendEmailJob` |

## Step 3: Write Failing Spec (RED)

### Spec Structure

```ruby
# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ClassName, type: :spec_type do
  describe '#method_name' do
    subject { described_class.new(args) }

    context 'when condition is met' do
      let(:dependency) { create(:factory) }

      it 'behaves as expected' do
        expect(subject.method_name).to eq(expected_value)
      end
    end

    context 'when edge case' do
      it 'handles gracefully' do
        expect { subject.method_name }.to raise_error(SpecificError)
      end
    end
  end
end
```

### Good Spec Characteristics

- **One behavior per example**: Each `it` block tests one thing
- **Clear description**: Reads like a sentence when combined with `describe`/`context`
- **Minimal setup**: Only create data needed for the specific test
- **Fast execution**: Avoid unnecessary database hits, use `build` over `create` when possible
- **Independent**: Tests don't depend on order or shared state

## Step 4: Verify Failure

Run the spec:
```bash
bundle exec rspec path/to/spec.rb --format documentation
```

The spec MUST fail with a clear message indicating:
- What was expected
- What was received (or that the method/class doesn't exist)
- Why it failed

**Important**: If the spec passes immediately, you're not doing TDD. Either:
- The behavior already exists (check if this is intentional)
- The spec is wrong (not testing what you think)

## Step 5: Implement (GREEN)

Write the MINIMUM code to pass:
- No optimization yet
- No edge case handling (unless that's what you're testing)
- No refactoring
- Just make it work

```ruby
# Start with the simplest thing that could work
def full_name
  "#{first_name} #{last_name}"
end
```

## Step 6: Verify Pass

Run the spec again:
```bash
bundle exec rspec path/to/spec.rb --format documentation
```

It MUST pass. If it fails:
1. Read the error carefully
2. Fix the implementation (not the spec, unless the spec was wrong)
3. Run again

## Step 7: Refactor

Now improve the code while keeping tests green:

### Refactoring Targets
- **Extract methods**: Long methods → smaller focused methods
- **Improve naming**: Unclear names → intention-revealing names
- **Remove duplication**: Repeated code → shared abstractions
- **Simplify logic**: Complex conditionals → cleaner patterns

### Refactoring Rules
1. Make ONE change at a time
2. Run specs after EACH change
3. If specs fail, undo and try different approach
4. Stop when code is clean (don't over-engineer)

## Step 8: Final Verification

Run all related specs:
```bash
bundle exec rspec spec/models/user_spec.rb
```

All specs must pass. If any fail:
- Undo recent changes
- Try a different refactoring approach
- Consider if the failing spec reveals a real bug

## Common Patterns

### Testing Validations

```ruby
describe 'validations' do
  it { is_expected.to validate_presence_of(:email) }
  it { is_expected.to validate_uniqueness_of(:email).case_insensitive }
  it { is_expected.to validate_length_of(:name).is_at_most(100) }
end
```

### Testing Associations

```ruby
describe 'associations' do
  it { is_expected.to belong_to(:organization) }
  it { is_expected.to have_many(:posts).dependent(:destroy) }
end
```

### Testing Scopes

```ruby
describe '.active' do
  let!(:active_user) { create(:user, status: :active) }
  let!(:inactive_user) { create(:user, status: :inactive) }

  it 'returns only active users' do
    expect(User.active).to contain_exactly(active_user)
  end
end
```

### Testing Service Objects

```ruby
describe '#call' do
  subject(:result) { described_class.new.call(params) }

  context 'with valid params' do
    let(:params) { { email: 'test@example.com' } }

    it 'returns success' do
      expect(result).to be_success
    end

    it 'creates a user' do
      expect { result }.to change(User, :count).by(1)
    end
  end

  context 'with invalid params' do
    let(:params) { { email: '' } }

    it 'returns failure' do
      expect(result).to be_failure
    end
  end
end
```

## Anti-Patterns to Avoid

1. **Testing implementation, not behavior**: Test what it does, not how
2. **Too many assertions**: Split into separate examples
3. **Brittle tests**: Don't test exact error messages or timestamps
4. **Slow tests**: Use `build` over `create`, mock external services
5. **Mystery guests**: Make test data explicit, not hidden in factories
