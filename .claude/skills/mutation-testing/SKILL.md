---
name: mutation-testing
description: >-
  Run mutant, read mutation reports, fix alive mutations, and verify coverage.
  Use when running mutation testing, responding to alive mutations, or improving
  test quality. Triggers: "mutation testing", "mutant", "alive mutation", "mutation coverage".
  WHEN NOT: Writing tests from scratch (use rspec-agent), fixing failing tests, or general code review.
context: fork
agent: general-purpose
model: sonnet
allowed-tools: Read, Write, Edit, Grep, Glob, Bash
user-invocable: true
argument-hint: "[subject expression, e.g. Entities::CreateService#call]"
---

# Mutation Testing with Mutant

## When to Activate

- The user asks to run mutation testing.
- The user has alive mutations to fix.
- The user asks to verify mutation coverage on a subject.

## When Not to Use

- The task does not involve mutation testing.

## Inputs

- Alive mutation output to act on (paste the `evil:` block).
- Optional: subject expression to scope the run.

## Outputs (Fixed Order)

1. Mutation results (alive count, coverage percentage).
2. Clear action for each alive mutation: add test or simplify code.

---

## Reading Mutation Output

An alive mutation looks like:

```text
evil:YourClass#method:YourClass#method:lib/your_class.rb:42:abc12
@@ -1,3 +1,3 @@
 def method
-  @value >= threshold
+  @value > threshold
 end
```

- `evil` means no test killed this mutation.
- The diff shows original (`-`) and mutated (`+`) code.

---

## Reporting Format (BLUF)

Lead with the verdict — bottom line up front:

**If unkillable:**

> **Unkillable.** Both forms are equivalent because \[reason\].
> Add to ignore list.

**If killable:**

> **Killable.**
>
> **Option A — add test:**
>
> ```diff
> (test diff)
> ```
>
> **Option B — simplify code:**
>
> ```diff
> (source diff)
> ```

Always present both options so the user can choose. Include evidence: if
you cannot think of a test that would kill the mutation, say so — that is
valuable signal toward unkillable.

---

## Usage

### 1. Run Mutant

```bash
bundle exec mutant run --fail-fast
```

When the subject is known, scope the run to avoid testing unrelated subjects:

```bash
bundle exec mutant run --fail-fast 'Entities::CreateService#call'
```

If the command succeeds, coverage is 100% — done.
If it fails, find the `evil:` line in the output — it has the subject
name, file path, and line number. The diff block immediately after shows
the original and mutated code.

### 2. Investigate

Read the source file and existing spec file for the subject.
Ask: **"Is the mutated code acceptable for all valid inputs?"**

### 3. Decide and Act

- **Add a test** when the mutated code is wrong but tests do not prove it.
- **Simplify the code** when the mutated code is correct for all valid inputs.

Do not change both code and tests in the same commit. If both need
changing, commit the test first, then simplify the code in a second commit.

### 4. Re-run and Verify

Re-run mutant (step 1) until 100%. If the same mutation survives after
2 attempts, evaluate whether it is unkillable.

```bash
bundle exec rspec  # full suite must pass
```

### 5. Commit

Follow the project's conventional commits format. The commit body must
explain which mutation survived, why the test kills it or why the
simplification is correct.

---

## Fixing Alive Mutations

### When to Add a Test

Add a test when the mutated code is wrong but the existing tests do not
prove it. The test must pass with the original code and fail with the
mutated code. Common reasons a test is missing:

- Only one value of a boolean/flag is tested — add the other.
- A collection has one element, so `next` and `break` behave the same —
  add a test with multiple elements.
- Two objects return the same value in test data, hiding which one the
  code actually uses — add test data where they differ.
- A method has a default parameter, and all tests pass the argument
  explicitly — add a test that omits the argument.

### When to Simplify Code

Simplify when the mutated code is correct for all valid inputs. Apply the
mutation's change directly to the source code — do not restructure or
rewrite, just accept the mutated form.

Mutant encodes the **principle of least power**: use the most constrained
primitive that satisfies the requirement. When Ruby offers multiple methods
that overlap in behavior but differ in power, mutant replaces the more
powerful one with the less powerful one. If tests still pass, you did not
need the extra power — accept the simpler form.

Before accepting a simplification, verify the mutation preserves behavior
across the method's full input domain and all call sites.

### Simplification Trap: Syntax Rewriting

Do not rewrite code to eliminate a mutation axis without first ensuring the
expression has test coverage. Changing syntax may make the mutation
disappear without proving the code is correct. The correct sequence:

1. Add test coverage for the expression.
2. Apply the simplification mutant suggests.
3. Verify 100% mutation coverage on the subject.

### When a Mutation Is Equivalent

When the original and mutated code produce the same result for all inputs,
the mutation is **equivalent**. Equivalent does NOT mean unkillable.
Ask: does the mutated form use a more constrained primitive? If yes, it IS
the simplification — apply it to the source.

Examples: `method` → `public_method` (restricts to public API),
`kind_of?` → `instance_of?` (restricts to exact class).

A mutation is only **unkillable** when you cannot add a test AND you cannot
apply the mutation to the source.

### When a Mutation Is Unkillable

1. Add the subject to the `ignore` list in `config/mutant.yml` with an
   inline comment explaining why it is unkillable.
2. Do not commit code or test changes for this subject.
3. Report: which mutation survived, why it is equivalent, and what you
   tried before concluding it is unkillable.

Every ignored subject must have a comment. No uncommented entries.

---

## Prepare a Legacy Project (First-Time Setup)

When adding mutant to a project with no ignore list, run mutant once to
find all alive subjects, then seed the ignore list so burn-down can start
from a passing baseline:

```bash
bundle exec mutant run 2>&1 \
  | sed -n 's/^evil:\([A-Za-z][A-Za-z0-9_:]*[#.][^:]*\):.*/\1/p' \
  | LC_ALL=C sort -u \
  || true
```

Add each subject to the `ignore` list in `config/mutant.yml` with
`# legacy baseline`. Then remove one subject at a time and work through
its alive mutations. Commit each fix with the ignore list removal included.

---

## Checklist

- [ ] Each alive mutation has a clear action: add test or simplify code.
- [ ] New tests fail against the mutated code, not just pass against the original.
- [ ] Full RSpec suite passes after each change (`bundle exec rspec`).
- [ ] Each commit touches one subject only.
- [ ] Unkillable mutations are in the ignore list with a comment.
- [ ] Report: which mutation survived, which option was chosen, and why.
