---
name: plan-artifact
argument-hint: <plan-file>
description: Creates one polished, self-contained HTML artifact from a plan, PRD, roadmap, strategy, migration, rollout, research, operations, or implementation proposal. Use when the user asks for a visual plan explanation, walkthrough, artifact, or presentation.
---

# Presenting Plans

Create one unique, self-contained HTML artifact that helps the plan's intended audience understand what is being planned, why it matters, how it will likely unfold, and what decisions or risks remain.

## Input

Plan:
$ARGUMENTS

If `$ARGUMENTS` is empty or does not identify a readable local file, ask for the file path and stop.

## Output requirement

Create a single `.html` file inside the `artifacts/` directory in the current working directory.

If `artifacts/` does not exist, create it.

The file must be fully self-contained:

* Include all CSS in a `<style>` tag.
* Include all JavaScript in a `<script>` tag.
* Do not depend on external CDNs, fonts, images, packages, or network requests.
* Use semantic HTML and accessible markup.
* Work by opening the file directly in a browser.

Name the file using a short slug derived from the plan title, for example:

```text
artifacts/plan-artifact-[slug].html
```

If no clear title exists, use:

```text
artifacts/plan-artifact.html
```

Do not overwrite an existing unrelated artifact unless the user explicitly asks. If the target filename exists, choose a clear variant such as `artifacts/plan-artifact-[slug]-v2.html`.

## Core Principles

* Treat the source plan as authoritative.
* Prefer a polished strategy artifact over a raw document dump.
* Adapt the page structure to the plan type instead of forcing every plan into a product-feature template.
* Make the path from current state to target state legible without drowning the page in implementation minutiae.
* Keep the artifact useful when opened directly from disk, without any build step or network.
* Make missing details visible instead of filling gaps with confident guesses.
* The artifact should feel intentionally designed, not templated.
* Avoid generic dashboard filler, decorative-only graphics, excessive cards, repeated section layouts, and one-note color palettes.

## Plan Type Detection

First classify the plan as one or more of these types:

* Product feature / PRD
* Technical implementation
* Migration / rollout
* Operations / incident response
* Research / discovery
* Business / go-to-market
* Organizational / process
* Architecture / platform strategy
* Other

Use the classification to choose the artifact structure, section names, visual models, and level of detail. Label the classification only if it helps the reader.

## Source Parsing

Before writing HTML, identify and separate:

* Plan title and one-sentence purpose.
* Intended audience, stakeholders, users, systems, teams, or surfaces affected.
* Current state, pain points, opportunity, or trigger for the plan.
* Target state, desired outcome, scope, non-goals, constraints, and dependencies.
* Workstreams, components, processes, systems, people, or touchpoints involved.
* Sequence, phases, milestones, rollout, operating model, or decision path.
* Risks, tradeoffs, unknowns, assumptions, and decisions needed.
* Metrics explicitly named in the plan.
* Reasonable inferences that should be labeled as `Inferred`.
* Missing information that belongs in `Open questions`.

## Required Understanding Goals

Every artifact must make these ideas easy to understand, using section names that fit the actual plan:

1. **What is being planned**

   * Plan name
   * One-sentence explanation
   * Intended audience or affected stakeholders
   * Primary outcome or value proposition

2. **Why it matters**

   * Current pain point, trigger, opportunity, or context
   * Expected user, business, technical, operational, or organizational impact

3. **Current state and target state**

   * What exists today
   * What should be true after the plan succeeds
   * Key scope boundaries, non-goals, and constraints

4. **Plan overview**

   * Major workstreams, capabilities, components, activities, or decisions
   * Important dependencies and touchpoints
   * Plain-language explanation with enough detail for the relevant experts

5. **Path or sequence**

   * Timeline, phases, milestones, rollout stages, workflow, journey, or operating cadence
   * Before/after flow when useful
   * Decision points and handoffs

6. **Execution plan**

   * Logical phases, milestones, or work packages
   * Dependencies
   * Risks, unknowns, or decisions needed

7. **Success criteria**

   * Metrics, acceptance criteria, outcomes, checkpoints, or observable signs of success
   * Use only criteria from the plan unless clearly labeled as suggested

8. **Open questions**

   * List unresolved product, design, engineering, analytics, operational, organizational, business, or rollout questions

If a required understanding goal has no source material, keep an appropriate section and clearly state that the plan does not specify it. Do not remove required understanding goals.

## Section Adaptation Guidance

Use plan-specific sections when they improve comprehension:

* Product feature / PRD: problem, users, capabilities, user journey, system touchpoints, launch, metrics.
* Technical implementation: architecture, data flow, APIs, migration steps, dependencies, risks, validation.
* Migration / rollout: current vs target state, cohorts, phases, cutover, rollback, readiness checks.
* Operations / incident response: triggers, roles, escalation paths, runbook flow, communication, recovery criteria.
* Research / discovery: hypotheses, methods, participants or data sources, timeline, decision outputs.
* Business / go-to-market: audience, positioning, channels, launch phases, enablement, success signals.
* Organizational / process: teams, responsibilities, handoffs, governance, cadence, adoption risks.
* Architecture / platform strategy: principles, system map, tradeoffs, dependencies, sequencing, standards.

## Design requirements

Use a modern, clean visual style:

* Responsive layout for desktop and mobile.
* Strong typography using system fonts only.
* Clear color palette defined in CSS variables.
* Cards, badges, callouts, and section anchors.
* A first viewport that immediately communicates the plan, audience, and value.
* Stable dimensions for diagrams, cards, controls, and fixed-format UI elements so text and hover/focus states do not shift the layout.
* No horizontal scrolling on mobile.
* At least one visual representation, such as:

  * timeline
  * architecture map
  * user-flow diagram
  * swimlane
  * dependency graph
  * phased roadmap
  * current-to-target-state comparison
  * decision matrix
  * risk board
  * stakeholder map
  * rollout readiness checklist

Choose the visual model that best explains the actual plan. Use multiple visuals only when they add clarity.

Use the plan's domain to choose the visual language:

* Roadmap or timeline for phased plans.
* System map or dependency graph for technical and architecture plans.
* Swimlane or process map for operational and organizational plans.
* Decision matrix for tradeoff-heavy plans.
* Risk board for uncertain or high-risk plans.
* Current-to-target comparison for transformation and migration plans.

Use JavaScript only when it improves comprehension, such as:

* collapsible detail sections
* tabbed views
* section navigation
* simple filtering
* progress/timeline interaction

Do not add JavaScript for decoration alone.

## Accessibility and standalone requirements

* Use semantic landmarks such as `header`, `nav`, `main`, `section`, and `article`.
* Include meaningful headings, labels, visible focus states, and keyboard-accessible interactive controls.
* If tabs or custom controls are used, include appropriate ARIA roles and keyboard behavior.
* Use sufficient color contrast and do not rely on color alone to communicate meaning.
* Include all CSS in one `<style>` tag.
* Include all JavaScript in one `<script>` tag.
* Do not use external fonts, images, scripts, stylesheets, CDNs, analytics, package imports, or network requests.

## Content rules

* Preserve the meaning of the original plan.
* Do not invent requirements.
* When making reasonable inferences, label them as `Inferred`.
* When information is missing, show it under `Open questions` instead of pretending it exists.
* Translate dense details into plain language while keeping enough depth for the relevant expert audience.
* Avoid generic filler. Every section should reflect the supplied plan.
* Use only metrics or success criteria from the plan unless clearly labeled as `Suggested`.
* Keep suggested success criteria conservative and tied to the plan's stated goals.
* Do not include source-code-level, legal, financial, medical, operational, or organizational details unless the plan names them or they are necessary to explain the path.
* Keep final page copy concise enough to scan.

## Workflow

1. Read the source plan completely.

2. Build a content model:

   * Classify the plan type.
   * Extract explicit facts.
   * List inferred implications.
   * List missing information and open decisions.
   * Decide which required understanding goals need an explicit "not specified" note.

3. Choose the artifact structure:

   * Pick the most useful visual model for the plan.
   * Create a clear page rhythm: hero, anchored sections, diagrams, path or sequence, execution details, questions.
   * Avoid decorative complexity that does not improve comprehension.

4. Create the HTML file:

   * Write clean HTML, CSS, and JavaScript in one file.
   * Ensure the page is readable without scrolling horizontally.
   * Include meaningful headings and accessible labels.
   * Make interactive sections useful even if JavaScript is disabled where practical, for example with `details`/`summary`.

5. Validate the artifact:

   * Confirm it contains no external dependencies.
   * Confirm all required understanding goals are present or intentionally marked as missing.
   * Confirm inferred content is labeled.
   * Confirm suggested success criteria are labeled when the source plan lacks them.
   * Confirm links are internal anchors only unless the plan explicitly requires otherwise.
   * Confirm the page has no horizontal overflow risk from fixed-width elements.
   * Confirm the file opens as standalone HTML.

Use quick local checks where available, for example:

```bash
rg -n "<(link|script|img|iframe|source)|href=|src=|@import|http|cdn|fonts" artifacts/plan-artifact-[slug].html
rg -n "Current|Target|Overview|Path|Execution|Success|Open Questions" artifacts/plan-artifact-[slug].html
```

The first check may show the inline `<script>` tag and internal `href="#..."` anchors. Treat external URLs, external `src`, `@import`, CDN references, and font downloads as failures.

6. Final response:

   * Provide the created path relative to the current working directory, for example `artifacts/plan-artifact-[slug].html`.
   * Summarize the artifact in 2–4 bullets.
   * Mention any important assumptions or missing source details.
   * Mention validation performed, or say what could not be validated.
