---
phase: 03-onboarding-and-source-setup
plan: 02
subsystem: ui
tags: [onboarding, onedrive, sftp, ftp, webdav, recovery]

# Dependency graph
requires:
  - phase: 02-cross-platform-baseline-and-releases
    provides: stable cross-platform setup flow and connector runtime baselines
provides:
  - onboarding source-connection orchestration with uniform status events
  - source cards for local, OneDrive, SFTP, FTP, and WebDAV onboarding
  - recovery coverage for timeout/cancel/repeated-failure semantics
affects: [phase-03-plan-03, onboarding-wizard, source-checklist]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - orchestration wrapper over existing connector services
    - explicit incomplete mapping for interrupted OneDrive device-code flow
    - escalated troubleshooting guidance after repeated connection failures

key-files:
  created:
    - lib/widgets/onboarding/source_connection_cards.dart
    - test/onboarding/source_connection_recovery_test.dart
    - .planning/phases/03-onboarding-and-source-setup/03-USER-SETUP.md
  modified:
    - lib/services/onboarding_source_connection_service.dart
    - lib/widgets/device_code_dialog.dart
    - lib/widgets/settings/remote_connection_dialog.dart

key-decisions:
  - "Map OneDrive cancel/timeout terminal states to onboarding 'incomplete' to preserve optional source setup behavior."
  - "Use outcome-returning dialog modes for onboarding while preserving existing settings-flow return types."
  - "Keep protocol implementation in existing services and add orchestration callbacks for deterministic, testable status mapping."

patterns-established:
  - "Onboarding connector adapters return OnboardingSourceStatusEvent objects instead of raw connector payloads."
  - "Repeated connection failures escalate from inline guidance to checklist + docs link after three attempts."

requirements-completed: [ONB-02, ONB-03, ONB-04]

# Metrics
duration: 9 min
completed: 2026-03-01
---

# Phase 3 Plan 02: Local/Cloud Source Recovery Summary

**Onboarding source setup now uses a unified orchestration service with explicit connected/incomplete/failed mapping, plus protocol cards and recovery UX for Local, OneDrive, SFTP, FTP, and WebDAV.**

## Performance

- **Duration:** 9 min
- **Started:** 2026-03-01T12:58:19Z
- **Completed:** 2026-03-01T13:07:48Z
- **Tasks:** 3
- **Files modified:** 6

## Accomplishments
- Added `OnboardingSourceConnectionService` orchestration to wrap existing connector entry points and normalize status events.
- Added onboarding source cards with neutral ordering and separate protocol entries for SFTP, FTP, and WebDAV.
- Updated OneDrive device-code dialog and remote connection dialog to return explicit outcomes and surface guided troubleshooting/escalation behavior.
- Added recovery tests covering local success path, OneDrive timeout/cancel incomplete mapping, and repeated-failure escalation.

## Task Commits

Each task was committed atomically:

1. **Task 1: Build onboarding source-connection orchestration service and status mapping** - `33813aa` (feat)
2. **Task 2: Implement onboarding protocol cards and recovery UX behavior** - `d43f8ee` (feat)
3. **Task 3: Add connector recovery tests for local/OneDrive/remote onboarding paths** - `d24557d` (test)

**Plan metadata:** pending

## Files Created/Modified
- `lib/services/onboarding_source_connection_service.dart` - orchestration service with status/event mapping and failure escalation tracking.
- `lib/widgets/onboarding/source_connection_cards.dart` - onboarding cards for local/OneDrive/SFTP/FTP/WebDAV source setup.
- `lib/widgets/device_code_dialog.dart` - explicit OneDrive auth outcomes (connected/cancelled/timed out/failed) plus retry guidance.
- `lib/widgets/settings/remote_connection_dialog.dart` - inline connection error mapping, troubleshooting, escalation, and optional onboarding outcome mode.
- `test/onboarding/source_connection_recovery_test.dart` - coverage for ONB-02/03/04 recovery semantics.
- `.planning/phases/03-onboarding-and-source-setup/03-USER-SETUP.md` - required Microsoft Entra manual setup steps.

## Decisions Made
- Kept connector protocol logic in existing services and introduced orchestration-only wrappers for onboarding semantics.
- Ensured OneDrive cancel/timeout are always represented as `incomplete`, not success and not onboarding blockers.
- Preserved settings dialog behavior while adding onboarding-specific outcome return mode to avoid breaking existing callers.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Decoupled local-source test path from plugin-initialized `LibraryProvider` constructor**
- **Found during:** Task 3 (recovery tests)
- **Issue:** Tests failed because constructing `LibraryProvider` initialized notification plugins outside a bound Flutter test platform.
- **Fix:** Added callback-based local orchestration overrides in `OnboardingSourceConnectionService.connectLocal` and updated tests to use deterministic callback snapshots instead of real provider construction.
- **Files modified:** `lib/services/onboarding_source_connection_service.dart`, `test/onboarding/source_connection_recovery_test.dart`
- **Verification:** `flutter test test/onboarding/source_connection_recovery_test.dart`
- **Committed in:** `d24557d`

---

**Total deviations:** 1 auto-fixed (1 blocking)
**Impact on plan:** Deviation was limited to testability plumbing and did not change user-facing connector behavior.

## Issues Encountered
- `flutter analyze` still reports pre-existing info-level lints in `lib/widgets/settings/remote_connection_dialog.dart` (deprecated `withOpacity` and const suggestions) outside this task's targeted behavior changes.

## Authentication Gates
None.

## User Setup Required

**External services require manual configuration.** See `.planning/phases/03-onboarding-and-source-setup/03-USER-SETUP.md` for:
- Environment variables to add
- Dashboard configuration steps
- Verification commands

## Next Phase Readiness
- ONB-02/03/04 source setup primitives are ready to be wired into the linear onboarding wizard flow in 03-03.
- Checklist/status events are available for resume/review wiring without introducing protocol-specific branching in UI steps.

---
*Phase: 03-onboarding-and-source-setup*
*Completed: 2026-03-01*

## Self-Check: PASSED

- FOUND: `.planning/phases/03-onboarding-and-source-setup/03-02-SUMMARY.md`
- FOUND: `.planning/phases/03-onboarding-and-source-setup/03-USER-SETUP.md`
- FOUND commit: `33813aa`
- FOUND commit: `d43f8ee`
- FOUND commit: `d24557d`
