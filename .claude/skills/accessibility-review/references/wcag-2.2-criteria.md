# WCAG 2.2 Success Criteria — Quick Reference (with Rails notes)

All 87 success criteria, grouped by POUR principle. Level column: **A**
(mandatory), **AA** (compliance target — this is what you audit for), **AAA**
(aspirational). Criteria **new in 2.2** are marked 🆕.

Authoritative text: <https://www.w3.org/TR/WCAG22/>.
Techniques & failures: <https://www.w3.org/WAI/WCAG22/Techniques/>.

## 1. Perceivable

| SC      | Title                              | L  | Rails/Hotwire note |
|---------|------------------------------------|----|--------------------|
| 1.1.1   | Non-text Content                   | A  | Every `image_tag` needs `alt`; `alt=""` for decorative. |
| 1.2.1   | Audio-only / Video-only (Prerec.)  | A  | Supply transcript / alt media. |
| 1.2.2   | Captions (Prerecorded)             | A  | `.vtt` captions on `<video>`. |
| 1.2.3   | Audio Description or Media Alt.    | A  | Transcript or audio description track. |
| 1.2.4   | Captions (Live)                    | AA | Required for Action Cable video streams. |
| 1.2.5   | Audio Description (Prerecorded)    | AA | |
| 1.2.6   | Sign Language (Prerecorded)        | AAA| |
| 1.2.7   | Extended Audio Description         | AAA| |
| 1.2.8   | Media Alternative (Prerecorded)    | AAA| |
| 1.2.9   | Audio-only (Live)                  | AAA| |
| 1.3.1   | Info and Relationships             | A  | Use `<h1>`–`<h6>`, `<ul>`, `<th scope>`, `<fieldset>`/`<legend>`. |
| 1.3.2   | Meaningful Sequence                | A  | DOM order matches visual order. |
| 1.3.3   | Sensory Characteristics            | A  | "Click the blue button" is not enough — add text. |
| 1.3.4   | Orientation                        | AA | No `@media (orientation: portrait)` locks. |
| 1.3.5   | Identify Input Purpose             | AA | `autocomplete="email"`, `"name"`, `"street-address"` etc. |
| 1.3.6   | Identify Purpose                   | AAA| |
| 1.4.1   | Use of Color                       | A  | Error states need icon or text, not red alone. |
| 1.4.2   | Audio Control                      | A  | Autoplaying audio > 3s must be stoppable. |
| 1.4.3   | Contrast (Minimum)                 | AA | 4.5:1 body, 3:1 large/bold. **Most common failure.** |
| 1.4.4   | Resize Text                        | AA | Zoom to 200% without loss. Avoid `px` for font size. |
| 1.4.5   | Images of Text                     | AA | Use real text; SVG with `<text>` ok. |
| 1.4.6   | Contrast (Enhanced)                | AAA| 7:1 body. |
| 1.4.7   | Low or No Background Audio         | AAA| |
| 1.4.8   | Visual Presentation                | AAA| |
| 1.4.9   | Images of Text (No Exception)      | AAA| |
| 1.4.10  | Reflow                             | AA | 320 CSS px wide, no horizontal scroll (except maps, tables). |
| 1.4.11  | Non-text Contrast                  | AA | 3:1 for focus rings, input borders, icon buttons. |
| 1.4.12  | Text Spacing                       | AA | User can override line-height / spacing without loss. |
| 1.4.13  | Content on Hover or Focus          | AA | Tooltips dismissible, hoverable, persistent until dismissed. |

## 2. Operable

| SC      | Title                              | L  | Rails/Hotwire note |
|---------|------------------------------------|----|--------------------|
| 2.1.1   | Keyboard                           | A  | No `div` click handlers without keydown equivalents. |
| 2.1.2   | No Keyboard Trap                   | A  | Modals must allow Escape / Tab out. |
| 2.1.3   | Keyboard (No Exception)            | AAA| |
| 2.1.4   | Character Key Shortcuts            | A  | Any single-key shortcut must be disableable/remappable. |
| 2.2.1   | Timing Adjustable                  | A  | Session timeouts: warn + extend. |
| 2.2.2   | Pause, Stop, Hide                  | A  | Carousels and auto-animations need a pause control. |
| 2.2.3   | No Timing                          | AAA| |
| 2.2.4   | Interruptions                      | AAA| |
| 2.2.5   | Re-authenticating                  | AAA| |
| 2.2.6   | Timeouts                           | AAA| |
| 2.3.1   | Three Flashes or Below             | A  | No strobing content. |
| 2.3.2   | Three Flashes                      | AAA| |
| 2.3.3   | Animation from Interactions        | AAA| Respect `prefers-reduced-motion`. |
| 2.4.1   | Bypass Blocks                      | A  | "Skip to main" link as first focusable element. |
| 2.4.2   | Page Titled                        | A  | Set `<title>` per page (Rails `content_for :title`). |
| 2.4.3   | Focus Order                        | A  | Focus flows match reading order. |
| 2.4.4   | Link Purpose (In Context)          | A  | Avoid bare "click here" links. |
| 2.4.5   | Multiple Ways                      | AA | Nav + search, or sitemap. |
| 2.4.6   | Headings and Labels                | AA | Descriptive, not "Form 1". |
| 2.4.7   | Focus Visible                      | AA | Never `outline: none` without `focus-visible` replacement. |
| 2.4.8   | Location                           | AAA| Breadcrumbs. |
| 2.4.9   | Link Purpose (Link Only)           | AAA| |
| 2.4.10  | Section Headings                   | AAA| |
| 2.4.11🆕| Focus Not Obscured (Minimum)       | AA | Sticky headers must not fully cover focused field. |
| 2.4.12🆕| Focus Not Obscured (Enhanced)      | AAA| Focused element never covered at all. |
| 2.4.13🆕| Focus Appearance                   | AAA| Focus indicator ≥ 2 CSS px, 3:1 contrast. |
| 2.5.1   | Pointer Gestures                   | A  | Provide single-pointer alternative to pinch/swipe. |
| 2.5.2   | Pointer Cancellation               | A  | Activate on `pointerup`, allow abort. |
| 2.5.3   | Label in Name                      | A  | Accessible name must include the visible label text. |
| 2.5.4   | Motion Actuation                   | A  | Shake-to-undo needs an alternative. |
| 2.5.5   | Target Size (Enhanced)             | AAA| 44×44 CSS px. |
| 2.5.6   | Concurrent Input Mechanisms        | AAA| |
| 2.5.7🆕 | Dragging Movements                 | AA | Drag-and-drop needs a click/tap alternative. |
| 2.5.8🆕 | Target Size (Minimum)              | AA | 24×24 CSS px minimum (with spacing exception). |

## 3. Understandable

| SC      | Title                              | L  | Rails/Hotwire note |
|---------|------------------------------------|----|--------------------|
| 3.1.1   | Language of Page                   | A  | `<html lang="en">` in `application.html.erb`. |
| 3.1.2   | Language of Parts                  | AA | `<span lang="fr">bonjour</span>`. |
| 3.1.3–5 | Unusual words / Reading level      | AAA| |
| 3.2.1   | On Focus                           | A  | Focus must not cause unexpected context change. |
| 3.2.2   | On Input                           | A  | Selecting a radio must not auto-submit. |
| 3.2.3   | Consistent Navigation              | AA | Same order on every page. |
| 3.2.4   | Consistent Identification          | AA | Same icon/label for the same action. |
| 3.2.5   | Change on Request                  | AAA| |
| 3.2.6🆕 | Consistent Help                    | A  | Help link in the same place across pages. |
| 3.3.1   | Error Identification               | A  | Errors in text, linked via `aria-describedby`. |
| 3.3.2   | Labels or Instructions             | A  | Never use `placeholder` as label. |
| 3.3.3   | Error Suggestion                   | AA | Suggest a fix when you know one. |
| 3.3.4   | Error Prevention (Legal/Financial) | AA | Review + confirm + reverse. |
| 3.3.5   | Help                               | AAA| |
| 3.3.6   | Error Prevention (All)             | AAA| |
| 3.3.7🆕 | Redundant Entry                    | A  | Re-use previously entered data in the same session. |
| 3.3.8🆕 | Accessible Authentication (Min.)   | AA | No cognitive tests (remember code, transcribe image). |
| 3.3.9🆕 | Accessible Authentication (Enh.)   | AAA| No object recognition either. |

## 4. Robust

| SC      | Title                              | L  | Rails/Hotwire note |
|---------|------------------------------------|----|--------------------|
| 4.1.1   | Parsing                            | — | Obsolete in 2.2 — removed. |
| 4.1.2   | Name, Role, Value                  | A  | Every custom widget exposes them to AT. |
| 4.1.3   | Status Messages                    | AA | `role="status"` / `role="alert"` for Turbo Stream updates. |

## Quick-scan priority for audits

When time is short, focus on the criteria that produce 80% of real-world
blockers:

1. 1.1.1 (images without alt)
2. 1.3.1 (non-semantic headings/lists/tables)
3. 1.4.3 (color contrast)
4. 2.1.1 (keyboard operability)
5. 2.4.4 (meaningful link text)
6. 2.4.7 (focus visibility)
7. 2.4.11 🆕 (focus not obscured)
8. 2.5.8 🆕 (target size)
9. 3.3.1 / 3.3.2 (form labels + errors)
10. 4.1.2 (correct roles on custom widgets)
11. 4.1.3 (live regions for Turbo updates)
