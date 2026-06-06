# Asset Library Storage

Kairo Library should store user information as inspectable asset nodes, not as one opaque chat log.

## Storage Goals

- Preserve original assets.
- Keep model-generated structure separate from raw resources.
- Support fast search, fuzzy lookup, date filters, type filters, folder filters, and future semantic search.
- Support user-controlled iCloud backup/sync behavior.
- Keep the format portable enough to export or migrate.

## Node Layout

Each user-created folder or InfoPage-backed collection should map to a storage node directory.

```text
Library/
  index.sqlite              # Planned search/index layer
  folders.json              # Small folder metadata fallback / migration helper
  nodes/
    <node-id>/
      node.json             # Node metadata: id, title, type, createdAt, updatedAt, folder policy
      html/
        index.html          # Rendered template snapshot, generated from structured JSON
      json/
        assets.json         # Asset references and extracted text metadata
        info-page.json      # Structured InfoPage content
        actions.json        # Reminder/action drafts and confirmation state
      resources/
        <asset-id>.<ext>    # Original or copied resources when Kairo owns the file
```

## JSON First, HTML As Rendered View

Models should produce structured JSON, not arbitrary UI.

- `json/info-page.json` is the source for facts, timeline, checklist, and reminders.
- `html/index.html` is a rendered template snapshot for fast preview/export.
- `resources/` stores original images, PDFs, or file copies only when Kairo owns the resource.

## Ingestion Decision Flow

Library should not expose raw import/export buttons as the main workflow. Capture starts from Share Extension, Chat input, or App Intent input.

Expected flow:

1. Shared content appears in Chat review.
2. Kairo extracts lightweight metadata and any available text.
3. Kairo queries the Library index for similar assets, folders, and InfoPages.
4. The model receives only the new item plus the retrieved candidates.
5. The model chooses create, merge, ask user, or skip.
6. Kairo saves only after user confirmation unless Settings allows low-risk auto-create.

This keeps Library as the searchable database while Chat handles the ambiguous decision of where new information belongs.

## SQLite Index

SQLite is the likely index layer once Library grows beyond small JSON lists.

Use SQLite for:

- fuzzy search tokens;
- normalized title/summary/extracted text;
- date ranges;
- asset type filters;
- folder/node membership;
- resource references;
- future embedding/vector references if added separately.

Do not use SQLite as the only source of truth for original resources. The node JSON and resources directory must remain exportable.

## iCloud Policy

The user should be able to choose Library backup/sync behavior in Settings.

Initial policy:

- Local only: set `isExcludedFromBackup=true` on Library directories and resource files.
- iCloud backup allowed: clear `isExcludedFromBackup` for Library directories and resource files.

Future policy:

- Per-folder backup/sync control.
- Explicit warning for large screenshots/PDF collections.
- No silent upload of model weights, caches, tokens, or generated credentials.

## Current Implementation State

- Implemented: file-backed `KnowledgeAsset` JSON index.
- Implemented: file-backed `KnowledgeAssetFolder` metadata.
- Implemented: query API for text, type, folder, and date filters.
- Implemented: iCloud backup policy for the current asset index/imported resources.
- Planned: node directory layout with `html/`, `json/`, and `resources/`.
- Planned: SQLite search/index layer.
- Planned: per-folder backup policy.
