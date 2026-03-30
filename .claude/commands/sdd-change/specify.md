---
description: Create a lightweight change specification for bug fixes and small features — skips the full SDD ceremony.
handoffs:
  - label: Generate Tasks
    agent: sdd-change:tasks
    prompt: Generate tasks for this change
    send: true
---

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

## Outline

The text the user typed after `/sdd-change:specify` in the triggering message **is** the change description. Do not ask the user to repeat it unless they provided an empty command.

Given that change description, do this:

1. **Generate a concise short name** (2-4 words) for the branch:
   - Analyze the description and extract the most meaningful keywords
   - Use action-noun format (e.g., "fix-login-timeout", "add-csv-export", "update-email-template")
   - Preserve technical terms and acronyms

2. **Create the feature branch** by running the script:

   **Branch numbering mode**: Check if `.specify/init-options.json` exists and read the `branch_numbering` value.
   - If `"timestamp"`, add `--timestamp` to the script invocation
   - If `"sequential"` or absent, do not add any extra flag

   Run: `.specify/scripts/bash/create-new-feature.sh "$ARGUMENTS" --json --short-name "<name>" "<description>"`

   **IMPORTANT**:
   - Do NOT pass `--number` — the script determines the next number automatically
   - Always include `--json` so the output can be parsed reliably
   - You must only ever run this script once per change
   - Parse the JSON output for BRANCH_NAME and SPEC_FILE paths
   - For single quotes in args, use escape syntax: e.g 'I'\''m Groot' (or double-quote if possible)

3. **Load the change-spec template**: Read `.specify/templates/change-spec-template.md` for the required structure.

4. **Load constitution** (if exists): Read `.specify/memory/constitution.md` to respect project principles when filling the spec.

5. **Fill the change spec and overwrite SPEC_FILE** with content based on the change-spec-template structure:

   - **Problem**: 2-3 sentences describing current vs expected behavior. Be specific.
   - **Proposed Change**: What the fix/change looks like from the user's perspective. No implementation details.
   - **Acceptance Criteria**: 1-3 Given/When/Then scenarios. Keep it focused and testable.
   - **Files Likely Affected**: Analyze the codebase to identify specific file paths. Use Glob/Grep if needed.
   - **Assumptions**: Document any best-guess decisions. NO `[NEEDS CLARIFICATION]` markers — make reasonable assumptions and document them here.
   - **Type**: Classify as Bug Fix, Small Feature, or Refactor.

   Note: The script created `spec.md` from the full spec-template. You must **overwrite** it entirely with the lightweight change-spec structure.

6. **Size heuristic check**: After filling the spec, evaluate:
   - If more than 3 acceptance criteria are needed
   - If more than 6 files are likely affected
   - If the problem description exceeds 5 sentences

   If any condition is true, warn: "This change may be complex enough for the full `/sdd:specify` pipeline. Proceed with the lightweight pipeline?" Wait for user confirmation before continuing.

7. **Report completion**:
   - Output the branch name and spec file path
   - Suggest next step: `/sdd-change:tasks`

## Quick Guidelines

- Focus on WHAT is broken and WHAT the fix looks like — not HOW to implement
- Keep it to one page — if it needs more, use the full `/sdd:specify`
- Make decisions, don't defer them — document assumptions instead of asking questions
- No checklists, no quality validation loops, no [NEEDS CLARIFICATION] markers
