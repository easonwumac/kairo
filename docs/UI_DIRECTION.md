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

Stage 27 makes Chat start-path-first:

- The empty Chat focus panel now presents one primary starting path instead of
  three equally weighted command rows.
- Plan and Reply remain available as compact secondary chips, keeping the
  first screen useful without reading like a feature catalog.
- The review-first promise stays in short supporting copy instead of a separate
  status pill competing with the user's first action.

Stage 28 makes Chat suggestions review-first:

- Proposed action cards no longer lead with generic capability/category labels;
  they now show the action, risk, and Review affordance first.
- Tool candidate cards keep title, review state, and risk on the first layer.
- Long handoff summaries move behind Details, so Chat suggestions read as
  decisions to review instead of implementation explanations.

Stage 29 makes Phone Tools status-first:

- Phone ability rows now keep only tool name, permission status, and Details on
  the first layer.
- Capability descriptions, fallback notes, core labels, and action chips move
  behind each row's Details disclosure.
- Phone Tools now reads more like everyday support for Chat instead of a
  capability inventory, while deeper permission context remains reachable.

Stage 30 makes Skill Manager action-first again:

- Skill rows now keep the first layer to skill name, install state, one primary
  action, and Details.
- Longer summaries, management summary, Disable, Manage, and Remove move behind
  Details so the library does not read like a control table.
- Marketplace updates remain first-level because they are review actions, while
  lower-frequency management stays progressive.

Stage 31 makes Workflows preview-first again:

- Saved workflow rows now keep only title, enabled state, Preview, and More
  actions on the first layer.
- Recipe summary, risk, review status, Run, and Enable/Pause move behind More
  actions so users start by previewing instead of reading a dense recipe brief.
- More-actions controls use an adaptive grid so management buttons remain tidy
  on phone widths.

Stage 32 makes starter models action-first:

- Starter model rows now keep the first layer to model name, install/download
  state, and the primary action.
- Download approval still shows license, storage, manifest, and purpose boundary
  at the moment of consent, but catalog detail text no longer competes with the
  route decision.
- Runtime fit, manifest transparency, speed checks, reply checks, catalog
  source, and cleanup stay behind Advanced diagnostics.

Stage 33 makes cloud key setup status-first:

- Settings connection setup now shows the OpenAI API key card as status plus an
  edit affordance first.
- The SecureField, Save, Dry Run, and Delete controls move behind the API key
  editor disclosure, reducing the form-heavy feel after opening setup.
- Cloud key handling remains testable and Keychain-bound; only presentation
  hierarchy changed.

Stage 34 makes connected accounts status-first:

- OAuth connector rows now keep the first layer to account name, readiness, and
  Details.
- Account data boundary, backend token-exchange notes, Authorize, and Disconnect
  move behind each row's Details disclosure.
- Connected accounts still show the same official OAuth/API boundaries, but
  Settings no longer reads like a connector implementation table.

Stage 35 makes privacy cleanup review-first:

- Privacy cleanup now opens to an audit-log status row instead of immediately
  exposing the destructive Clear Audit Log action.
- Keychain boundary text, audit-log retention detail, and the clear action move
  behind an Audit log cleanup disclosure.
- The destructive action remains reachable and smoke-tested, but Settings reads
  as retention status first, cleanup second.

Stage 36 makes Action Preview outcome-first:

- Action Preview now opens with the concrete next step as the primary object,
  using the draft title, destination, handoff target, or requested action instead
  of leading with review/checklist framing.
- Confirm and Go back sit directly under the outcome so the decision is visible
  before payload and safety disclosures.
- Exact payload, confirmation rules, capability, and rationale remain available
  below the decision path, preserving review safety without making the sheet feel
  like a metadata table.

Stage 37 makes Workflows starter-first:

- Empty Workflows now shows one starter path instead of pairing the starter
  recipe center with a separate empty saved-workflows card.
- The starter action is framed as adding workflows to preview and run, not as a
  sample/demo catalog.
- Once workflows exist, saved workflows return to the first position and the
  starter set becomes a secondary add-more path below them.

Stage 38 makes Access setup details secondary:

- Access overview now opens with the ready tool count as the only first-level
  status, keeping the page focused on tools Chat can actually suggest.
- Review-first, setup-needed, and unavailable counts move behind a Setup details
  disclosure so permission boundaries remain visible without turning the first
  screen into a status dashboard.
- The everyday tool list remains directly under the overview; advanced skill
  library, developer manifest import, and HomeKit previews stay progressive.

Stage 39 makes local model setup starter-led:

- AI setup no longer drops users directly into model rows after the route card;
  the starter model section now names the job as starting with one local model.
- Supporting copy explains that downloads are only for on-device eligible
  prompts, so the section reads like an opt-in product step instead of a model
  catalog.
- Existing model actions, download approval, trimmed catalog note, and advanced
  diagnostics remain unchanged and progressively disclosed.

Stage 40 makes Settings route-first:

- Settings overview now opens with the current answer route as the only
  first-level status, matching the screen's primary job: how Kairo answers.
- Cloud key, connected account count, and local model status move behind Setup
  details so supporting setup no longer competes with the route decision.
- Connection setup, account editing, OAuth details, privacy cleanup, and model
  controls keep their existing progressive disclosures.

Stage 41 makes Memory search-first:

- Memory no longer opens with export and status pills competing with the search
  path.
- Memory count, user-approved status, and export move behind Library details so
  the first layer reads as a context library users can search or add to.
- Record metadata and delete controls remain behind per-record Details, keeping
  lower-frequency management secondary.

Stage 42 makes Workflows action-first:

- Workflows overview no longer opens with saved-count and review-rule pills;
  those status details move behind Workflow details.
- The starter card now places Add Starter Workflows before the internal-recipe
  boundary note, so the empty state leads with the next action.
- Saved workflow rows, preview-first controls, and advanced Shortcut references
  keep their existing progressive disclosure.

Stage 43 makes Chat start with one action:

- The new-chat focus panel now gives the shared-content starter a single primary
  CTA instead of showing three equal starter prompts at once.
- Planning and reply prompts move behind More starts, preserving useful
  shortcuts without making the first screen read like a demo launcher.
- The composer and route controls remain unchanged so the everyday chat path
  stays stable while the first layer gets quieter.

Stage 44 makes Settings connection setup quieter:

- Connection setup no longer shows API key and connected-account pills on the
  first layer; those status details move behind Connection details.
- The setup toggle remains the primary action for editing cloud keys, accounts,
  and privacy controls when setup needs attention.
- Account editing, OAuth connectors, and privacy cleanup keep their existing
  progressive disclosure after the setup section is opened.

Stage 45 makes empty Memory action-only:

- Memory no longer adds a separate "No memories yet" explanation card on the
  first layer when the library is empty; Search and Add context are enough.
- A compact no-results message appears only after an active search has no
  matches, so feedback is tied to the user's action.
- Record details and library export remain progressive, keeping the memory
  surface focused on finding or adding context.

Stage 46 makes navigation product-led:

- The drawer now groups Chat, Memory, and Workflows under Start here so the
  main product path reads as one workflow instead of separate support rooms.
- Phone tools, AI setup, and Settings move together under Setup, making
  configuration secondary to the everyday Chat path.
- Workflows drawer copy now describes reviewed flows instead of recipes, keeping
  the navigation language closer to what users do.

Stage 47 makes Access tools list direct:

- The Access tool list now starts with Everyday tools instead of the more
  abstract Phone abilities label.
- The explanatory footer under that list heading is removed from the first
  layer; the overview already explains that Chat suggests tools only when
  needed.
- Per-tool details, setup status, and advanced skill library controls remain
  progressive and unchanged.

Stage 48 makes Workflows starter action-only:

- The starter workflow and saved workflow sections now open with only their
  section names and primary action/preview path, not explanatory subtitles.
- The internal-recipe boundary and sample-recipe explanation move into Workflow
  details, so safety context remains reachable without making the first layer
  read like setup documentation.
- Advanced Shortcut references and per-recipe More actions remain unchanged and
  progressive.

Stage 49 makes Chat starter terse:

- The empty Chat panel now opens with a title and one primary starter action,
  removing the explanatory subtitle from the first layer.
- The shared-content starter no longer carries a second descriptive line; the
  button title and icon should be enough to choose that path.
- More starts is a compact disclosure label only. Plan and Reply remain
  available after expansion, but the first screen reads less like onboarding
  copy.

Stage 50 makes Settings setup direct and terse:

- Connection setup now opens with the essential setup controls visible by
  default, while still allowing users to collapse the section.
- Connection details is a compact disclosure label on the first layer; setup
  rationale, cloud-key status, and connected-account status appear only after
  expansion.
- The existing API key editor, OAuth connector controls, and privacy cleanup
  stay in the setup section without adding first-layer explanatory copy.

Stage 51 makes Models route-first:

- Models no longer opens with a separate AI engine explainer card and duplicate
  status pills.
- The first card is now the answer route: route preference, current route, and
  selected local model status in one place.
- Starter model rows remain available below the route card, while catalog
  source, runtime fit, manifest details, and the compact setup explanation stay
  behind Advanced diagnostics.

Stage 52 makes Memory search-first again:

- Memory now opens with Find context, then Add context, then records.
- Library details, storage status, and export move below the working memory
  list so they read as support controls instead of the page's main job.
- No memory behavior changes: manual save, search, record details, delete, and
  export remain reachable with the same identifiers.

Stage 53 makes Workflows overview terse:

- Workflows no longer opens with explanatory subtitle copy under the page title.
- Workflow details is now a compact first-layer disclosure label; the workflow
  purpose, saved count, review-first rule, recipe-center rationale, and internal
  recipe boundary appear only after expansion.
- Starter workflows, saved workflow preview, and advanced Shortcut references
  keep their existing progressive paths.

Stage 54 makes Access overview terse:

- Access no longer opens with explanatory subtitle copy under the page title.
- Setup details is now a compact first-layer disclosure label; the tool-use
  boundary, review-first rule, setup-needed count, and unavailable count appear
  only after expansion.
- Everyday tools remain directly below the overview, and advanced skill library
  controls keep their existing progressive path.

Stage 55 makes Models starter action-first:

- The starter model section no longer opens with explanatory subtitle copy.
- Starter rows now follow the answer route as direct download/select actions,
  keeping the Models first layer route-first and action-first.
- The starter purpose boundary and local-download reminder move into Advanced
  diagnostics with the existing catalog and runtime context.

Stage 56 makes Settings route overview terse:

- Settings no longer opens the answer-route card with explanatory subtitle copy.
- Setup details is now a compact first-layer disclosure label; routing rationale,
  cloud key readiness, connected account count, and local model status appear
  only after expansion.
- Connection setup, API key editing, OAuth connector controls, privacy cleanup,
  and model controls keep their existing progressive paths.

Stage 57 makes Memory overview terse:

- Memory no longer opens the library header with explanatory subtitle copy.
- Library details is now a compact first-layer disclosure label; memory purpose,
  library status, user-approved boundary, and export appear only after expansion.
- Find context, Add context, records, per-record Details, Delete, and search
  behavior keep their existing progressive paths.

Stage 58 makes Memory add context action-first:

- Add context no longer shows explanatory detail copy on the first layer.
- Add context now sits before search so the Memory screen opens on the primary
  save action, then search and saved records follow.
- The Add context disclosure opens directly from a compact action row; save
  guidance appears only after expansion next to the input field.
- Search, manual save, record Details, Delete, and export behavior keep their
  existing identifiers and progressive paths.

Stage 59 makes Workflows advanced references quieter:

- Advanced references no longer shows implementation-detail copy on the first
  layer.
- The advanced disclosure is now a compact row with a full-width tap target;
  Shortcut handoff and node-preview guidance appears only after expansion.
- Shortcut templates, demo previews, preview result identifiers, and recipe
  center behavior keep their existing progressive paths.

Stage 60 makes Access skill library quieter:

- Skill library no longer shows management/setup explanation on the first layer.
- The Skill library disclosure is now a compact full-width row; installed skill,
  beta demo, and signed-manifest guidance appears only after expansion.
- Skill Manager, developer setup, HomeKit preview demos, and existing access
  smoke identifiers keep their current progressive paths.

Stage 61 makes Settings OpenAI setup quieter:

- OpenAI no longer shows cloud-model explanatory copy in the section header.
- The OpenAI first layer keeps only API key status and the edit action; cloud
  model guidance appears only when the API key editor is expanded.
- API key field, save, dry-run, delete, status message, and connection setup
  identifiers keep their current progressive paths.

Stage 62 makes Settings connected accounts quieter:

- Connected accounts no longer shows OAuth handoff explanation in the section
  header.
- The first layer keeps only account names, readiness state, and Details; OAuth
  handoff guidance appears only after a connector row is expanded.
- Connector readiness, account boundary details, backend-exchange notes, and
  callback-preview isolation keep their existing identifiers and paths.

Stage 63 makes Workflows advanced groups quieter:

- Shortcut templates and demo previews no longer repeat explanatory subtitles in
  their section headers after Advanced references is expanded.
- The advanced layer now moves directly from the group title into the manual
  approval disclaimer or demo rows, keeping the screen more action/contract
  oriented.
- Shortcut template identifiers, manual install disclaimer, demo contracts, and
  preview sample actions keep their existing paths.

Stage 64 makes Access advanced setup rows quieter:

- Developer setup and HomeKit preview demos no longer show explanatory copy in
  their collapsed disclosure rows.
- The first advanced layer keeps only the compact row titles; setup guidance and
  HomeKit preview boundaries appear after the user expands each row.
- Installed skill rows now expose Manage as a first-layer action, while Details
  keeps descriptive summaries and heavier disable/remove actions behind
  disclosure.
- HomeKit preview demos now appear before the longer skill library inside
  Advanced setup, keeping security-preview examples reachable without scrolling
  through the full catalog first.
- Manifest import, HomeKit demo, preview confirmation, and existing Access smoke
  identifiers keep their current paths.

Stage 65 makes Chat action preview easier to confirm:

- The action preview first layer now keeps the outcome, destination, risk,
  confirmation state, and primary buttons as the visible decision path.
- Payload and safety rows no longer show explanatory copy while collapsed; exact
  payload guidance, capability, and rationale remain available after expansion.
- Confirm/cancel actions, payload details, safety disclosure, and existing chat
  action preview identifiers keep their current paths.

Stage 66 makes empty Workflows action-first:

- Empty Workflows now opens on the starter workflow action instead of the
  explanatory overview.
- Workflow details keeps saved count, review-first state, and the internal
  workflow boundary after expansion without repeating multiple explanatory
  paragraphs.
- Saved workflow lists, recipe preview/run controls, advanced references, and
  existing workflow smoke identifiers keep their current paths.

Stage 67 makes Models diagnostics quieter:

- Advanced diagnostics no longer explains catalog/runtime/manifest checks on
  the collapsed row.
- The Models first layer stays focused on answer route, selected model, and the
  starter model action; troubleshooting context appears only after expansion.
- Route preference, starter model rows, download confirmation, catalog refresh,
  runtime checks, and model diagnostics identifiers keep their current paths.

Stage 68 makes Access expanded layers action-first:

- Access setup details no longer opens with explanatory paragraphs; expansion
  goes directly to review-first, setup-needed, and unavailable status pills.
- Skill library expansion now moves directly into HomeKit previews, skill
  management, and developer setup instead of showing a setup explainer first.
- Capability rows, HomeKit demos, skill manager flows, manifest import, and
  existing Access smoke identifiers keep their current paths.

## Next UI stages

1. Product surface audit
   - Re-scan Chat, Memory, Access, Models, and Settings for remaining
     first-level text blocks, duplicated status rows, or table-like disclosures
     that still compete with the primary product path.

## What to avoid

- Long explanatory blocks on first-level screens.
- Tables or list sections that expose every capability at once.
- Demo labels, mock-only emphasis, or developer metadata in the main path.
- New Shortcut nodes, new surfaces, widgets, keyboard extension, CarPlay, or
  extra OAuth providers unless product scope is explicitly reopened.
