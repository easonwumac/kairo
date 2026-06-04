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

## Next UI stages

1. Memory Center
   - Continue tuning record actions only after smoke tests show which memory
     states users need to act on most often.

2. Phone Tools and Skill Manager
   - Continue tuning skill cards so install/update/enable actions are easier
     to scan without reading every metadata line.

3. Workflows
   - Continue tightening recipe row actions after runtime smoke tests reveal
     the most common workflow states.

4. AI Setup and Settings
   - Continue moving deep diagnostics behind explicit advanced affordances
     after simulator smoke confirms the new first screen.

5. Action Preview
   - Continue tuning checklist labels after broader smoke coverage shows which
     action types need stronger destination or permission summaries.

## What to avoid

- Long explanatory blocks on first-level screens.
- Tables or list sections that expose every capability at once.
- Demo labels, mock-only emphasis, or developer metadata in the main path.
- New Shortcut nodes, new surfaces, widgets, keyboard extension, CarPlay, or
  extra OAuth providers unless product scope is explicitly reopened.
