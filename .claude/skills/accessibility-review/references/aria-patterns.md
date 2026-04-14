# ARIA Authoring Practices — Rails Recipes

Source of truth: <https://www.w3.org/WAI/ARIA/apg/patterns/>. When HTML alone
suffices, use HTML. Only use ARIA to fill gaps the platform does not provide,
and then implement the pattern **completely** — partial ARIA is worse than none.

General rules:

- Do not override native semantics (`<button role="link">` is broken).
- Every custom widget must be reachable by keyboard with the expected key map.
- Manage `aria-expanded`, `aria-controls`, `aria-selected`, `aria-current`
  dynamically — static markup is almost always wrong.
- Return focus to the invoking element when a transient widget closes.

## 1. Disclosure (Show/Hide)

Use for FAQ rows, collapsible sections, inline "more details".

```erb
<%# app/views/shared/_disclosure.html.erb %>
<div data-controller="disclosure">
  <button type="button"
          data-action="click->disclosure#toggle"
          data-disclosure-target="trigger"
          aria-expanded="false"
          aria-controls="details-<%= id %>">
    Shipping details
  </button>
  <div id="details-<%= id %>" data-disclosure-target="panel" hidden>
    <%= yield %>
  </div>
</div>
```

```js
// app/javascript/controllers/disclosure_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["trigger", "panel"]

  toggle() {
    const open = this.triggerTarget.getAttribute("aria-expanded") === "true"
    this.triggerTarget.setAttribute("aria-expanded", String(!open))
    this.panelTarget.toggleAttribute("hidden", open)
  }
}
```

Keys: Enter / Space toggle. Focus stays on trigger.

## 2. Modal Dialog

Prefer the native `<dialog>` element. It handles focus trap, inert background,
and the Escape key for free in modern browsers.

```erb
<dialog id="confirm-delete"
        data-controller="dialog"
        aria-labelledby="confirm-delete-title"
        aria-describedby="confirm-delete-desc">
  <h2 id="confirm-delete-title">Delete this entity?</h2>
  <p id="confirm-delete-desc">This action cannot be undone.</p>

  <form method="dialog" class="flex gap-2">
    <button value="cancel">Cancel</button>
    <%= button_to "Delete", entity_path(@entity),
          method: :delete, form: { data: { turbo: false } },
          class: "bg-red-600 text-white" %>
  </form>
</dialog>
```

```js
// app/javascript/controllers/dialog_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  open()  { this.element.showModal() }     // traps focus, adds backdrop
  close() { this.element.close() }
}
```

Required behavior (native `<dialog>` covers all four):

1. Focus moves into the dialog on open.
2. Tab cycles within the dialog.
3. Escape closes it.
4. Focus returns to the opener on close.

If you must roll your own, follow the APG Dialog (Modal) pattern end-to-end.

## 3. Menu Button

Use only for a true action menu. A list of links is **not** a menu — it is a
navigation landmark.

```erb
<div data-controller="menu">
  <button type="button"
          data-action="click->menu#toggle keydown.down->menu#openAndFocus"
          data-menu-target="trigger"
          aria-haspopup="menu"
          aria-expanded="false"
          aria-controls="user-menu">
    Account
  </button>

  <ul id="user-menu" role="menu" data-menu-target="list" hidden>
    <li role="none"><a role="menuitem" href="/profile">Profile</a></li>
    <li role="none"><a role="menuitem" href="/settings">Settings</a></li>
    <li role="none">
      <%= button_to "Sign out", session_path, method: :delete,
            form: { role: "none" }, role: "menuitem" %>
    </li>
  </ul>
</div>
```

Key map: Down/Up move between items, Home/End jump to ends, Escape closes,
Tab closes and moves focus forward, Enter/Space activate the item.

## 4. Tabs

```erb
<div data-controller="tabs">
  <div role="tablist" aria-label="Account sections">
    <button role="tab" id="tab-profile"    aria-selected="true"  aria-controls="panel-profile"    tabindex="0"  data-tabs-target="tab">Profile</button>
    <button role="tab" id="tab-security"   aria-selected="false" aria-controls="panel-security"   tabindex="-1" data-tabs-target="tab">Security</button>
    <button role="tab" id="tab-billing"    aria-selected="false" aria-controls="panel-billing"    tabindex="-1" data-tabs-target="tab">Billing</button>
  </div>

  <section role="tabpanel" id="panel-profile"  aria-labelledby="tab-profile"  data-tabs-target="panel"           ><%= render "profile_panel"  %></section>
  <section role="tabpanel" id="panel-security" aria-labelledby="tab-security" data-tabs-target="panel" hidden    ><%= render "security_panel" %></section>
  <section role="tabpanel" id="panel-billing"  aria-labelledby="tab-billing"  data-tabs-target="panel" hidden    ><%= render "billing_panel"  %></section>
</div>
```

Key map (roving `tabindex`): Left/Right or Up/Down move selection, Home/End
jump to ends, Tab moves into the active panel.

## 5. Combobox / Autocomplete

Prefer an HTML `<input list>` with `<datalist>` when the list is static —
browsers handle keyboarding and AT exposure. For dynamic results
(typeahead, Turbo Frame-backed), follow the APG Combobox pattern:

- `role="combobox"` on the input, `aria-expanded`, `aria-controls="listbox-id"`,
  `aria-autocomplete="list"`.
- `role="listbox"` on the result container, `role="option"` on children,
  `aria-selected="true"` on the active option, `aria-activedescendant` on the
  input pointing at the active option id.
- Keys: Down/Up move through options without moving DOM focus, Enter selects,
  Escape closes and restores the typed value.

## 6. Tooltip

Tooltips must not contain interactive content and must be keyboard-reachable.

```erb
<button type="button" aria-describedby="tip-save">Save</button>
<div id="tip-save" role="tooltip" hidden>Saves without publishing.</div>
```

Show on focus and hover; hide on blur, mouseleave, or Escape. Never put a
tooltip on a non-focusable element.

## 7. Toast / Live Region

Do not move focus to a toast. Announce via a live region.

```erb
<div id="flash" role="status" aria-live="polite" aria-atomic="true">
  <%= flash[:notice] %>
</div>
```

For errors that must interrupt (form submission failed): `role="alert"` with
`aria-live="assertive"`. Use sparingly — assertive interrupts the current
screen-reader utterance.

## 8. Accordion

Multiple disclosures grouped under a heading. Each trigger is a `<button>`
inside its heading (`<h3>`), with `aria-expanded` and `aria-controls`.

```erb
<h3>
  <button type="button" aria-expanded="false" aria-controls="acc-panel-1">
    Billing
  </button>
</h3>
<div id="acc-panel-1" role="region" aria-labelledby="acc-header-1" hidden>…</div>
```

## Anti-patterns — do not ship

- `role="button"` on a `<div>` without keydown handlers for Space/Enter.
- `aria-hidden="true"` on a focusable element (traps AT users on invisible
  content).
- `aria-label` that duplicates visible text — screen readers announce the
  label, not both.
- Positive `tabindex` values (`tabindex="5"`). Only `0` and `-1` are correct.
- ARIA states that never change (e.g. hard-coded `aria-expanded="false"`).
