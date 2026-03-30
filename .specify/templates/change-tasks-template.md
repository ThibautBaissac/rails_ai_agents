# Tasks: [CHANGE NAME]

**Input**: Change spec from `/specs/[###-change-name]/spec.md`
**Prerequisites**: spec.md (required)

<!--
  ============================================================================
  IMPORTANT: The tasks below are SAMPLE TASKS for illustration purposes only.

  The /sdd-change:tasks command MUST replace these with actual tasks
  based on the change spec's Problem, Acceptance Criteria, and Files Affected.

  Rules:
  - 3-8 tasks maximum (if you need more, use the full /sdd:tasks pipeline)
  - Flat sequential list (no phases, no [P] markers, no [US#] labels)
  - Include exact file paths in every task description
  - Always end with a validation task (rspec + rubocop)
  - Execute top to bottom

  DO NOT keep these sample tasks in the generated tasks.md file.
  ============================================================================
-->

## Tasks

- [ ] T001 [Description with exact file path]
- [ ] T002 [Description with exact file path]
- [ ] T003 [Description with exact file path]
- [ ] T004 Run `bundle exec rspec` and `bundle exec rubocop -a` to validate all changes

## Notes

- Execute tasks sequentially (top to bottom)
- Mark completed tasks as `[X]`
- Commit after each logical group of changes
