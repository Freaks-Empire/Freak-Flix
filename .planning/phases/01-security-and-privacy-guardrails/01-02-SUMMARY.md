---
phase: 01-security-and-privacy-guardrails
plan: 02
subsystem: security
tags: [filesystem, traversal, path, flutter, tests]

# Dependency graph
requires:
  - phase: 01-security-and-privacy-guardrails
    provides: Existing local backup/persistence entry points to harden
provides:
  - Canonical path containment utility for local filesystem decisions
  - Root-constrained path enforcement in persistence and local backup flows
  - Traversal regression coverage for encoded, mixed-separator, and normalization payloads
affects: [phase-01-plan-03, backup, persistence, security-tests]

# Tech tracking
tech-stack:
  added: []
  patterns: [canonicalize-before-containment, fail-closed-path-guard]

key-files:
  created: [lib/utils/path_guard.dart, test/security/path_guard_test.dart]
  modified: [lib/services/persistence_service.dart, lib/services/data_backup_service.dart, test/security/directory_traversal_test.dart, lib/utils/input_validation.dart]

key-decisions:
  - "Use a shared PathGuard utility to decode, normalize, and enforce root containment before filesystem IO."
  - "Fail closed with actionable errors when backup paths escape allowed roots."

patterns-established:
  - "Canonicalize encoded input before traversal decisions"
  - "Perform containment checks at service entry points before read/write/delete"

requirements-completed: [SEC-02]

# Metrics
duration: 5 min
completed: 2026-02-27
---

# Phase 1 Plan 2: Canonical Path Containment Summary

**Canonical root containment now protects local persistence and backup file IO, with regression coverage proving encoded and normalized traversal payloads are blocked.**

## Performance

- **Duration:** 5 min
- **Started:** 2026-02-27T17:09:36Z
- **Completed:** 2026-02-27T17:15:28Z
- **Tasks:** 3
- **Files modified:** 6

## Accomplishments
- Added `PathGuard` with deterministic allow/deny APIs using canonical containment checks for POSIX and Windows semantics.
- Enforced containment checks in `PersistenceService` and `DataBackupService` before any local file IO.
- Added focused utility tests and expanded directory-traversal security tests with service-level guard assertions.

## Task Commits

Each task was committed atomically:

1. **Task 1: Implement canonical path containment utility for local IO** - `c97b7f1` (feat)
2. **Task 2: Enforce containment in persistence and backup service entry points** - `15fa613` (feat)
3. **Task 3: Add traversal regression tests at utility and security-suite level** - `aa247f7` (fix)

**Plan metadata:** Pending

## Files Created/Modified
- `lib/utils/path_guard.dart` - Canonical decode/normalize and root-containment decision API.
- `lib/services/persistence_service.dart` - Applies fail-closed containment checks for app data files.
- `lib/services/data_backup_service.dart` - Validates import/export file paths against selected roots before IO.
- `test/security/path_guard_test.dart` - Unit coverage for POSIX/Windows containment and traversal payloads.
- `test/security/directory_traversal_test.dart` - Service-level traversal regression assertions.
- `lib/utils/input_validation.dart` - Additional `%u` and multi-dot traversal hardening.

## Decisions Made
- Centralized path traversal defense into `PathGuard` instead of service-specific string checks.
- Kept backup path validation fail-closed and surfaced blocking reasons as actionable import/export errors.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Blocked unicode-encoded traversal payload variant in file path validation**
- **Found during:** Task 3 (Add traversal regression tests at utility and security-suite level)
- **Issue:** `..%u002e%u002e%u002fetc/passwd` bypassed `InputValidation.validateFilePath` while traversal suite expected it blocked.
- **Fix:** Hardened `validateFilePath` dangerous-pattern set to reject `%uXXXX` unicode escapes and multi-dot separator patterns.
- **Files modified:** `lib/utils/input_validation.dart`
- **Verification:** `flutter test test/security/directory_traversal_test.dart`
- **Committed in:** `aa247f7` (part of task commit)

---

**Total deviations:** 1 auto-fixed (1 bug)
**Impact on plan:** Auto-fix was necessary to satisfy encoded traversal blocking requirements; no scope creep.

## Authentication Gates
None.

## Issues Encountered
- `flutter analyze` on touched services still reports pre-existing informational/warning findings in `lib/services/persistence_service.dart`; no blocking errors for this plan scope.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Plan 01-02 security objective is complete and verified by traversal-focused tests.
- Ready for `01-03-PLAN.md` (secure secret storage migration).

## Self-Check: PASSED
- Verified summary file exists at `.planning/phases/01-security-and-privacy-guardrails/01-02-SUMMARY.md`.
- Verified task commits exist: `c97b7f1`, `15fa613`, `aa247f7`.

---
*Phase: 01-security-and-privacy-guardrails*
*Completed: 2026-02-27*
