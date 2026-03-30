---
name: feature-tdd-implementation
description: >-
  Guides Test-Driven Development workflow with Red-Green-Refactor cycle.
  Use when the user wants to implement a feature using TDD, write tests first,
  follow test-driven practices, or mentions red-green-refactor.
argument-hint: "[feature or spec file path]"
---

# TDD Cycle Skill

## Overview

Guides the Red-Green-Refactor TDD cycle: write a failing test describing desired behavior,
implement the minimum code to pass it, then improve the code while keeping tests green.
See `references/testing-patterns.md` for code examples, common patterns, and anti-patterns.

## Test Type Selection

| Test Type | Use For | Location |
|-----------|---------|----------|
| Model spec | Validations, scopes, instance methods | `spec/models/` |
| Request spec | API endpoints, HTTP responses | `spec/requests/` |
| System spec | Full user flows with JavaScript | `spec/system/` |
| Service spec | Business logic, complex operations | `spec/services/` |
| Job spec | Background job behavior | `spec/jobs/` |

## Workflow Steps

1. **Choose Test Type** -- Pick the appropriate spec type from the table above based on what you are testing.
2. **Write Failing Spec (RED)** -- Write a spec that describes the desired behavior. Follow the structure template in the references file.
3. **Verify Failure** -- Run `bundle exec rspec path/to/spec.rb --format documentation`. The spec must fail with a clear message. If it passes immediately, either the behavior already exists or the spec is wrong.
4. **Implement Minimal Code (GREEN)** -- Write the minimum code to make the spec pass. No optimization, no extra edge-case handling, no refactoring yet.
5. **Verify Pass** -- Run the spec again. It must pass. If it fails, read the error, fix the implementation (not the spec unless it was wrong), and re-run.
6. **Refactor** -- Improve the code one change at a time: extract methods, improve naming, remove duplication, simplify logic. Run specs after each change. Undo if specs fail.
7. **Final Verification** -- Run all related specs. All must pass. If any fail, undo recent changes and try a different approach.

## Good Spec Characteristics

- **One behavior per example**: each `it` block tests one thing
- **Clear description**: reads like a sentence with `describe`/`context`
- **Minimal setup**: only create data needed for the specific test
- **Fast execution**: prefer `build` over `create`, mock external services
- **Independent**: tests do not depend on order or shared state

## Refactoring Targets

- Extract methods: long methods into smaller focused methods
- Improve naming: unclear names into intention-revealing names
- Remove duplication: repeated code into shared abstractions
- Simplify logic: complex conditionals into cleaner patterns

## Refactoring Rules

1. Make ONE change at a time
2. Run specs after EACH change
3. If specs fail, undo and try a different approach
4. Stop when code is clean -- do not over-engineer
