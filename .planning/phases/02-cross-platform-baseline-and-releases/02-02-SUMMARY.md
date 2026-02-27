---
phase: 02-cross-platform-baseline-and-releases
plan: 02
subsystem: platform
tags: [smoke-tests, routing, navigation, parity, verification-artifacts]

requires:
  - phase: 02-cross-platform-baseline-and-releases
    provides: hardened platform guardrails from 02-01
provides:
  - Route-level smoke coverage for mandatory core journeys.
  - Navigation/settings semantic parity coverage for adult-toggle branch visibility.
  - Cross-platform smoke matrix and deferred-issue registry artifacts.
affects: [routing, navigation, settings, smoke-tests, planning-artifacts]

tech-stack:
  added: [integration_test (sdk)]
  patterns: [route-level smoke assertions, parity index mapping, deferred matrix evidence]

key-files:
  created:
    - integration_test/core_journey_smoke_test.dart
    - test/smoke/navigation_settings_parity_test.dart
    - .planning/phases/02-cross-platform-baseline-and-releases/02-smoke-matrix.md
    - .planning/phases/02-cross-platform-baseline-and-releases/02-deferred-issues.md
  modified:
    - lib/router.dart
    - lib/screens/main_screen.dart
    - lib/widgets/navigation_dock.dart
    - pubspec.yaml

key-decisions:
  - "Extract route redirect logic into redirectPathForState for deterministic smoke assertions without full app bootstrap."
  - "Model visible dock destinations as branch-index specs to keep navigation semantics stable when adult tab visibility changes."
  - "Track non-executed Android/Web runtime checks as explicit deferred items instead of silent assumptions."

patterns-established:
  - "Core-journey smoke checks assert route outcomes and access gating at the router boundary."
  - "Parity evidence is stored as a matrix plus deferred registry with linked IDs."

requirements-completed: [PLAT-01]

duration: 42 min
completed: 2026-02-28
---

# Phase 2 Plan 02: Core Journey Smoke and Parity Summary

**Mandatory journey route behavior and navigation/settings parity now have executable smoke coverage plus traceable matrix/defer artifacts.**

## Performance

- **Duration:** 42 min
- **Started:** 2026-02-28T01:16:00Z
- **Completed:** 2026-02-28T01:58:00Z
- **Tasks:** 3
- **Files modified:** 8

## Accomplishments
- Added route-level core-journey smoke coverage in `integration_test/core_journey_smoke_test.dart` and executed it on Windows target.
- Added parity smoke coverage for navigation/settings semantics in `test/smoke/navigation_settings_parity_test.dart` and refactored dock visibility logic into explicit branch-index mappings.
- Added `02-smoke-matrix.md` and `02-deferred-issues.md` with linked deferred IDs for Android/Web runtime validation not executed in this run.

## Task Commits

Each task was committed atomically:

1. **Task 1: Create mandatory journey smoke runner for Windows/Android/Web** - `48d7b41` (test)
2. **Task 2: Lock navigation/settings semantic parity with focused regressions** - `73e2a10` (feat)
3. **Task 3: Generate smoke pass/fail matrix and structured defer registry artifacts** - `22348b1` (docs)

**Plan metadata:** `PENDING` (docs)

## Files Created/Modified
- `integration_test/core_journey_smoke_test.dart` - Core route smoke checks for setup/profile/root/adult gating and mandatory route accessibility.
- `lib/router.dart` - Added pure redirect helper (`redirectPathForState`) and routed provider redirect logic through it.
- `test/smoke/navigation_settings_parity_test.dart` - Added parity assertions for branch index mapping and dock tap behavior.
- `lib/widgets/navigation_dock.dart` - Refactored to destination specs with stable visible branch index helper.
- `lib/screens/main_screen.dart` - Added explicit shell-unavailable message helper for deterministic fallback behavior.
- `.planning/phases/02-cross-platform-baseline-and-releases/02-smoke-matrix.md` - Added per-journey platform matrix with evidence/deferred IDs.
- `.planning/phases/02-cross-platform-baseline-and-releases/02-deferred-issues.md` - Added structured deferred registry with workaround and target phase.

## Decisions Made
- Added `integration_test` SDK dependency because `flutter test -d windows` on integration tests requires it.
- Kept Android/Web runtime smoke checks explicitly deferred with concrete IDs instead of inferring pass from unit/integration route checks alone.
- Centralized dock destination visibility to ensure branch semantics remain stable under adult opt-in state changes.

## Deviations from Plan

- **[Rule 3 - Blocking] Integration test dependency missing** — `flutter test -d windows integration_test/core_journey_smoke_test.dart` failed until `integration_test` was added to `dev_dependencies`.

## Issues Encountered

- Initial integration-test invocation failed with multi-device selection and missing `integration_test` SDK dependency; resolved by selecting `-d windows` and adding dependency.
- Android and Web runtime smoke execution remains deferred due unavailable runtime sessions in this execution wave.

## User Setup Required

None.

## Next Phase Readiness

- 02-02 outputs are complete and provide evidence artifacts consumed by phase verification.
- Release reproducibility work in 02-03 remains to complete PLAT-02 evidence.

## Self-Check: PASSED

- Verified summary exists at `.planning/phases/02-cross-platform-baseline-and-releases/02-02-SUMMARY.md`.
- Verified task commits exist: `48d7b41`, `73e2a10`, `22348b1`.
- Verified `flutter test -d windows integration_test/core_journey_smoke_test.dart` passes.
- Verified `flutter test test/smoke/navigation_settings_parity_test.dart` passes.

---
*Phase: 02-cross-platform-baseline-and-releases*
*Completed: 2026-02-28*
