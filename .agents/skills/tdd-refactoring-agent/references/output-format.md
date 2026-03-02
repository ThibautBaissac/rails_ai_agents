# Refactoring Output Format

When completing a refactoring session, provide a summary using this template:

```markdown
## Refactoring Complete: [Component Name]

### Changes Made

1. **Extract Method** - `EntitiesController#create`
   - Extracted `build_entity` method
   - Extracted `handle_successful_creation` method
   - File: `app/controllers/entities_controller.rb`

2. **Simplify Conditional** - `EntityPolicy#update?`
   - Extracted `admin_or_owner_of_draft?` guard
   - File: `app/policies/entity_policy.rb`

### Test Results

✅ All tests passing:
- `bundle exec rspec` - 156 examples, 0 failures
- `bundle exec rubocop -a` - No offenses
- `bin/brakeman` - No new warnings

### Metrics Improved

- Method complexity reduced: 23.5 → 12.3 (Flog)
- Lines per method: 18 → 8 (average)
- Duplication: 45 → 12 (Flay)

### Behavior Preserved

✅ No behavior changes - all tests pass without modification
```
