# Kairo UI Direction

## Product spine

Kairo should feel like a focused phone-agent workspace, not a capability demo.
The first screen should help the user choose one job, review the result, and run
only after confirmation.

The product story is:

1. Bring context into Kairo.
2. Ask Kairo to prepare a concrete next step.
3. Review the draft, risk, and destination.
4. Confirm the action or keep editing in Chat.

## Design principles

- Lead with jobs, not capability inventory.
- Keep Chat as the primary surface.
- Show setup only when it affects the current job.
- Keep safety visible through short status and review states, not long prose.
- Prefer one primary action per surface.
- Move advanced catalogs, manifests, and diagnostics behind progressive disclosure.
- Make Memory, Tools, Workflows, and AI setup feel like supporting rooms around Chat.

## Current stage

Stage 1 gives the app a clearer commercial shell:

- The root header now presents Kairo as the product, with a short operating promise.
- Primary sections are exposed as compact top tabs, so users do not start from a drawer.
- Chat now starts with a focused command panel for the three most common jobs:
  shared-content organization, reminder/calendar planning, and message drafting.
- The design system now has elevated and soft surfaces for a cleaner hierarchy.

This stage does not add new capabilities. It only changes presentation and
entry points for existing behavior.

Stage 2 starts moving support screens from setup-heavy pages toward focused
workspaces:

- Memory Center now leads with search, saved-count status, and export in one
  library header.
- Manual capture remains available, but it is visually secondary to finding
  and reviewing context.
- Memory status is framed around user-approved context instead of a generic
  data table.

Stage 3 refocuses Phone Tools:

- Phone Tools now opens with a status summary instead of a raw capability list.
- Everyday tools are shown first, while signed manifests, marketplace refresh,
  and local skill drafting stay behind an advanced setup disclosure.
- Skill Manager remains available, but reads as a managed tool library rather
  than the whole product.
- HomeKit stays explicitly preview-only and visually separated from everyday
  tools.

Stage 4 turns Workflows into a guided workflow gallery:

- The screen now opens with workflow counts and a review-first safety state.
- Sample recipes come before technical Shortcut demos, so users can create a
  usable workflow path without reading implementation details first.
- Saved recipes use one card pattern for preview, run, and pause actions.
- Shortcut templates and action previews remain available, but are visually
  secondary and explicitly manual.

Stage 5 clarifies AI setup and Settings:

- Settings now starts with how Kairo answers: cloud readiness, route preference,
  connected accounts, and local model state.
- API keys, OAuth connectors, and privacy controls remain available, but they
  support the answer route instead of defining the page.
- AI engine now opens with route and local-model readiness before catalog
  controls, so model downloads feel like an explicit opt-in path.

Stage 6 makes Action Preview a confirmation checklist:

- The sheet now leads with a clear review state instead of treating the payload
  as the whole story.
- Users can scan capability, destination, rationale, and confirmation state
  before reading the detailed payload.
- The payload remains visible, but it is framed as content to review before
  the confirm button.

Stage 7 removes the last native Settings demo form:

- Shortcut demo-only Settings now uses the same focus-card language as the rest
  of the app instead of a `Form` and `Section`.
- Demo input/output contracts remain available for verification, but the page
  reads as a reference gallery rather than a primary workflow.

Stage 8 polishes chat history outside iOS:

- The non-iOS chat history sidebar now uses Kairo cards instead of a native
  `List`, keeping the product language consistent across surfaces.
- Thread selection is still simple, but history reads as saved work rather than
  a default system table.

Stage 9 clarifies the chat route control:

- The composer route bar now reads as two compact controls, Mode and Route,
  instead of a terse technical string separated by punctuation.
- The same menu still owns private chat and route preference, keeping advanced
  routing editable without making Chat feel like a settings page.

Stage 10 improves Skill Manager scanning:

- Skill rows now read as managed cards with status, a compact management
  summary, and a predictable action grid.
- Install, update, enable, disable, manage, and remove remain available, but no
  longer appear as a vertical wall of tiny text buttons.

Stage 11 makes Memory records feel like usable context:

- Saved memories now render as individual cards instead of a divided table.
- Search is its own first-class card between the library status and quick
  capture, making the primary Memory job easier to find.
- Each card leads with the remembered content, then exposes short source,
  freshness, sync, and expiry states.
- Delete remains the only destructive action, so the record list reads as
  context Kairo can use rather than metadata the user must decode.

Stage 12 makes Workflows recipe-first:

- Shortcut templates and node demo previews now live behind an Advanced
  References disclosure instead of competing with saved recipes on first load.
- The first-level Workflows path is now status, sample recipes, and saved
  recipe review cards.
- The Apple Shortcuts boundary remains visible as a short safety status in the
  recipe center, not as a long setup explanation.

Stage 13 makes Settings setup-on-demand:

- Settings now keeps the first level focused on how Kairo answers and whether
  connection setup needs attention.
- API key, OAuth connector, and privacy controls live behind a Connection Setup
  disclosure instead of loading as three full setup sections.
- The same controls and identifiers remain available after expansion, so setup
  workflows stay testable without turning Settings into the product homepage.

Stage 14 makes AI setup route-first:

- AI Setup now opens with answer route, selected model state, and starter model
  actions instead of catalog metadata and dev checks.
- Catalog refresh, manifest transparency, runtime fit, speed tests, reply checks,
  and destructive model cleanup live behind Advanced diagnostics.
- Download approval still shows license, storage, and manifest details at the
  moment of consent, keeping safety visible without making diagnostics the main
  product path.

Stage 15 makes Phone Tools action-first:

- Phone Tools now keeps the first level to Chat-suggested everyday capabilities
  instead of showing skill management and beta demos immediately.
- Skill Manager, marketplace refresh, signed manifest import, local skill drafts,
  and HomeKit preview demos now live inside Skill library.
- Existing controls remain reachable after expansion, but Tools reads as a
  support room for Chat rather than a marketplace or demo console.

Stage 16 makes Action Preview checklist-first:

- Action Preview now keeps capability, destination, reason, risk, and confirmation
  as the first-level decision surface.
- Exact draft or handoff payload details live behind a content details disclosure
  so users are not forced through long fields before confirming.
- Confirm and Go Back remain visible without opening details, preserving the
  review-first safety flow while reducing text overload.

Stage 17 makes Workflows recipe-action-first:

- Workflows no longer promotes Shortcut handoff counts or demo preview counts in
  the overview; the first-level status is saved workflows plus review-first
  safety.
- Empty Workflows now points users to one starter set before asking them to scan
  saved recipes.
- Saved recipe rows lead with title, short summary, risk, and a primary Preview
  action, while Run and Pause stay available as secondary controls.
- Advanced references remain reachable, but implementation catalogs no longer
  compete with the recipe job on first load.

Stage 18 makes root navigation job-first:

- The top navigation strip now only exposes Chat, Memory, and Workflows as
  first-level jobs.
- Phone Tools, AI Setup, and Settings remain available in Sections, but they no
  longer compete with Chat as equal top-level destinations.
- The drawer now labels those destinations as support rooms and setup, matching
  the product spine: ask in Chat, use supporting rooms only when the job needs
  them.

Stage 19 makes Memory capture on-demand:

- Memory Center now keeps search and saved context as the first-level job.
- Manual capture remains available, but it starts behind an Add context
  disclosure instead of presenting a blank input form on first load.
- Saving a memory collapses the capture controls again, returning the screen to
  finding and reviewing usable context.

Stage 20 makes Phone Tools progressive:

- Phone Tools now shows the four most common Chat-support tools first: shared
  context, memory, reminders, and calendar.
- Mail, messages, web, and location stay available behind a More tools
  disclosure instead of making the first level read like a capability inventory.
- Capability rows now carry stable identifiers so future UI smoke can verify
  progressive disclosure behavior without asserting user-facing copy.

Stage 21 makes AI Setup answer-route-first:

- AI Setup now combines route preference and selected local model state into one
  Answer route card instead of showing them as separate settings panels.
- Starter model downloads remain below the route decision, keeping model catalog
  work secondary to how Kairo answers.
- Existing route and selected-model identifiers remain in the card so current
  smoke coverage can continue to target behavior rather than copy.

Stage 22 makes Settings support-first:

- Settings keeps the answer-routing overview and connection setup as the first
  job, while destructive privacy cleanup starts collapsed behind its own
  disclosure.
- Cloud key and OAuth setup remain reachable after opening connection setup, but
  audit-log cleanup no longer appears as an always-visible first-level action.
- The cleanup toggle has a stable identifier so smoke coverage can verify the
  progressive control without asserting layout copy.

Stage 23 makes Skill library rows action-first:

- Skill rows now lead with the skill name, short summary, status, and the
  current primary action instead of exposing every management control at once.
- Management summary, Manage, and Remove now live behind a per-skill Details
  disclosure so destructive or diagnostic controls do not compete with install,
  enable, disable, or update.
- Skill action buttons use an adaptive compact grid so longer labels can wrap
  cleanly on phone widths instead of being squeezed into a single row.

Stage 24 makes Workflows preview-first:

- Saved workflow rows now keep Preview and status as the first-level decision,
  with Run and Enable/Pause moved behind a per-recipe More actions disclosure.
- This reinforces the product rule that workflows are reviewed before execution
  instead of presenting run controls as equally primary.
- Existing run and toggle identifiers stay reachable after expansion so smoke
  tests still verify behavior rather than copy.

Stage 25 makes Action Preview decision-first:

- Action Preview now keeps destination, risk, and confirmation status as the
  first-level review surface.
- Capability and rationale move behind a Safety details disclosure so long
  explanatory text does not compete with the confirm/cancel decision.
- Exact draft or handoff payload details remain separately collapsed, preserving
  review depth without forcing every user through every field.

Stage 26 makes Memory records context-first:

- Saved memory cards now keep title, summary, source, and updated date as the
  first-level scanning surface.
- Lower-frequency metadata such as cloud use and expiry now lives behind a
  per-record Details disclosure.
- Delete moved into Details so the Memory Center reads as a context library
  first, not a table of record-management controls.

## Next UI stages

1. Chat
   - Continue reducing first-level helper copy and make suggested jobs feel like
     one clear starting path before exposing routing or setup details.

2. Phone Tools and Skill Manager
   - Continue tuning skill-card density inside Skill library after simulator
     smoke confirms the new first screen.

3. Workflows
   - Continue tuning saved recipe cards only after runtime smoke confirms the
     new recipe-first order.

4. AI Setup and Settings
   - Continue tightening starter model rows after simulator smoke confirms which
     local-model states users need on the first screen.

5. Action Preview
   - Continue tuning action-specific summaries after smoke coverage shows which
     destination or permission states are still ambiguous.

## What to avoid

- Long explanatory blocks on first-level screens.
- Tables or list sections that expose every capability at once.
- Demo labels, mock-only emphasis, or developer metadata in the main path.
- New Shortcut nodes, new surfaces, widgets, keyboard extension, CarPlay, or
  extra OAuth providers unless product scope is explicitly reopened.
