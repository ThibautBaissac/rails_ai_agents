# Screen Reader Testing Playbook

Automated tools catch 30–57% of WCAG issues. The rest require a human with a
screen reader and a keyboard. This playbook is a minimum smoke test before
shipping changed UI.

## When to run

- After any change to forms, modals, menus, tables, flashes, or navigation.
- Before releasing a feature with new ViewComponents or Stimulus controllers.
- After Turbo Drive / Turbo Frame / Turbo Stream logic changes.

## Reader + browser pairs to use

| OS       | Screen reader       | Browser  | Notes                                  |
|----------|---------------------|----------|----------------------------------------|
| Windows  | NVDA (free)         | Firefox  | Closest to real-world usage            |
| Windows  | JAWS (commercial)   | Chrome   | Enterprise target; optional but ideal  |
| macOS    | VoiceOver (built-in)| Safari   | `Cmd+F5` to toggle                      |
| iOS      | VoiceOver           | Safari   | Triple-press side button                |
| Android  | TalkBack            | Chrome   | Accessibility Suite                     |

Test **at least one desktop pair** per change. Test mobile when the feature
targets touch users.

## Starting the screen reader

- **NVDA**: Launch NVDA, `Insert+N` opens menu. Modifier key ("NVDA key") is
  `Insert` or `CapsLock`.
- **VoiceOver (macOS)**: `Cmd+F5`. Modifier key ("VO") is `Ctrl+Option`.
- **JAWS**: Launch JAWS. Modifier key is `Insert`.

## Universal keyboard-only smoke test (no reader required)

Run this first — if it fails, fix before wasting screen-reader time.

1. Unplug/ignore the mouse.
2. Tab from the top of the page. Every interactive element must receive a
   **visible** focus ring in a logical order.
3. Reach each control with `Tab`. `Shift+Tab` must reverse the path exactly.
4. Activate each control with `Enter` (links, buttons, submits) or `Space`
   (buttons, checkboxes).
5. Open each menu / modal / disclosure. Close with `Escape`. Focus must return
   to the element that opened it.
6. Submit a form with errors. You must be able to reach the error from the
   keyboard and understand which field is wrong.
7. Resize the browser to 320 CSS px wide and 200% zoom. Content must reflow
   without horizontal scroll or clipped text (WCAG 1.4.10, 1.4.4).

Failure of any step is a blocker.

## NVDA quick commands

| Action                     | Keys                          |
|----------------------------|-------------------------------|
| Read next / previous item  | `Down` / `Up`                  |
| Next heading               | `H` (`Shift+H` previous)       |
| Next landmark              | `D`                            |
| Next form field            | `F`                            |
| Next button                | `B`                            |
| Next link                  | `K`                            |
| Next table                 | `T`                            |
| Open elements list         | `NVDA+F7`                      |
| Read from here             | `NVDA+Down`                    |
| Stop speech                | `Ctrl`                         |

## VoiceOver quick commands (macOS)

| Action                     | Keys                          |
|----------------------------|-------------------------------|
| Start/stop VoiceOver       | `Cmd+F5`                       |
| Next item                  | `VO+Right`                     |
| Open rotor (headings etc.) | `VO+U`                         |
| Interact with group        | `VO+Shift+Down`                |
| Stop interacting           | `VO+Shift+Up`                  |
| Read from here             | `VO+A`                         |
| Jump to web content        | `VO+U` then select Landmarks   |

## What to listen for

For each changed page, verify the reader announces:

1. **Page load** — page title changes (`document.title`) and reader speaks it.
2. **Landmarks** — the Elements/Rotor list shows `main`, `navigation`,
   `banner`, `contentinfo`, and any `complementary` regions.
3. **Headings** — a single `h1`, nested in order, no skipped levels.
4. **Form fields** — every input announces label + type + state
   ("Email, edit text, required").
5. **Buttons vs links** — controls announce the correct role.
6. **Dynamic updates** — flash toasts, Turbo Stream appends, inline
   validation, and loading states announce via live regions.
7. **Images** — informative images announce meaningful alt text; decorative
   images are silent.
8. **Tables** — data tables announce row/column headers on cell navigation.

## Hotwire-specific checks

- **Turbo Drive navigation**: after a link click, does the reader announce
  the new page's title/heading? If not, add a focus-on-navigate Stimulus
  controller or use `turbo:load` to move focus to `main`.
- **Turbo Frame swap**: focus inside the frame before the swap — is it
  preserved or restored sensibly after?
- **Turbo Stream append/replace**: wrap the target in a live region so
  insertions/updates are announced without stealing focus.
- **Modal opened via Turbo Frame**: confirm the dialog is announced, focus
  moves in, Escape closes, and focus returns to the opener.

## Recording findings

For each issue capture:

- Page / URL
- Component / file path
- Reader + browser pair
- Steps to reproduce
- Expected announcement vs actual
- WCAG success criterion and level (e.g. "2.4.3 Focus Order, Level A")

Feed each item back into the priority table in `SKILL.md`.

## References

- WebAIM — Using NVDA to evaluate web accessibility:
  <https://webaim.org/articles/nvda/>
- WebAIM — Using VoiceOver to evaluate web accessibility:
  <https://webaim.org/articles/voiceover/>
- Deque — Screen reader keyboard shortcuts:
  <https://dequeuniversity.com/screenreaders/>
- WAI — Easy Checks for a first review:
  <https://www.w3.org/WAI/test-evaluate/easy-checks/>
