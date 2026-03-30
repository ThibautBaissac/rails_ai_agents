---
description: Execute a small change by processing all tasks sequentially from tasks.md — no subagents, no hooks, no checklists.
---

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

## Outline

1. **Locate feature directory**: Run `.specify/scripts/bash/check-prerequisites.sh --json --paths-only` from repo root. Parse JSON for FEATURE_DIR, FEATURE_SPEC, and TASKS paths. For single quotes in args, use escape syntax: e.g 'I'\''m Groot' (or double-quote if possible).

2. **Validate artifacts exist**:
   - Check that FEATURE_DIR/spec.md exists. If not: "Run `/sdd-change:specify` first."
   - Check that FEATURE_DIR/tasks.md exists. If not: "Run `/sdd-change:tasks` first."

3. **Load context**:
   - **REQUIRED**: Read spec.md (the change spec — Problem, Proposed Change, Acceptance Criteria)
   - **REQUIRED**: Read tasks.md (the flat task list)
   - **IF EXISTS**: Read `.specify/memory/constitution.md` to respect project principles
   - **IF EXISTS**: Read `.specify/memory/lessons-learned.md` — filter to entries tagged `[phase:implement]` or `[phase:all]` and note any relevant to the current change

4. **Execute tasks sequentially**:
   - Parse all uncompleted tasks (`- [ ]` items) from tasks.md
   - For each task:
     - Execute the task as described (create, modify, or update files)
     - Follow Rails conventions and the project's architecture (skinny controllers, services for business logic, normalization-only callbacks)
     - Mark the task as `[X]` in tasks.md immediately after completion
     - Report brief progress: task ID and what was done
   - If a task fails:
     - Provide clear error context (what failed and why)
     - Log the error to `.specify/memory/lessons-learned.md` if it represents a reusable learning (create the file with its standard header if it does not exist)
     - Halt execution and suggest next steps for manual resolution

5. **Final validation**:
   - Run `bundle exec rspec` and report results
   - Run `bundle exec rubocop -a` and report results
   - If either fails: attempt to fix the issues and re-run (max 2 attempts)
   - If still failing after retries: report the remaining issues for manual resolution

6. **Lessons learned capture**:
   - Review the implementation for noteworthy patterns or surprises
   - Present the user with:
     ```
     ## Lessons Learned

     Implementation complete. Any learnings worth recording?

     Suggested based on this session:
     - [1-2 specific observations from the implementation]

     Reply: (1) Accept suggestions, (2) Add your own, (3) Skip
     ```
   - If the user provides input, append entries to `.specify/memory/lessons-learned.md` using the entry format documented in that file
   - If the user skips, proceed without writing
   - Create the file with its standard header if it does not exist

7. **Report completion**:
   - Summary of completed tasks (count and IDs)
   - Test suite results (pass/fail count)
   - Linting results (clean or issues remaining)
