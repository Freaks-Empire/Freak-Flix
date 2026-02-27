# Phase 2: Cross-Platform Baseline and Releases - Research

**Researched:** 2026-02-27  
**Domain:** Cross-platform runtime reliability and release-output reproducibility (Windows, Android, Web)  
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
## Implementation Decisions

### Core journey pass criteria
- Mandatory journeys for phase signoff on every platform: onboarding, browse, details, playback, settings.
- A journey pass means end-to-end completion with no crash, no dead-end state, and expected state persistence.
- Platform-specific gaps are only acceptable when explicitly documented with workaround and defer note.
- Completion evidence must include a per-platform smoke checklist and pass/fail matrix.

### Platform parity vs acceptable differences
- Core behavior parity is required; platform-native visual differences are acceptable.
- Interaction models may be platform-appropriate (touch vs mouse/keyboard) as long as outcomes match.
- If behavior is not cleanly supported on one platform in this phase, show an explicit "not available yet" state and defer note.
- Navigation destinations and settings semantics must match across platforms, even if layout placement differs.
- Playback semantics that must match: play/pause, seek, resume position, and error messaging intent.
- Settings values must persist/reload consistently across all target platforms.
- Performance can vary by platform, but flows must complete reliably without hangs or crashes.
- In parity conflicts, reliability and predictable behavior win over visual consistency.

### Release output expectations
- Required outputs for phase completion: Windows release build, Android release build, Web release build.
- Minimum acceptance per output: build succeeds, app launches, and core smoke journey passes on target platform.
- Internal distributable readiness is sufficient in this phase; store submission readiness can defer.
- Build process must be reproducible with documented repeatable commands/steps per platform.

### Blocker and defer policy
- Automatic blockers: any platform where required core journeys cannot complete reliably.
- Deferrable items: non-critical UX polish and non-blocking performance tuning only, with documented follow-up.
- Every deferred item must record: issue, affected platform, workaround, and target phase.
- No known high-severity reliability defects are acceptable at phase close for scoped journeys.

### Claude's Discretion
- Exact smoke-checklist structure and naming conventions.
- Specific formatting for pass/fail matrix and release verification notes.
- Tooling details used to run and validate release commands, as long as decision constraints above are preserved.

### Deferred Ideas (OUT OF SCOPE)
## Deferred Ideas

None - discussion stayed within phase scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| PLAT-01 | Core flows (onboarding, browse, details, play, settings) work on Windows, Android, and Web builds. | Runtime platform-guard audit, parity hardening for navigation/settings/playback semantics, and smoke journey validation matrix. |
| PLAT-02 | Release builds complete successfully for Windows, Android, and Web targets. | Repeatable build orchestration, artifact verification, and Android/Windows/Web build stabilization from concrete command output. |
</phase_requirements>

## Summary

Phase 2 should be planned as a **platform hardening + release discipline pass** over the existing app, not as a feature expansion.

Current baseline evidence from local commands:
- `flutter build web --release` succeeded.
- `flutter build windows --release` succeeded and produced `build/windows/x64/runner/Release/freakflix.exe` (with plugin CMake warnings).
- `flutter build apk --release` produced `build/app/outputs/flutter-apk/app-release.apk`, but emitted Kotlin daemon/incremental cache exceptions from Android plugin cache roots. This is a reliability risk for repeatable release runs.
- `flutter doctor -v` reports Android toolchain issues (`cmdline-tools` missing, Android license status unknown) despite successful local APK output. This is a repeatability/environment gap.

Primary code risk for PLAT-01:
- Multiple shared runtime paths still use direct `dart:io` + `Platform.is*` checks in cross-platform classes (`lib/main.dart`, `lib/providers/library_provider.dart`, `lib/services/scan_orchestration_service.dart`, and others). These may not fail compile-time but can fail or diverge at runtime on web if reached without safe guarding.

**Primary recommendation:** execute in four slices:
1. Runtime guardrail hardening for platform safety and explicit unsupported states,
2. Core journey parity + smoke harness,
3. Build/release reproducibility and Android stabilization,
4. Final cross-platform pass/fail gate with documented deferred issues.

## Standard Stack

### Core
| Library/Tool | Version | Purpose | Why Standard |
|--------------|---------|---------|--------------|
| Flutter SDK | 3.38.4 | Cross-platform build/run baseline | Project is already pinned here; phase validates behavior on this exact toolchain. |
| Dart SDK | 3.10.3 | Runtime/compiler behavior | Matches current Flutter toolchain output and warnings observed during builds. |
| `go_router` | ^16.3.0 | Route-level parity/gating behavior | Core journey destination semantics depend on router consistency. |
| `provider` | ^6.1.2 | Shared settings/state behavior | Needed for settings persistence parity and cross-platform behavior checks. |
| `integration_test` + `flutter_test` | Flutter SDK | Smoke flow verification automation | Required for repeatable pass/fail journey evidence. |

### Supporting
| Library/Tool | Version | Purpose | When to Use |
|--------------|---------|---------|-------------|
| `package:media_kit` + platform libs | existing deps | Playback behavior on desktop/mobile | Verify parity and graceful platform fallback handling. |
| `flutter build` commands | SDK CLI | Release artifact generation | Required for PLAT-02 evidence and reproducibility scripts. |
| PowerShell scripts in `scripts/` | repo-native | Repeatable command orchestration + report generation | Use for deterministic local/CI release verification runs. |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Manual build/test steps | Scripted runbook + generated matrix | Manual execution is error-prone and not reproducible enough for PLAT-02. |
| Implicit platform behavior | Explicit unsupported states and defer registry | Implicit behavior creates user-visible dead ends and undocumented parity drift. |

## Architecture Patterns

### Pattern 1: Platform Guardrail Boundary
Use a single platform abstraction boundary (`lib/utils/platform/platform.dart` + `kIsWeb`) for shared runtime checks. Avoid direct `dart:io Platform` usage in cross-platform execution paths.

### Pattern 2: Reliability-First Capability Gating
When platform support is incomplete, return explicit "not available yet" UX and defer entry with workaround documentation instead of silent hiding or crash-risk execution.

### Pattern 3: Journey Smoke as Contract
Define one smoke contract for onboarding, browse, details, playback, settings. Execute per platform and produce a machine-readable + human-readable matrix (pass/fail, evidence, deferred notes).

### Pattern 4: Build Reproducibility as Code
Treat build commands and artifact validation as versioned scripts (preflight, build, artifact existence, checksum/size metadata, known warning capture).

### Anti-Patterns to Avoid
- Platform-specific guards scattered ad hoc in feature files.
- "Build succeeded once" treated as phase completion.
- Deferred issues captured informally without platform/workaround/target phase fields.
- Silent feature removal on unsupported platforms (violates locked decision for explicit unsupported state).

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Platform detection in shared paths | Repeated raw `dart:io Platform` checks | existing `lib/utils/platform/platform.dart` + `kIsWeb` safe checks | Consolidates behavior and avoids runtime divergence/crashes. |
| Smoke reporting | Ad hoc markdown notes only | deterministic checklist + generated matrix file | Enables repeatable PLAT-01/02 gating and checker/verifier traceability. |
| Release validation | Human memory of prior commands | scripted command pipeline under `scripts/` | Prevents environment drift and regression in repeat runs. |

## Common Pitfalls

### Pitfall 1: Runtime platform checks can crash on web paths
**What goes wrong:** Direct `Platform.is*` usage in shared files can be reached on web and produce unsupported-operation failures.  
**Warning signs:** Files like `lib/main.dart` and `lib/providers/library_provider.dart` use direct `dart:io` checks outside guaranteed native-only boundaries.

### Pitfall 2: Android release appears successful but emits instability traces
**What goes wrong:** APK is generated, but Kotlin daemon incremental cache exceptions appear for Android plugins (`screen_brightness_android`, `webview_flutter_android`).  
**Impact:** Non-deterministic CI/local release reliability for PLAT-02.  
**Recommendation:** Treat as blocker until release command is stable across repeated runs.

### Pitfall 3: Toolchain diagnostics and build behavior disagree
**What goes wrong:** `flutter doctor -v` flags Android command-line tools/licenses, but local build can still succeed.  
**Impact:** Build portability risk for other machines/CI.  
**Recommendation:** Add preflight checks and documented remediation in release script/runbook.

### Pitfall 4: Release warnings drift into ignored noise
**What goes wrong:** Font/package warnings (e.g., missing Cupertino icon family) and plugin CMake warnings accumulate and mask real failures.  
**Recommendation:** classify warnings into "known acceptable", "must fix this phase", and "defer with owner/phase."

## Code Examples

### Safe platform boundary usage in shared startup path
```dart
if (!kIsWeb && Platform.isWindows) {
  // Windows-only setup
}
```

### Release preflight command pattern
```powershell
flutter doctor -v
flutter pub get
flutter build web --release
flutter build windows --release
flutter build apk --release
```

### Matrix record shape for deferred issues
```yaml
defer:
  issue: "Android release emits Kotlin daemon cache exceptions"
  platform: "android"
  workaround: "clean build cache and rerun scripted release command"
  target_phase: "02 or 2.x polish"
```

## State of the Art

| Area | Current Repo State | Target State for Phase 2 |
|------|--------------------|--------------------------|
| Journey validation | Mostly manual confidence | Repeatable smoke checklist + pass/fail matrix per platform |
| Platform safety checks | Mixed direct/platform-abstraction usage | Unified safe boundary and explicit unsupported behavior |
| Release commands | Known commands in docs | Scripted reproducible release workflow with artifact checks |
| Build reliability | Web/Windows good, Android noisy | Stable repeated builds with warnings triaged/documented |

## Open Questions

1. **Android smoke execution environment**
   - Unknown if phase will use physical device, emulator, or automation-only proxy for playback checks.
2. **Acceptance threshold for known non-blocking warnings**
   - Need explicit allowlist format in phase artifacts to avoid ambiguity at close.
3. **CI scope for this phase**
   - Whether to add/extend workflows in `.github/workflows` now vs keep scripts local and defer CI expansion.

## Sources

### Primary (HIGH confidence)
- Repository files:
  - `lib/main.dart`
  - `lib/providers/library_provider.dart`
  - `lib/services/scan_orchestration_service.dart`
  - `lib/widgets/settings/settings_sync_section.dart`
  - `lib/utils/platform/platform.dart`
  - `.planning/phases/02-cross-platform-baseline-and-releases/02-CONTEXT.md`
  - `.planning/ROADMAP.md`
  - `.planning/REQUIREMENTS.md`
  - `pubspec.yaml`
- Local command evidence (2026-02-27):
  - `flutter doctor -v`
  - `flutter build web --release`
  - `flutter build windows --release`
  - `flutter build apk --release`

### Secondary (MEDIUM confidence)
- Flutter build/runtime conventions from official Flutter SDK tooling behavior (observed via CLI output in this environment).

### Tertiary (LOW confidence)
- None.

## Metadata

**Confidence breakdown:**
- Requirement mapping: HIGH  
- Build baseline evidence: HIGH  
- Android instability root-cause certainty: MEDIUM (symptoms are concrete; final root cause still needs execution-phase deep fix)

**Research date:** 2026-02-27  
**Valid until:** 2026-03-20
