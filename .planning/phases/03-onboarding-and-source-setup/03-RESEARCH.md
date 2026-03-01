# Phase 3: Onboarding and Source Setup - Research

**Researched:** 2026-03-01
**Domain:** Flutter onboarding UX + local/remote source connection flows (OneDrive Device Code, SFTP/FTP/WebDAV)
**Confidence:** MEDIUM-HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

### Onboarding flow
- Use a linear guided onboarding wizard.
- Show progress using checklist-style completion states.
- If onboarding is interrupted, prompt users to resume where they left off or restart.
- Entering Home should not be hard-blocked by source connection completion.

### Source priorities
- Do not prioritize a default source type; users choose their first source path.
- Do not push source-connection count during first run; source setup remains optional in onboarding.
- Present SFTP, FTP, and WebDAV as separate remote protocol cards.
- After onboarding, browse/search defaults should include all enabled sources.

### Connection recovery
- Show connection/auth failures inline near relevant fields, with local context.
- Primary recovery path should be guided troubleshooting before retry.
- If OneDrive Device Code flow times out or is abandoned, return to source list and mark OneDrive incomplete.
- After repeated failures, show a short troubleshooting checklist and docs link.

### Library type setup
- Preselect no library types; users opt in explicitly.
- Present type choices as visual cards.
- Put Adult type in a separate explicit privacy section.
- Require a final review step summarizing selected types and sources before finishing onboarding.

### Claude's Discretion
- Exact visual styling and wording of step labels, checklist markers, and helper text.
- Exact copy of troubleshooting checklist and docs link labels.
- Exact wording for resume/restart and incomplete-source prompts.

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| ONB-01 | User can complete first-run setup and select enabled library types. | Wizard state model, explicit card selection pattern, separate adult-privacy step, final review step pattern, resumable checkpoint persistence. |
| ONB-02 | User can add at least one local folder source from onboarding. | `file_picker` directory flow on desktop/mobile, platform-specific fallback behavior, `LibraryProvider.pickAndScan` integration pattern. |
| ONB-03 | User can connect OneDrive using Device Code Flow. | OAuth device-code protocol requirements, polling/timeout/error mapping, existing `GraphAuthService` + `DeviceCodeDialog` integration points. |
| ONB-04 | User can add remote source profile for SFTP/FTP/WebDAV. | Existing protocol adapters (`dartssh2`, `ftpconnect`, `webdav_client`) and hardened inline validation/troubleshooting pattern in `RemoteConnectionDialog`. |
</phase_requirements>

## Summary

Phase 3 should be planned as a UX orchestration phase, not a protocol-invention phase. The repository already has core technical building blocks for all required source types: local folder picker (`LibraryProvider.pickAndScan`), OneDrive Device Code auth (`GraphAuthService` + `DeviceCodeDialog`), and remote profile management (`RemoteStorageService` + protocol wrappers + `RemoteConnectionDialog`). The plan should prioritize composing these into a linear onboarding workflow with resumable state, explicit completion checklist states, and a mandatory review step.

For OneDrive, the protocol details are clear and stable: request device code, display user code + verification URI, poll token endpoint with interval/backoff, handle pending/slow_down/declined/expired states, and persist delegated tokens securely. Microsoft docs also confirm app-registration prerequisites (`Allow public client flows`) and expected token endpoint error semantics for device flow. This aligns with the existing `GraphAuthService` architecture and should be reused, not replaced.

The biggest planning risk is state consistency across interruptions: onboarding progress, partial source attempts, and completion semantics (`enter Home not hard-blocked`). The implementation should persist a dedicated onboarding draft state (step index + selected library types + per-source status) separate from irreversible completion state (`settings.isSetupCompleted`).

**Primary recommendation:** Build a resumable onboarding state machine that orchestrates existing source connectors and validation layers, adding minimal new protocol code.

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Flutter | 3.38.4 | App/UI framework | Existing app baseline and platform behavior are already validated in repo conventions. |
| provider | ^6.1.2 | State management | Existing app state architecture uses `ChangeNotifier` + Provider end-to-end. |
| go_router | ^16.3.0 | Route guards/redirects | Existing setup gating already implemented in router redirect logic. |
| http | ^1.2.2 | Graph/REST calls | Already used in auth and OneDrive folder browsing; no extra SDK lock-in required. |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| file_picker | ^8.1.2 | Local file/folder selection | Use for ONB-02 local source selection; desktop uses `getDirectoryPath()`, mobile can fallback to file selection behavior as needed. |
| flutter_secure_storage | ^10.0.0 | Secret/token storage | Use for OneDrive and remote credentials (passwords/tokens/private keys). |
| shared_preferences | ^2.3.3 | Lightweight checkpoint state | Use for resumable onboarding draft/checkpoint data only (non-secret). |
| dartssh2 | ^2.8.2 | SFTP protocol client | Use for SFTP connect/list/test operations. |
| ftpconnect | ^2.0.7 | FTP protocol client | Use for FTP profile/test operations, with explicit insecure warnings. |
| webdav_client | ^1.2.2 | WebDAV protocol client | Use for HTTPS WebDAV profile/test operations. |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Raw Graph + custom polling (current) | MSAL SDK wrappers | MSAL is preferred generally by Microsoft docs, but existing codebase already has stable custom flow and token persistence; changing stack is out of phase scope. |
| `shared_preferences` legacy API | `SharedPreferencesAsync`/`WithCache` | New APIs are now preferred by package maintainers; migration can be deferred unless onboarding state consistency issues appear. |

**Installation:**
```bash
flutter pub get
```

## Architecture Patterns

### Recommended Project Structure
```
lib/
├── onboarding/              # New: wizard state, step models, completion logic
├── screens/                 # Onboarding shell + step screens
├── widgets/                 # Reusable cards/checklist/error components
├── providers/               # Settings/Library/Profile + onboarding controller
└── services/                # Existing auth and source connectors (reuse)
```

### Pattern 1: Resumable Wizard State Machine
**What:** A dedicated onboarding controller that tracks step progression, partial selections, and completion flags per requirement.
**When to use:** Any first-run step with resume/restart requirements and optional source completion.
**Example:**
```dart
// Source: repository pattern in lib/providers/settings_provider.dart + lib/screens/setup_screen.dart
class OnboardingState {
  final int currentStep;
  final Set<LibraryType> selectedTypes;
  final bool localSourceAdded;
  final bool oneDriveConnected;
  final bool remoteProfileAdded;
}
```

### Pattern 2: Connector Adapter Reuse
**What:** Keep protocol logic in existing services; onboarding triggers service actions and maps results to UX states.
**When to use:** ONB-03/ONB-04 source connection steps.
**Example:**
```dart
// Source: lib/services/graph_auth_service.dart
final session = await auth.requestDeviceCode();
final result = await auth.pollDeviceCode(session);
```

### Pattern 3: Field-Adjacent Inline Recovery UX
**What:** Show validation/auth failures close to the offending input + contextual fix examples + escalated help after repeated failure.
**When to use:** Remote protocol profile setup and OneDrive auth interruption flows.
**Example:**
```dart
// Source: lib/widgets/settings/remote_connection_dialog.dart
if (hostResult.isBlocking) {
  _registerBlockingResult('host', hostResult, isSubmit: true);
}
```

### Anti-Patterns to Avoid
- **Monolithic onboarding screen:** Makes resume/restart and per-step verification hard to reason about; use explicit step state.
- **Re-implementing auth/protocol clients in UI layer:** Duplicates security and retry logic; call existing services.
- **Blocking Home until every source is connected:** Contradicts locked decision; treat source setup as optional completion items.
- **Storing tokens in `SharedPreferences`:** Violates existing security posture and SEC-04.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| OAuth device grant primitives | Custom protocol variants | Existing `GraphAuthService` + Microsoft device flow contract | Error semantics and polling edge-cases are subtle and already covered. |
| Secret persistence | Plain JSON/prefs token storage | `flutter_secure_storage` via existing services | Platform keystore/keychain handling is already integrated. |
| SFTP/FTP/WebDAV transport implementations | Raw socket protocol clients | `dartssh2` / `ftpconnect` / `webdav_client` wrappers | Protocol parsing and connection edge-cases are high-complexity. |
| Folder selection UI plumbing | Custom platform channels for folder pickers | `file_picker` | Cross-platform picker behavior is already solved and integrated. |

**Key insight:** Phase 3 risk is orchestration and state durability, not protocol capability.

## Common Pitfalls

### Pitfall 1: Onboarding completion and setup completion are conflated
**What goes wrong:** User exits early and gets redirected inconsistently because one boolean (`isSetupCompleted`) is overloaded.
**Why it happens:** Existing setup flow stores only terminal completion state.
**How to avoid:** Persist a draft onboarding checkpoint object separately; only set completion flag after final review confirmation.
**Warning signs:** Resume dialog cannot determine exact previous step or source statuses.

### Pitfall 2: Device-code polling loops become aggressive
**What goes wrong:** Excess polling causes rate limiting or noisy errors.
**Why it happens:** Interval/backoff rules are not strictly followed.
**How to avoid:** Respect `interval`; handle `slow_down` by increasing polling interval; stop on non-pending terminal errors.
**Warning signs:** Repeated token endpoint failures, frequent `slow_down`, or UI thrash.

### Pitfall 3: Local folder flow fails on unsupported picker behavior
**What goes wrong:** Directory picker assumptions break on some platforms (notably web for `getDirectoryPath()`).
**Why it happens:** Platform capability differences are ignored.
**How to avoid:** Gate by platform capability and show explicit unsupported-state messaging.
**Warning signs:** Null paths, unhandled exceptions, missing progress state updates.

### Pitfall 4: Remote protocol error UX is detached from the field causing failure
**What goes wrong:** Users get generic toast errors and retry blindly.
**Why it happens:** Validation and network errors are reported globally.
**How to avoid:** Reuse field-adjacent validation and escalated guidance pattern from `RemoteConnectionDialog`.
**Warning signs:** High retry count without input edits.

### Pitfall 5: OneDrive timeout/abandon path is not modeled as incomplete source
**What goes wrong:** Onboarding treats canceled/expired auth as success or dead-end.
**Why it happens:** No explicit status enum for source connection states.
**How to avoid:** Use source status states: `not_started`, `in_progress`, `incomplete`, `connected`, `failed`.
**Warning signs:** Inconsistent checklist state after closing auth dialog.

## Code Examples

Verified patterns from official/repository sources:

### OneDrive Device Code Request + Poll
```dart
// Source: https://learn.microsoft.com/en-us/entra/identity-platform/v2-oauth2-device-code
// Source: lib/services/graph_auth_service.dart
final session = await auth.requestDeviceCode();
while (DateTime.now().isBefore(session.expiresAt)) {
  await Future.delayed(Duration(seconds: interval));
  final result = await auth.pollDeviceCode(session);
  if (result.state == DeviceCodePollState.success) break;
  if (result.state == DeviceCodePollState.slowDown) {
    interval = result.recommendedInterval ?? (interval + 5);
  }
}
```

### Local Source Picker Flow
```dart
// Source: lib/providers/library_provider.dart
final path = await FilePicker.platform.getDirectoryPath();
if (path != null) {
  await addLibraryFolder(LibraryFolder(
    id: DateTime.now().millisecondsSinceEpoch.toString(),
    path: path,
    accountId: '',
    type: forcedType ?? LibraryType.other,
  ));
}
```

### Remote Profile Validation Before Connect
```dart
// Source: lib/widgets/settings/remote_connection_dialog.dart
final hostResult = InputValidation.strictValidateHostname(_hostController.text);
if (hostResult.isBlocking) {
  _registerBlockingResult('host', hostResult, isSubmit: true);
  return;
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `SharedPreferences` as default plugin API | `SharedPreferencesAsync` / `SharedPreferencesWithCache` recommended for new use | shared_preferences >= 2.3.0 | Existing code can stay, but new onboarding checkpoint logic should account for cache staleness or consider newer API. |
| Ad-hoc navigation guards | Declarative `go_router` redirect callbacks | go_router maturation (ongoing; feature-complete status documented) | Onboarding gating should stay in router redirect model for consistency. |
| Manual assumption that `verification_uri_complete` is always available | Treat `verification_uri` + `user_code` as baseline | Microsoft device-flow docs note `verification_uri_complete` not supported there | UI should always show manual code entry path first, optional shortcut second. |

**Deprecated/outdated:**
- `shared_preferences` legacy API as first choice for new persistence logic (package maintainers now recommend async/cache variants).

## Open Questions

1. **How should ONB-03 define “supported platforms” for Device Code in this app?**
   - What we know: Requirement says Device Code on supported platforms; app currently uses web popup flow on web and device code on non-web.
   - What's unclear: Whether web should be excluded from ONB-03 acceptance criteria or treated as alternate auth path.
   - Recommendation: Define ONB-03 as desktop/mobile device-code path; keep web explicitly marked as alternate flow/unsupported for this requirement.

2. **Should ONB-02 be a mandatory completion criterion or just capability exposed in onboarding?**
   - What we know: Locked decision says entering Home is not hard-blocked by source connection completion.
   - What's unclear: Whether QA must verify user actually adds at least one local folder before finishing wizard.
   - Recommendation: Make local source step skippable but clearly marked incomplete; verify ONB-02 by reachable successful path, not mandatory path.

3. **Where should resumable draft onboarding state be persisted?**
   - What we know: Settings are persisted to `settings.json`; secrets already go to secure storage.
   - What's unclear: Whether onboarding draft belongs in `SettingsProvider` or a new provider/service file.
   - Recommendation: Create dedicated onboarding draft model/service (non-secret), referenced by router + onboarding UI.

## Sources

### Primary (HIGH confidence)
- https://learn.microsoft.com/en-us/entra/identity-platform/v2-oauth2-device-code - device code request/response, polling errors, token semantics (updated 2025-01-04).
- https://learn.microsoft.com/en-us/entra/identity-platform/scenario-desktop-app-registration - public client flow requirement and desktop app registration prerequisites (updated 2025-09-11).
- https://learn.microsoft.com/en-us/graph/api/driveitem-list-children - OneDrive folder listing endpoint, permissions, pagination behavior (updated 2025-11-25).
- https://learn.microsoft.com/en-us/graph/api/driveitem-get - Drive item metadata endpoint and least-privilege permissions (updated 2025-11-25).
- https://learn.microsoft.com/en-us/graph/api/driveitem-put-content - upload endpoint and permission requirements (updated 2026-02-06).
- https://learn.microsoft.com/en-us/graph/best-practices-concept - Graph reliability/pagination/retry guidance (updated 2025-08-15).
- https://www.rfc-editor.org/rfc/rfc8628.txt - OAuth device grant normative polling/error behavior.
- Repository files: `lib/services/graph_auth_service.dart`, `lib/widgets/device_code_dialog.dart`, `lib/services/remote_storage_service.dart`, `lib/widgets/settings/remote_connection_dialog.dart`, `lib/providers/library_provider.dart`, `lib/router.dart`, `lib/providers/settings_provider.dart`.

### Secondary (MEDIUM confidence)
- https://pub.dev/packages/file_picker - platform capability matrix (`getDirectoryPath` web limitation), API examples.
- https://pub.dev/packages/flutter_secure_storage - platform secure-storage behavior summary.
- https://pub.dev/packages/dartssh2 - SFTP capability and supported operations.
- https://pub.dev/packages/ftpconnect - FTP capability and connection options.
- https://pub.dev/packages/webdav_client - WebDAV capabilities and caveats.
- https://pub.dev/packages/shared_preferences - API evolution and storage caveats.
- https://pub.dev/documentation/go_router/latest/topics/Redirection-topic.html - redirect behavior and redirect limit.

### Tertiary (LOW confidence)
- N/A (no critical findings rely on single unverified community source only).

## Metadata

**Confidence breakdown:**
- Standard stack: **HIGH** - derived from repo dependencies and active official package/docs references.
- Architecture: **MEDIUM-HIGH** - strong repo evidence, but some onboarding-state design remains implementation-specific.
- Pitfalls: **MEDIUM** - validated by protocol/docs + existing code, but some failure-rate assumptions are experiential.

**Research date:** 2026-03-01
**Valid until:** 2026-03-31
