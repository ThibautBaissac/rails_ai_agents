# Common WCAG 2.2 Failures — Expanded Catalog

Beyond the "top offenders" in `SKILL.md`. Each entry: symptom → WCAG SC →
why it fails → Rails/Hotwire remediation.

## Images and media

### Decorative icon announced as "image"
- **SC**: 1.1.1
- **Symptom**: `<%= image_tag "icon.svg" %>` produces `alt="icon.svg"`.
- **Fix**: `<%= image_tag "icon.svg", alt: "" %>` (empty alt) + `role="presentation"` if needed.

### Logo linking home has no name
- **SC**: 2.4.4, 4.1.2
- **Symptom**: `<a href="/"><%= image_tag "logo.svg" %></a>` announces nothing.
- **Fix**: `alt: "Acme — home"` on the image, or `aria-label` on the link.

### Video without captions
- **SC**: 1.2.2
- **Fix**: Provide `<track kind="captions" srclang="en" src="...">` on every `<video>`.

## Structure

### Styled `<div>` used as heading
- **SC**: 1.3.1
- **Fix**: Use `<h1>`–`<h6>`. Style with Tailwind utilities, not tag choice.

### Skipped heading levels
- **SC**: 1.3.1, 2.4.6
- **Symptom**: `<h1>` → `<h4>`.
- **Fix**: Keep levels contiguous within a landmark.

### Multiple `<h1>` or no `<h1>`
- **SC**: 2.4.6
- **Fix**: One `<h1>` per page, set per-view via `content_for :title` + a visible `<h1>` in the template.

### Layout tables
- **SC**: 1.3.1
- **Fix**: Use CSS grid / flex, not `<table>` for layout. Reserve tables for data.

### Data table without headers
- **SC**: 1.3.1
- **Fix**: `<th scope="col">` / `<th scope="row">`. For complex tables, `id`/`headers`.

## Forms

### Placeholder used as label
- **SC**: 3.3.2, 1.3.1, 4.1.2
- **Why**: Placeholder disappears on typing, has weak contrast, is ignored by some AT.
- **Fix**: Always pair `<%= f.label :email %>` with the input.

### Label not associated with input
- **SC**: 1.3.1, 4.1.2
- **Symptom**: `<label>Email</label><input>` with no `for`/`id` link.
- **Fix**: Use Rails form helpers (`f.label` + `f.email_field`) — they wire `for`/`id` automatically.

### Grouped radios / checkboxes without `<fieldset>`
- **SC**: 1.3.1
- **Fix**:
  ```erb
  <fieldset>
    <legend>Notification frequency</legend>
    <%= f.collection_radio_buttons :frequency, Frequencies.all, :id, :name %>
  </fieldset>
  ```

### Required field not announced
- **SC**: 3.3.2, 4.1.2
- **Fix**: Use HTML `required` (screen readers announce it) and visible "*".

### Autocomplete missing
- **SC**: 1.3.5
- **Fix**: `autocomplete: "email"`, `"current-password"`, `"street-address"`, etc.

### Errors unreachable
- **SC**: 3.3.1, 3.3.3
- **Fix**:
  ```erb
  <%= f.email_field :email,
        "aria-invalid": user.errors[:email].any?,
        "aria-describedby": ("email-err" if user.errors[:email].any?) %>
  <% if user.errors[:email].any? %>
    <p id="email-err" role="alert"><%= user.errors[:email].to_sentence %></p>
  <% end %>
  ```
  Move focus to the first invalid field after submit.

## Interaction

### `<div>` with click handler
- **SC**: 2.1.1, 4.1.2
- **Fix**: Use `<button type="button">`. If you *must* keep a `<div>`, add `role="button"`, `tabindex="0"`, and key handlers for Enter and Space.

### Submit rendered as `<a>`
- **SC**: 4.1.2
- **Fix**: `button_to` for destructive/action links, `link_to` only for navigation.

### Focus indicator removed
- **SC**: 2.4.7, 1.4.11
- **Symptom**: `outline: none` or Tailwind `focus:outline-none` without a replacement.
- **Fix**: Add `focus-visible:ring-2 focus-visible:ring-blue-600 focus-visible:ring-offset-2` (contrast ≥ 3:1).

### Tab order broken by positive `tabindex`
- **SC**: 2.4.3
- **Fix**: Only use `tabindex="0"` (include) or `tabindex="-1"` (programmatic focus only). Never positive values.

### Keyboard trap in custom widget
- **SC**: 2.1.2
- **Fix**: Custom modals/menus must cycle Tab within the widget **and** allow Escape to exit.

## Color and contrast

### Gray text on white
- **SC**: 1.4.3
- **Bad**: `text-gray-400` (≈ 2.8:1).
- **Good**: `text-gray-600` (≈ 4.7:1). Use a contrast checker.

### Link distinguished only by color
- **SC**: 1.4.1
- **Fix**: Underline links in prose, or add another visual cue.

### Placeholder text too light
- **SC**: 1.4.3
- **Fix**: Placeholder contrast ≥ 4.5:1 if it conveys info (but don't use it for labels).

### Focus ring too faint
- **SC**: 1.4.11, 2.4.7
- **Fix**: Ring color ≥ 3:1 against both the button background and the page background.

## Hotwire / Turbo / Stimulus

### Turbo Drive navigation does not announce new page
- **SC**: 2.4.3, 4.1.3
- **Fix**: Listen for `turbo:load`, move focus to `<main>` or `<h1>`, or announce via a polite live region.

### Turbo Frame swap loses focus
- **SC**: 2.4.3
- **Fix**: Before the swap, capture `document.activeElement`; after `turbo:frame-load`, restore focus or move to a sensible element within the new frame.

### Turbo Stream replace interrupts screen reader
- **SC**: 4.1.3
- **Fix**: Wrap the replaced element in a region with `aria-live="polite"` so updates are announced without stealing focus.

### Modal Turbo Frame without focus trap
- **SC**: 2.1.2, 2.4.3
- **Fix**: Use native `<dialog>` + `showModal()`. It traps focus, closes on Escape, and restores focus on close.

### Flash toast appears silently
- **SC**: 4.1.3
- **Fix**: Render flash container with `role="status" aria-live="polite" aria-atomic="true"`.

### Stimulus toggle without `aria-expanded`
- **SC**: 4.1.2
- **Fix**: Update `aria-expanded` alongside the visual state in the controller action.

## ViewComponent-specific

### Icon-only button lacks label
- **SC**: 4.1.2, 2.5.3
- **Fix**: `<button aria-label="Close"><%= icon "x" %></button>` or a visually-hidden `<span class="sr-only">Close</span>`.

### Component hides content with `display: none` but AT still sees it
- **SC**: 4.1.2
- **Fix**: Use the `hidden` attribute (or `display: none`) — both hide from AT. Avoid `visibility: hidden` for transient states that must be announced.

### Preview lacks an accessibility assertion
- **SC**: process gap
- **Fix**: Every component preview ships an RSpec system spec with `be_axe_clean`.

## Motion and preferences

### Animation ignores `prefers-reduced-motion`
- **SC**: 2.3.3
- **Fix**:
  ```css
  @media (prefers-reduced-motion: reduce) {
    *, *::before, *::after { animation: none !important; transition: none !important; }
  }
  ```

### Autoplaying carousel with no pause
- **SC**: 2.2.2
- **Fix**: Add a visible pause/play button; do not autoplay when the user has `prefers-reduced-motion: reduce`.

## Authentication (new in 2.2)

### CAPTCHA that requires puzzle-solving
- **SC**: 3.3.8
- **Fix**: Offer a non-cognitive alternative (email link, passkey, device trust).

### Login requires transcribing a code from another app without paste
- **SC**: 3.3.8
- **Fix**: Allow paste, or use WebAuthn / passkeys.
