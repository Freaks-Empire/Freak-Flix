# Phase 2: Cross-Platform Baseline and Releases - Context

**Gathered:** 2026-02-27
**Status:** Ready for planning

<domain>
## Phase Boundary

Deliver a reliable cross-platform baseline where the existing core journeys run on Windows, Android, and Web, and produce repeatable release artifacts for all three platforms. This phase validates platform readiness and release discipline for current capabilities, not new product features.

</domain>

<decisions>
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

</decisions>

<specifics>
## Specific Ideas

- Phase completion should be treated as an operational readiness gate: build artifacts plus demonstrated end-to-end journey reliability on each platform.
- Reliability-first policy is explicit when platform behavior and visual consistency conflict.

</specifics>

<deferred>
## Deferred Ideas

None - discussion stayed within phase scope.

</deferred>

---

*Phase: 02-cross-platform-baseline-and-releases*
*Context gathered: 2026-02-27*
