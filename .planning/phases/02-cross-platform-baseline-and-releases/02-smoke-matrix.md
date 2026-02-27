# Phase 02 Smoke Matrix

Generated: 2026-02-28
Phase: 02-cross-platform-baseline-and-releases

## Journey Matrix

| Journey | Windows | Android | Web | Evidence | Deferred ID |
|---|---|---|---|---|---|
| Onboarding route gate (`/setup`) | PASS | DEFERRED | DEFERRED | `integration_test/core_journey_smoke_test.dart` (`setup flow gates pre-setup navigation`) | D-02-001, D-02-002 |
| Browse entry (`/discover`) | PASS | DEFERRED | DEFERRED | `integration_test/core_journey_smoke_test.dart` (`core routes are accessible`) | D-02-001, D-02-002 |
| Details route (`/media/:id`) | PASS | DEFERRED | DEFERRED | `integration_test/core_journey_smoke_test.dart` route assertions | D-02-001, D-02-002 |
| Playback entry fallback (trailer) | PASS | DEFERRED | DEFERRED | `test/platform/platform_guard_test.dart` + trailer fallback guard code path | D-02-001, D-02-002 |
| Settings + nav parity | PASS | DEFERRED | DEFERRED | `test/smoke/navigation_settings_parity_test.dart` | D-02-001, D-02-002 |
| Adult route opt-in protection (`/adult`) | PASS | DEFERRED | DEFERRED | `integration_test/core_journey_smoke_test.dart` (`adult route remains opt-in protected`) | D-02-001, D-02-002 |

## Notes

- Windows evidence is from local automated test execution in this phase.
- Android and Web runtime smoke execution is deferred because no device/browser runtime session was available in this run.
- Deferred entries map to `.planning/phases/02-cross-platform-baseline-and-releases/02-deferred-issues.md`.
