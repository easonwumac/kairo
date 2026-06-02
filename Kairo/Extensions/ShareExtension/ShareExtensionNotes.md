# Kairo Share Extension

This directory is the source-first scaffold for the `KairoShareExtension` target declared in `project.yml`.

The extension should collect user-shared text, URLs, files, PDFs, and images, copy security-scoped file data into the App Group container when necessary, and enqueue a `ShareIngestionItem` using `JSONFileShareIngestionQueue`.

The main app imports pending queue items on Chat launch and turns them into chat attachments so the user can review, edit the prompt, and send only after confirmation.

Production wiring checklist:

1. Configure an App Group shared by `KairoApp` and `KairoShareExtension`.
2. Point `KairoPaths` to the App Group container when running in extension/app targets.
3. Use `NSItemProvider` type checks for `public.text`, `public.url`, images, PDFs, and generic files.
4. Copy shared files into the shared container instead of retaining temporary provider URLs.
5. Never execute agent actions from the extension; only enqueue and return control to the user.
