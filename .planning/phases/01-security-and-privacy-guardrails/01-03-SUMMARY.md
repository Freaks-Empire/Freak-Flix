---
phase: 01-security-and-privacy-guardrails
plan: 03
subsystem: security
tags: [flutter_secure_storage, settings, secrets, tmdb, stash]

requires:
  - phase: 01-security-and-privacy-guardrails
    provides: validation and path-containment hardening from plans 01-01 and 01-02
provides:
  - Secret-at-rest boundary for TMDB and Stash keys via platform secure storage
  - Legacy plaintext key migration during settings load/import
  - Redacted settings/export serialization and regression coverage
affects: [settings, metadata, stashdb, backups]

tech-stack:
  added: []
  patterns: [secure-secret side-channel, metadata-only settings serialization, legacy secret migration]

key-files:
  created:
    - test/security/secret_storage_test.dart
  modified:
    - lib/services/secure_key_service.dart
    - lib/providers/settings_provider.dart
    - lib/models/stash_endpoint.dart
    - lib/widgets/settings/settings_metadata_section.dart
    - lib/widgets/settings/settings_advanced_section.dart

key-decisions:
  - "Use flutter_secure_storage directly and remove custom XOR encryption logic"
  - "Keep Stash endpoint apiKey runtime-only while excluding it from JSON serialization"
  - "Migrate legacy tmdbApiKey and stash apiKey values to secure storage during load/import"

patterns-established:
  - "Secret boundary: JSON stores metadata only; secrets flow through SecureKeyService"
  - "Migration-first loading: absorb legacy plaintext once, then persist scrubbed state"

requirements-completed: [SEC-04]

duration: 5 min
completed: 2026-02-27
---

# Phase 1 Plan 03: Secret Storage Boundary Summary

**Platform-backed secret storage now handles TMDB and Stash credentials while settings/export artifacts persist metadata only with legacy plaintext migration built in.**

## Performance

- **Duration:** 5 min
- **Started:** 2026-02-27T17:06:04Z
- **Completed:** 2026-02-27T17:11:58Z
- **Tasks:** 3
- **Files modified:** 6

## Accomplishments
- Reworked `SecureKeyService` to remove custom encryption and expose deterministic TMDB/per-endpoint Stash key APIs.
- Refactored `SettingsProvider` + `StashEndpoint` serialization so settings JSON omits secret fields while preserving runtime key access.
- Updated settings key-edit flows and added regression tests proving serialized/exported settings never include plaintext secrets.

## Task Commits

Each task was committed atomically:

1. **Task 1: Rework secure key boundary to platform-backed storage only** - `5dd0d3b` (feat)
2. **Task 2: Split settings persistence into non-secret state plus secure secret references** - `25ca411` (feat)
3. **Task 3: Update settings UI wiring and add secret-leak regression tests** - `0063e62` (test)

**Plan metadata:** `PENDING` (docs)

## Files Created/Modified
- `lib/services/secure_key_service.dart` - Simplified secure-storage boundary with TMDB/Stash secret APIs and legacy migration helpers.
- `lib/providers/settings_provider.dart` - Metadata-only persistence, secret migration, and secure runtime hydration.
- `lib/models/stash_endpoint.dart` - Removed secret serialization from endpoint JSON output.
- `lib/widgets/settings/settings_metadata_section.dart` - Routed TMDB edits through secure-storage-backed provider saves during submit/test flow.
- `lib/widgets/settings/settings_advanced_section.dart` - Preserved masked Stash key editing by only replacing secrets when users submit a new key.
- `test/security/secret_storage_test.dart` - Regression checks for redacted settings/export serialization.

## Decisions Made
- Removed DIY key obfuscation and trusted platform keystore/keychain behavior through `flutter_secure_storage`.
- Kept endpoint API keys as runtime fields to avoid breaking existing Stash workflows while preventing JSON persistence.
- Migrated legacy plaintext secrets opportunistically on load/import, then persisted scrubbed settings payloads.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- `flutter analyze` reported existing informational lints in settings widgets (deprecated `activeColor`, const/style suggestions) but no new analyzer errors.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- SEC-04 requirements for secret persistence and export redaction are implemented and verified.
- Ready for `01-04-PLAN.md` (adult-content default-off route/UX gating hardening).

## Self-Check: PASSED

- Found `.planning/phases/01-security-and-privacy-guardrails/01-03-SUMMARY.md`.
- Verified task commits `5dd0d3b`, `25ca411`, and `0063e62` exist.

---
*Phase: 01-security-and-privacy-guardrails*
*Completed: 2026-02-27*
