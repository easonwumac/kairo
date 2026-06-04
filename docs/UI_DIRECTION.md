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

## Next UI stages

1. Memory Center
   - Continue improving record cards with source, freshness, and actions
     without making every record feel equal.

2. Phone Tools and Skill Manager
   - Continue tuning skill cards so install/update/enable actions are easier
     to scan without reading every metadata line.

3. Workflows
   - Convert recipe/demo/template sections into a guided workflow gallery.
   - Put preview/run/toggle into a consistent review-first card pattern.

4. AI Setup and Settings
   - Separate everyday routing status from advanced model management.
   - Make local/cloud/private routing understandable from Chat first.

5. Action Preview
   - Turn the sheet into a clearer review checklist:
     destination, payload, risk, permission, and confirmation.

## What to avoid

- Long explanatory blocks on first-level screens.
- Tables or list sections that expose every capability at once.
- Demo labels, mock-only emphasis, or developer metadata in the main path.
- New Shortcut nodes, new surfaces, widgets, keyboard extension, CarPlay, or
  extra OAuth providers unless product scope is explicitly reopened.
