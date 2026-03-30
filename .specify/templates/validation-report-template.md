# Specification Validation Report: [FEATURE NAME]

**Feature Branch**: `[###-feature-name]`
**Validated**: [DATE]
**Spec**: [path to spec.md]

## Coverage Summary

- **Total Requirements**: [count]
- **Covered**: [count] ([percentage]%)
- **Likely Covered**: [count] (AI-inferred, no direct test)
- **Not Covered**: [count]
- **Broken**: [count] (test exists but fails)

**Overall Assessment**: [PASS — all requirements covered | PARTIAL — some gaps exist | FAIL — critical requirements uncovered or broken]

## Requirement Status

<!--
  Status values:
  - COVERED: Direct test match, test passes
  - BROKEN: Direct test match, test fails
  - LIKELY COVERED: AI semantic match found implementing code, but no direct test
  - NOT COVERED: No evidence of implementation found

  Evidence types:
  - Test (pass): RSpec test matched by description or metadata tag, passing
  - Test (fail): RSpec test matched, but failing
  - Convention: Rails file exists at expected path (model, controller, etc.)
  - AI match: LLM found implementing code via semantic search
  - None: No evidence found
-->

| ID | Requirement | Evidence Type | Status | Details |
|----|-------------|--------------|--------|---------|
| FR-001 | [requirement text] | [evidence type] | [status] | [file path or explanation] |

## Coverage by Layer

| Layer | Method | Requirements Matched | Notes |
|-------|--------|---------------------|-------|
| 1 | Structural scan (Rails conventions) | [count] | Entity/file existence |
| 2 | Test coverage mapping (RSpec) | [count] | Description/tag matching |
| 3 | AI semantic analysis | [count] | Confidence-based code search |
| 4 | Acceptance test generation | [count] | On-demand, user-approved |

## Broken Requirements (tests failing)

<!--
  List only requirements where a matching test exists but fails.
  If none, write "None — all matched tests pass."
-->

## Uncovered Requirements

<!--
  List requirements with no implementation evidence.
  Include recommended action for each.
-->

| ID | Requirement | Recommended Action |
|----|-------------|--------------------|
| [ID] | [text] | [Generate acceptance test / Add test coverage / Investigate] |

## Notes

- Layer 1 (structural) and Layer 2 (test mapping) are deterministic and fast
- Layer 3 (AI semantic) is probabilistic — "LIKELY COVERED" means evidence was found but should be verified
- Layer 4 (acceptance test generation) only runs if user opts in
- RSpec metadata tags (`requirement: "FR-001"`) improve Layer 2 precision but are not required
