# Beta Hardening Plan Archive

This historical implementation plan has been superseded by the release-blocking sources below:

- `NEXT_STEPS.md`
- `docs/APP_STORE_READINESS.md`
- `docs/REAL_DEVICE_BETA_SIGNOFF.md`
- `docs/APP_STORE_SUBMISSION_CHECKLIST.md`
- `docs/RELEASE_HYGIENE.md`

Do not use the original unchecked checklist as current release status. The beta hardening work has moved into smaller verified commits, and remaining blockers are now tracked only in the release documents above.

Current unresolved blockers remain:

- Real-device beta sign-off is incomplete while all listed physical devices are `unavailable`.
- Permission-denied fallback QA still needs physical-device evidence for Calendar, Reminders, Notifications, and Contacts.
- Production signed skill/model catalogs and public trust-store metadata still need standalone publication.
- iOS production local model inference remains `Planned` until real-device runtime proof exists.

Historical scope preserved for traceability: beta smoke coverage, local model hardening, provider credential safety, release hygiene, and App Review/readiness document alignment.
