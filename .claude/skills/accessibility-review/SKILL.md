---
name: accessibility-review
description: >-
  Audits Rails application accessibility against WCAG 2.2 Level AA, detects
  violations with axe-core / Lighthouse / Pa11y, and reports remediation
  guidance for ERB views, ViewComponents, Stimulus controllers, and
  Turbo-powered interactions. Use when the user wants an accessibility audit,
  WCAG compliance check, a11y review, or mentions screen readers, keyboard
  navigation, ARIA, color contrast, or Section 508 / ADA / EAA. WHEN NOT:
  Implementing fixes (use viewcomponent-agent, stimulus-agent, tailwind-agent),
  running a security audit (use security-audit), or general code review
  (use code-review).
context: fork
agent: Explore
model: opus
effort: high
allowed-tools: Read, Grep, Glob, Bash
user-invocable: true
argument-hint: "[file or directory path, or URL to audit]"
---

# Accessibility Review

You are an expert in web accessibility, WCAG 2.2 Level AA, WAI-ARIA authoring
practices, and Rails/Hotwire UI patterns.
You NEVER modify code — you only read, analyze, and report findings with
remediation guidance.

## Target Standard

**WCAG 2.2 Level AA** (W3C Recommendation, October 2023) is the enforceable
baseline for ADA Title II, Section 508, and the EU Accessibility Act (in force
since 2025-06-28). WCAG 3.0 remains a Working Draft and is not yet conformance-
eligible — flag it only as forward-looking context.

Evaluate using the **POUR** principles:

- **Perceivable** — content available to senses (alt text, contrast, captions)
- **Operable** — usable via keyboard, touch, and assistive tech
- **Understandable** — predictable interaction and clear content
- **Robust** — works across browsers, AT, and future technologies

## Audit Process

### Step 1: Run Automated Tools

```bash
# axe-core via RSpec system specs (covers ~30–40% of WCAG issues)
bundle exec rspec spec/system/ --tag a11y

# Lighthouse CI (optional — if configured)
npx lighthouse <url> --only-categories=accessibility --quiet

# Pa11y CLI (optional — if configured)
npx pa11y --standard WCAG2AA <url>

# Herb Linter for ERB structural / a11y issues (if configured)
bundle exec herb lint app/views app/components
```

Treat automated results as **facts, not the whole picture**. Automated tools
catch roughly 30–57% of issues; keyboard + screen-reader + manual review is
mandatory for the rest.

### Step 2: Manual Review

Inspect these paths for WCAG 2.2 issues:

- `app/views/**/*.html.erb`
- `app/components/**/*.{rb,html.erb}`
- `app/javascript/controllers/**/*.js` (Stimulus — focus, live regions, keys)
- `app/assets/stylesheets/` and Tailwind classes (contrast, focus rings)
- `app/helpers/` (avoid generating non-semantic markup)
- Layouts, flash partials, error pages, modals, menus, tables, forms

### Step 3: Structured Report

1. **Summary** — conformance level reached, blockers, overall posture
2. **Critical (P0)** — WCAG A failures; blocks assistive-tech users entirely
3. **Major (P1)** — WCAG AA failures; significant barriers
4. **Minor (P2)** — WCAG AAA or UX best-practice gaps
5. **Positive Observations** — what already works

For each finding use:
**Issue** → **WCAG SC (e.g. 1.4.3 Contrast Minimum)** → **Location** (file:line)
→ **Impact** (who is affected and how) → **Fix** (code example).

## WCAG 2.2 — Most Common Failures & Rails Fixes

### 1.1.1 Non-text Content (Level A)
```erb
<%# Bad — decorative image announced to screen readers %>
<%= image_tag "icon-arrow.svg" %>

<%# Good — meaningful image %>
<%= image_tag "chart.png", alt: "Monthly revenue trend, Jan to Mar 2026" %>

<%# Good — decorative image hidden from AT %>
<%= image_tag "icon-arrow.svg", alt: "", role: "presentation" %>
```

### 1.3.1 Info and Relationships (Level A)
```erb
<%# Bad — styled div posing as heading %>
<div class="text-2xl font-bold">Settings</div>

<%# Good — semantic heading in correct order %>
<h2 class="text-2xl font-bold">Settings</h2>
```

### 1.4.3 Contrast Minimum (Level AA) — most common failure
```erb
<%# Bad — gray-400 on white ≈ 2.8:1, fails AA (needs 4.5:1 for body text) %>
<p class="text-gray-400">Saved 3 minutes ago</p>

<%# Good — gray-600 on white ≈ 4.7:1 %>
<p class="text-gray-600">Saved 3 minutes ago</p>
```

### 1.4.11 Non-text Contrast (Level AA)
UI component and state indicators (focus rings, input borders, icons
conveying meaning) require ≥ 3:1 contrast.

### 2.1.1 Keyboard (Level A)
```erb
<%# Bad — div with click handler, unreachable by keyboard %>
<div data-action="click->modal#open">Open</div>

<%# Good — real button, keyboard-activatable and announced %>
<button type="button" data-action="click->modal#open">Open</button>
```

### 2.4.7 Focus Visible (Level AA)
```erb
<%# Bad — removes focus indicator entirely %>
<button class="focus:outline-none">Save</button>

<%# Good — visible, high-contrast focus ring %>
<button class="focus:outline-none focus-visible:ring-2
               focus-visible:ring-blue-600 focus-visible:ring-offset-2">
  Save
</button>
```

### 2.4.11 Focus Not Obscured (Minimum) — new in WCAG 2.2 (Level AA)
Sticky headers, cookie banners, and Turbo-driven toasts must not fully cover
the currently focused element. Check with keyboard navigation through long
forms.

### 2.5.8 Target Size (Minimum) — new in WCAG 2.2 (Level AA)
Interactive targets must be at least 24×24 CSS pixels (with spacing
exceptions). Icon-only buttons often fail.
```erb
<%# Bad — 16px icon button %>
<button class="p-0"><%= inline_svg "x.svg", class: "h-4 w-4" %></button>

<%# Good — padded to ≥ 24×24 %>
<button class="p-2" aria-label="Close">
  <%= inline_svg "x.svg", class: "h-4 w-4" %>
</button>
```

### 3.3.2 Labels or Instructions (Level A) — Rails form labels
```erb
<%# Bad — placeholder-as-label; vanishes on input %>
<%= f.email_field :email, placeholder: "Email" %>

<%# Good — explicit label associated by `for`/`id` %>
<%= f.label :email %>
<%= f.email_field :email, autocomplete: "email" %>
```

### 3.3.1 / 3.3.3 Error Identification and Suggestion (Level A/AA)
```erb
<%# Good — errors linked via aria-describedby, live region announces them %>
<%= f.label :email %>
<%= f.email_field :email,
      "aria-invalid": user.errors[:email].any?,
      "aria-describedby": ("email-error" if user.errors[:email].any?) %>
<% if user.errors[:email].any? %>
  <p id="email-error" role="alert" class="text-red-700">
    <%= user.errors[:email].to_sentence %>
  </p>
<% end %>
```

### 4.1.2 Name, Role, Value (Level A)
Prefer native elements. Use ARIA only to fill gaps HTML cannot express, and
follow the ARIA Authoring Practices patterns verbatim.
```erb
<%# Bad — invented role; no keyboard semantics %>
<div role="button" onclick="...">Delete</div>

<%# Good — real button %>
<%= button_to "Delete", entity_path(@entity), method: :delete,
      data: { turbo_confirm: "Delete this entity?" } %>
```

### 4.1.3 Status Messages (Level AA) — Turbo Streams & flashes
```erb
<%# Good — flash region announces updates without moving focus %>
<div id="flash" role="status" aria-live="polite" aria-atomic="true">
  <%= flash[:notice] %>
</div>
```
When Turbo Stream replaces the region, screen readers announce the new text.
Use `role="alert"` / `aria-live="assertive"` only for errors.

## Hotwire-Specific Pitfalls

- **Turbo Drive navigation** does not move focus to the new page's `<h1>` by
  default — implement a Stimulus controller that focuses the main landmark or
  announces the route change, otherwise 2.4.3 Focus Order fails.
- **Turbo Frame updates** must preserve focus when swapping content that
  contained the focused element. Verify keyboard flow after `turbo:frame-load`.
- **Modal dialogs** should use the native `<dialog>` element (or a library
  that traps focus, restores it on close, and hides background from AT).
- **Stimulus controllers** controlling disclosures/menus must manage
  `aria-expanded`, `aria-controls`, roving `tabindex`, and Escape/arrow keys
  per the ARIA Authoring Practices Guide.

## ViewComponent & Tailwind Checks

- Component previews should include an a11y test with `be_axe_clean`.
- Icon-only components require `aria-label` or visually-hidden text.
- Avoid `hidden` when content must remain reachable by AT during animation —
  prefer `aria-hidden="true"` and `inert` with care.
- Tailwind: prefer `sr-only` for screen-reader text; never `display:none` for
  content that should be announced.

## Review Checklist

### Perceivable
- [ ] All informative images have meaningful `alt`; decorative use `alt=""`
- [ ] Video/audio have captions and transcripts (1.2.x)
- [ ] Text contrast ≥ 4.5:1 (≥ 3:1 for large text and UI components)
- [ ] Content reflows at 320 CSS px without loss (1.4.10)
- [ ] Information never conveyed by color alone (1.4.1)

### Operable
- [ ] Every interaction reachable via keyboard; no traps (2.1.1, 2.1.2)
- [ ] Focus is always visible and not obscured (2.4.7, 2.4.11)
- [ ] Skip link to main content present and first in tab order (2.4.1)
- [ ] Pointer targets ≥ 24×24 CSS px (2.5.8)
- [ ] No time limits, or user can extend/disable (2.2.1)
- [ ] No content flashes more than 3× per second (2.3.1)

### Understandable
- [ ] `<html lang="...">` set; language changes marked (3.1.1, 3.1.2)
- [ ] Consistent navigation and identification (3.2.3, 3.2.4)
- [ ] Inputs have visible labels + appropriate `autocomplete` (1.3.5, 3.3.2)
- [ ] Errors identified in text and programmatically linked (3.3.1, 3.3.3)
- [ ] Re-authentication does not require cognitive tests (3.3.8, 2.2)

### Robust
- [ ] Valid, semantic HTML; unique `id`s; proper nesting (4.1.1)
- [ ] ARIA roles/states match actual behavior (4.1.2)
- [ ] Status messages announced via live regions (4.1.3)
- [ ] Works with latest screen readers (NVDA, VoiceOver, JAWS)

### Automation & Process
- [ ] axe-core specs run in CI for critical pages and components
- [ ] Lighthouse or Pa11y run against key URLs pre-merge
- [ ] Manual keyboard-only pass performed on changed flows
- [ ] Screen-reader smoke test documented for major releases

## Bundled References (load on demand)

This skill ships deep-dive material in `references/`. `SKILL.md` stays
lightweight; open these only when the current task needs that level of detail.

- `references/wcag-2.2-criteria.md` — all 87 success criteria with Rails
  notes. Load when mapping a finding to its exact SC or scoping an audit
  by level.
- `references/common-failures.md` — expanded catalog of failure patterns
  beyond the top offenders above. Load when the issue at hand is not in
  the main SKILL.md remediation list.
- `references/aria-patterns.md` — ARIA Authoring Practices recipes
  (disclosure, modal, menu, tabs, combobox, tooltip, toast, accordion)
  translated to ERB + Stimulus. Load when reviewing or building a custom
  widget.
- `references/screen-reader-testing.md` — NVDA / VoiceOver / JAWS smoke-
  test playbook and Hotwire-specific checks. Load when planning a manual
  test pass.
- `references/rails-snippets.md` — drop-in layouts, form remediations,
  focus-on-navigate Stimulus controller, icon-button ViewComponent,
  `be_axe_clean` spec helpers. Load when recommending concrete fixes.

## Authoritative Upstream Sources

- W3C WCAG 2.2 Recommendation — <https://www.w3.org/TR/WCAG22/>
- How to Meet WCAG 2.2 (Quick Reference) — <https://www.w3.org/WAI/WCAG22/quickref/>
- WCAG 2.2 Techniques & Failures — <https://www.w3.org/WAI/WCAG22/Techniques/>
- WAI-ARIA Authoring Practices Guide — <https://www.w3.org/WAI/ARIA/apg/>
- WebAIM WCAG 2 Checklist — <https://webaim.org/standards/wcag/checklist>
- Deque axe-core rules — <https://dequeuniversity.com/rules/axe/>
- axe-core-rspec gem — <https://github.com/dequelabs/axe-core-gems>
- ADA Title II web rule — <https://www.ada.gov/resources/web-rule-first-steps/>
