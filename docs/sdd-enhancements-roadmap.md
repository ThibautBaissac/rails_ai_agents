# SDD Toolkit Enhancement Roadmap

**Created**: 2026-03-29
**Based on**: Deep research into spec-driven development, AI-assisted workflows, requirements engineering, and Claude Code best practices
**Current spec-kit version**: 0.4.3

## Current State

The SDD toolkit is an 8-command pipeline built on spec-kit:

| Command | Purpose |
|---------|---------|
| `sdd:constitution` | Project-level principles (non-negotiable guardrails) |
| `sdd:specify` | Natural language to structured spec (user stories, FRs, acceptance criteria) |
| `sdd:clarify` | Up to 5 targeted Q&A rounds to reduce ambiguity |
| `sdd:plan` | Tech architecture, data models, contracts, Hotwire decision matrix |
| `sdd:tasks` | Dependency-ordered task breakdown by user story |
| `sdd:checklist` | "Unit tests for English" -- validate requirement quality |
| `sdd:analyze` | Cross-artifact consistency analysis (spec vs plan vs tasks) |
| `sdd:implement` | Phase-by-phase TDD execution |

**Strengths**: Well-structured artifact flow, constitution-as-law pattern, checklists that test requirements not implementation, strong Rails-specific conventions, extension hooks system, multi-agent context support.

**Key gap**: The pipeline is linear (specify to implement). After implementation, specs become stale. ThoughtWorks calls this the difference between "Spec-First" (current level) and "Spec-Anchored" (the sweet spot).

---

## Enhancement 1: LessonsLearned.md Feedback Loop [DONE]

**Priority**: 1 (Low effort, High impact -- compounds across every feature)

**Problem**: Each feature starts from scratch. Errors and fixes discovered during implementation are lost in conversation context.

**Research basis**: Red Hat reports 95%+ first-pass implementation accuracy when using a cumulative lessons file.

**Implementation**:

1. Create `.specify/memory/lessons-learned.md` with structured format:

```markdown
# Lessons Learned

## [Feature Branch] - [Date]

### Error: [Brief description]
- **Root Cause**: [What actually went wrong]
- **Fix**: [How it was resolved]
- **Prevention**: [What to do differently next time]
- **Applies to**: [specify|plan|implement|all]
```

2. Modify `sdd:implement` command to:
   - Log errors and their resolutions to lessons-learned.md when tasks fail
   - Format entries with feature branch, date, and applicable phase

3. Modify `sdd:plan` and `sdd:implement` commands to:
   - Load `.specify/memory/lessons-learned.md` as additional context
   - Filter entries by `Applies to` field for relevant phase

**Files to modify**:
- `.specify/memory/lessons-learned.md` (new)
- `.claude/commands/sdd/implement.md` (add context loading step + error logging)
- `.claude/commands/sdd/plan.md` (add context loading step)

---

## Enhancement 2: Lightweight Mode for Small Changes

**Priority**: 2 (Medium effort, High impact -- removes adoption friction)

**Problem**: Same heavy ceremony (full spec, clarify, plan, tasks) for a bug fix and a major feature. Anti-pattern research identifies Problem Scale Mismatch as the #1 adoption killer.

**Research basis**: Kiro's experience showed generating 4 user stories with 16 acceptance criteria for a bug fix is overkill. The Augment Code guide recommends tiered workflows by complexity.

**Implementation**:

1. Add feature size detection to `sdd:specify`:
   - If description < 30 words or matches patterns like "fix", "bug", "patch", "tweak", "update" -> offer lightweight "change spec" template
   - New template: `change-spec-template.md` with sections: Problem, Fix Description, Acceptance Criteria, Files Affected

2. Create a `change-spec-template.md`:

```markdown
# Change Specification: [BRIEF TITLE]

**Branch**: `[###-change-name]`
**Created**: [DATE]
**Type**: [Bug Fix | Small Enhancement | Patch]

## Problem
[What is broken or needs changing]

## Proposed Change
[What the fix or change looks like from the user's perspective]

## Acceptance Criteria
1. **Given** [state], **When** [action], **Then** [outcome]

## Files Likely Affected
- [file path and what changes]

## Assumptions
- [Any assumptions made]
```

3. For lightweight specs, route directly to a minimal task generation (3-5 tasks), skipping `sdd:clarify` and full `sdd:plan`

**Files to create/modify**:
- `.specify/templates/change-spec-template.md` (new)
- `.claude/commands/sdd/specify.md` (add size detection logic)
- Optionally: `.claude/commands/sdd/quick-implement.md` (new, simplified implement for small changes)

---

## Enhancement 3: Claude Code Hooks for Automated Enforcement

**Priority**: 3 (Medium effort, High impact -- makes guardrails unavoidable)

**Problem**: Constitution enforcement is prompt-based (advisory). Agents can ignore or forget constraints during long sessions.

**Research basis**: Van Eyck's guardrails research: "If there's a deterministic tool for the job, don't prompt the model to do the tool's work." Claude Code supports 12 lifecycle hook events with command, prompt, and agent handler types.

**Implementation**:

1. **PreToolUse hook on git commit** -- auto-run linting and tests:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash(git commit:*)",
        "hooks": [
          {
            "type": "command",
            "command": "bundle exec rubocop --force-exclusion $(git diff --cached --name-only --diff-filter=ACM -- '*.rb') 2>/dev/null || true"
          }
        ]
      }
    ]
  }
}
```

2. **PostToolUse hook on Edit/Write** -- auto-lint changed Ruby files:

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "bundle exec rubocop -a --force-exclusion $CLAUDE_FILE_PATH 2>/dev/null || true"
          }
        ]
      }
    ]
  }
}
```

3. **Stop hook** during implementation -- spec-compliance check before agent declares done

**Files to create/modify**:
- `.claude/settings.json` (add hooks configuration)
- Documentation for hook setup

**References**:
- [Claude Code Hooks Guide](https://code.claude.com/docs/en/hooks-guide)
- [All 12 Hook Events](https://www.pixelmojo.io/blogs/claude-code-hooks-production-quality-ci-cd-patterns)

---

## Enhancement 4: Fresh Context Per Task in Implement [DONE]

**Priority**: 4 (Medium effort, High impact -- prevents quality degradation)

**Problem**: Long `sdd:implement` sessions accumulate context, causing "context rot" where later tasks get worse AI output than earlier ones.

**Research basis**: The GSD framework solves this by spawning fresh subagent contexts per task. CodeScene research shows AI "breaks code in 2 of 3 refactoring attempts" when context is bloated.

**Implementation**:

1. Refactor `sdd:implement` to use Claude Code's Agent tool for each task:
   - Each task subagent gets: constitution + relevant spec section + current task description + lessons learned
   - Existing `[P]` parallel markers identify which tasks can be spawned concurrently
   - Parent agent tracks progress and collects results

2. Task execution pattern:

```
For each phase:
  For each task in phase:
    Spawn Agent with:
      - Constitution context
      - Relevant spec section (just the user story this task belongs to)
      - Task description with file paths
      - Lessons learned (filtered by relevance)
    Collect result
    Update tasks.md checkbox
    Run verification (rspec + rubocop)
```

3. Error handling: if a task agent fails, parent agent logs the error to lessons-learned.md and decides whether to retry or halt

**Files to modify**:
- `.claude/commands/sdd/implement.md` (refactor execution loop to use subagents)

---

## Enhancement 5: Post-Implementation Drift Detection (`sdd:validate`)

**Priority**: 5 (Medium effort, High impact -- closes the spec-anchored loop)

**Problem**: After implementation, specs drift from reality. No mechanism detects when implementation diverges from spec promises.

**Research basis**: ThoughtWorks Technology Radar places "Spec-Anchored" (specs synchronized with code throughout lifecycle via automated tests) as the sweet spot for production systems.

**Implementation**:

1. Create new command `.claude/commands/sdd/validate.md`:
   - Load spec.md and extract all FR-### and SC-### identifiers
   - Search codebase for `# Implements FR-###` comment anchors
   - Run the test suite and map pass/fail to spec requirements
   - Report:
     - Requirements with passing tests (covered)
     - Requirements with failing tests (broken)
     - Requirements with no tests (uncovered)
     - Tests with no requirement mapping (orphaned)

2. Add requirement ID anchors convention:
   - Implementation files include `# Implements FR-003` comments
   - Test files include `# Validates SC-001` comments
   - `sdd:implement` auto-generates these anchors when creating code

3. Auto-update spec header after validation:

```markdown
**Implementation Status**: Validated 2026-03-29
**Coverage**: 12/15 requirements covered (80%)
**Branch**: `004-user-auth`
```

**Files to create/modify**:
- `.claude/commands/sdd/validate.md` (new)
- `.claude/commands/sdd/implement.md` (add anchor generation convention)
- `.specify/templates/spec-template.md` (add Implementation Status field)

---

## Enhancement 6: Architectural Constraint Tests (Executable Constitution)

**Priority**: 6 (Low effort, Medium impact -- executable constitution)

**Problem**: Constitution principles (thin controllers, normalization-only callbacks, services for side effects) are enforced by prompting, not by tests. Agents can violate them.

**Research basis**: Spotify uses "Independent Verifiers" that activate based on codebase contents. ArchUnit-style architectural tests encode constraints as executable rules.

**Implementation**:

1. Generate `spec/architecture/constitution_spec.rb`:

```ruby
# frozen_string_literal: true

RSpec.describe "Constitution Compliance" do
  describe "Controllers" do
    it "do not contain business logic" do
      controller_files = Dir.glob("app/controllers/**/*.rb")
      controller_files.each do |file|
        content = File.read(file)
        # Controllers should not define private methods with complex logic
        # They should delegate to services
        expect(content).not_to match(/\bActiveRecord::Base\b/),
          "#{file} contains direct ActiveRecord calls - use a service"
      end
    end
  end

  describe "Model callbacks" do
    it "only use normalization callbacks" do
      model_files = Dir.glob("app/models/**/*.rb")
      allowed_callbacks = %w[before_validation before_save]
      side_effect_callbacks = %w[after_create after_save after_commit
                                  after_update after_destroy]

      model_files.each do |file|
        content = File.read(file)
        side_effect_callbacks.each do |callback|
          expect(content).not_to match(/\b#{callback}\b/),
            "#{file} uses #{callback} - side effects belong in services"
        end
      end
    end
  end

  describe "Services" do
    it "expose a .call class method" do
      service_files = Dir.glob("app/services/**/*.rb")
      service_files.each do |file|
        content = File.read(file)
        expect(content).to match(/def self\.call|def call/),
          "#{file} does not define a .call method"
      end
    end
  end
end
```

2. Add this to `sdd:implement` final phase (Polish) as a validation step
3. Extend patterns as constitution evolves

**Files to create**:
- `spec/architecture/constitution_spec.rb` (new, generated per project)
- `.claude/commands/sdd/implement.md` (add to Polish phase)

---

## Enhancement 7: Traceability Matrix in Analyze

**Priority**: 7 (Low effort, Medium impact -- automated requirement mapping)

**Problem**: `sdd:analyze` does cross-artifact analysis but doesn't produce a reusable traceability artifact.

**Research basis**: AI-powered traceability reduces change impact assessment by 70% (Accenture). Academic research identifies trace matrices as critical for automated traceability.

**Implementation**:

1. Enhance `sdd:analyze` to output `FEATURE_DIR/traceability-matrix.md`:

```markdown
# Traceability Matrix: [Feature Name]

**Generated**: [DATE]

## Requirement to Task Mapping

| Requirement | Description | Task IDs | Status |
|-------------|-------------|----------|--------|
| FR-001 | User can create account | T006, T009, T012 | Covered |
| FR-002 | Validate email format | T007 | Covered |
| SC-001 | Complete checkout < 3min | -- | NOT COVERED |

## Task to File Mapping

| Task ID | Description | Implementation Files | Test Files |
|---------|-------------|---------------------|------------|
| T006 | Create User model | app/models/user.rb | spec/models/user_spec.rb |

## Coverage Summary
- Requirements covered: 12/15 (80%)
- Tasks with no requirement: 2 (T003, T008 - infrastructure)
- Requirements with no task: 3 (SC-001, SC-003, FR-012)
```

2. Optionally add a standalone `sdd:trace` command for post-implementation tracing (requirement -> task -> test -> code)

**Files to modify**:
- `.claude/commands/sdd/analyze.md` (add traceability matrix generation)
- Optionally: `.claude/commands/sdd/trace.md` (new)

---

## Enhancement 8: Decision Log Per Feature

**Priority**: 8 (Low effort, Medium impact -- prevents re-debating)

**Problem**: During planning and implementation, architectural decisions are made but lost in conversation context. Future agents may re-debate settled questions.

**Research basis**: Augment Code identifies decision logging as one of 7 essential sections for AI agent context. Architecture Decision Records (ADRs) are a well-established pattern.

**Implementation**:

1. Add `decisions.md` to the feature artifact set:

```markdown
# Decision Log: [Feature Name]

## DEC-001: [Decision Title]
- **Date**: 2026-03-29
- **Phase**: plan
- **Decision**: [What was decided]
- **Rationale**: [Why this was chosen]
- **Alternatives rejected**: [What else was considered and why not]
- **Consequences**: [What this means for implementation]
```

2. Auto-populate during `sdd:plan` Phase 0 (research consolidation)
3. Update during `sdd:implement` when deviations from plan occur
4. Load as context in future `sdd:implement` tasks to prevent re-debating

**Files to create/modify**:
- `.specify/templates/decisions-template.md` (new)
- `.claude/commands/sdd/plan.md` (auto-generate decisions.md during Phase 0)
- `.claude/commands/sdd/implement.md` (load decisions.md as context, update on deviation)

---

## Enhancement 9: Property-Based Test Extraction from Specs

**Priority**: 9 (High effort, Medium impact -- formal methods bridge)

**Problem**: Standard example-based tests verify specific cases but miss edge cases. Spec acceptance criteria often express universal properties naturally but these aren't systematically exploited.

**Research basis**: Anthropic's PBT agent found valid bugs in NumPy and AWS Lambda with 86% validity. Property-based testing achieves 23-37% gains over standard TDD. Kiro demonstrates that "specification requirements are oftentimes directly expressing properties."

**Implementation**:

1. During `sdd:plan`, scan acceptance criteria for universal quantifiers:
   - "for ANY user..." -> property: forall users, property holds
   - "ALWAYS maintains..." -> invariant property
   - "NEVER allows..." -> negative property
   - "all X must..." -> universal property

2. Generate property specifications in plan.md or a separate `properties.md`:

```markdown
## Extracted Properties

| Source | Property | Type | Test Strategy |
|--------|----------|------|---------------|
| SC-001 | "Any user can complete checkout" | Universal | Property: forall(user), checkout succeeds |
| FR-003 | "Balance never goes negative" | Invariant | Property: after any transaction, balance >= 0 |
| FR-007 | "All emails are unique" | Uniqueness | Property: forall(email), count == 1 |
```

3. During `sdd:implement`, generate property-based tests alongside standard RSpec tests
4. Add optional "System Invariants" section to spec template
5. Teach `sdd:checklist` to flag acceptance criteria with universal quantifiers lacking property tests

**Dependencies**: May need a Ruby property-based testing gem (e.g., `rantly`, `hypothesis-ruby`, or `propcheck`)

**Files to create/modify**:
- `.specify/templates/spec-template.md` (add optional System Invariants section)
- `.claude/commands/sdd/plan.md` (add property extraction step)
- `.claude/commands/sdd/implement.md` (generate property tests)
- `.claude/commands/sdd/checklist.md` (flag ungoverned universal quantifiers)

---

## Enhancement 10: Adversarial Spec Review ("Devil's Advocate" Mode)

**Priority**: 10 (Medium effort, Medium impact -- catches blind spots)

**Problem**: Specs reviewed by the same agent that wrote them have systematic blind spots. Single-perspective review misses security, scalability, and edge-case gaps.

**Research basis**: Multi-Agent Debate (MAD) improves requirement F1-scores from 0.726 to 0.841. An adversarial second agent challenging the spec catches significantly more gaps.

**Implementation**:

1. Create new command `.claude/commands/sdd/review.md`:
   - Load the current spec
   - Spawn a subagent tasked with finding flaws from these perspectives:
     - Security: authentication gaps, data exposure, injection vectors
     - Performance: missing latency targets, unbounded queries, N+1 risks
     - Edge cases: concurrent access, empty states, boundary conditions
     - Scalability: data growth, traffic spikes, resource exhaustion
     - Regulatory: data retention, privacy, compliance gaps

2. Output a structured critique:

```markdown
# Spec Review: [Feature Name]

## Critical Issues (must fix before planning)
- [Issue with specific spec section reference]

## Warnings (should address)
- [Issue with recommendation]

## Observations (consider for future)
- [Low-priority notes]
```

3. Feed critique back into spec refinement (user decides which items to address)

**Files to create**:
- `.claude/commands/sdd/review.md` (new)

---

## Research Sources

- [ThoughtWorks: Spec-Driven Development Unpacking 2025](https://www.thoughtworks.com/en-us/insights/blog/agile-engineering-practices/spec-driven-development-unpacking-2025-new-engineering-practices)
- [GitHub Blog: Spec-Driven Development with AI](https://github.blog/ai-and-ml/generative-ai/spec-driven-development-with-ai-get-started-with-a-new-open-source-toolkit/)
- [Martin Fowler: Understanding SDD - Kiro, Spec-Kit, Tessl](https://martinfowler.com/articles/exploring-gen-ai/sdd-3-tools.html)
- [InfoQ: Spec-Driven Development When Architecture Becomes Executable](https://www.infoq.com/articles/spec-driven-development/)
- [Red Hat: How SDD Improves AI Coding Quality](https://developers.redhat.com/articles/2025/10/22/how-spec-driven-development-improves-ai-coding-quality)
- [Guardrails for Agentic Coding - Van Eyck](https://jvaneyck.wordpress.com/2026/02/22/guardrails-for-agentic-coding-how-to-move-up-the-ladder-without-lowering-your-bar/)
- [CodeScene: Guardrails and Metrics for AI-Assisted Coding](https://codescene.com/blog/implement-guardrails-for-ai-assisted-coding)
- [Addy Osmani: LLM Coding Workflow Going Into 2026](https://addyosmani.com/blog/ai-coding-workflow/)
- [Augment Code: Mastering SDD with Prompted AI Workflows](https://www.augmentcode.com/guides/mastering-spec-driven-development-with-prompted-ai-workflows-a-step-by-step-implementation-guide)
- [Augment Code: Living Specs for AI Agent Development](https://www.augmentcode.com/guides/living-specs-for-ai-agent-development)
- [O'Reilly: How to Write a Good Spec for AI Agents](https://www.oreilly.com/radar/how-to-write-a-good-spec-for-ai-agents/)
- [Spotify: Feedback Loops for Background Coding Agents](https://engineering.atspotify.com/2025/12/feedback-loops-background-coding-agents-part-3/)
- [Kiro: Property-Based Testing and SDD](https://kiro.dev/blog/property-based-testing/)
- [Anthropic Red Team: Property-Based Testing with Claude](https://red.anthropic.com/2026/property-based-testing/)
- [Claude Code Docs: Hooks Guide](https://code.claude.com/docs/en/hooks-guide)
- [SDD Framework Comparison: BMAD vs Spec-Kit vs OpenSpec vs PromptX](https://redreamality.com/blog/-sddbmad-vs-spec-kit-vs-openspec-vs-promptx/)
- [SDD Is Eating Software Engineering: 30+ Frameworks Map](https://medium.com/@visrow/spec-driven-development-is-eating-software-engineering-a-map-of-30-agentic-coding-frameworks-6ac0b5e2b484)
- [AWS: Use of Formal Methods at Amazon Web Services](https://lamport.azurewebsites.net/tla/formal-methods-amazon.pdf)
