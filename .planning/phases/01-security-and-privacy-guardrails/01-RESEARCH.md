# Phase 1: Security and Privacy Guardrails - Research

**Researched:** 2026-02-27  
**Domain:** Flutter app security guardrails (input validation, filesystem safety, SSRF defenses, secret storage, privacy defaults)  
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
## Implementation Decisions

### Unsafe input handling UX
- Validation model is hybrid: lightweight checks while typing, strict validation on submit.
- Error messaging must include a specific rejection reason plus a concrete example fix.
- Severity model is split: critical-risk cases are hard-blocking; low-risk cases are warnings.
- Recovery pattern combines inline fix hints and one-tap safe defaults where applicable.
- Warning-only scope is primarily formatting issues (for example extra spaces or non-dangerous malformed input).
- Message tone should be calm and user-first, not harsh or punitive.
- Safe default action and manual edit path should have equal visual weight.
- Repeated blocked attempts should escalate to expanded guidance plus a docs/help link.

### Claude's Discretion
- Exact thresholds for when repeated failures trigger escalation prompts.
- Exact copy text and microcopy variants while keeping the approved tone and specificity.
- Visual styling and spacing of inline warnings/errors/safe-default actions.

### Deferred Ideas (OUT OF SCOPE)
## Deferred Ideas

None — discussion stayed within phase scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| SEC-01 | User-provided inputs cannot trigger command execution or shell injection paths. | Centralized typed validator model, strict submit-time enforcement, risk-classified outcomes, and corrected security test contracts. |
| SEC-02 | Local file operations reject directory traversal attempts. | Canonical path normalization + allowed-root enforcement for local IO entry points (`DataBackupService`, `PersistenceService`), plus traversal-focused tests. |
| SEC-03 | Remote URL and connector handling prevents SSRF-style unsafe target access. | Target canonicalization, scheme allowlist by connector type, DNS resolution + post-resolution private/link-local/loopback blocking, metadata endpoint denylist. |
| SEC-04 | Secrets and credentials are stored with platform-appropriate secure handling and never committed. | Move app/API secrets from settings JSON to `flutter_secure_storage`; keep non-secret metadata in file prefs; enforce ignore and leak checks. |
| SEC-05 | Adult library remains hidden by default and requires explicit opt-in toggle. | Preserve default-off in settings, route/nav/content gating, onboarding copy and explicit opt-in flow verification tests. |
</phase_requirements>

## Summary

Phase 1 should be planned as a **security baseline hardening pass over existing code**, not a greenfield feature build. The repository already contains initial controls (`InputValidation`, secure storage usage for some credentials, adult-content default-off behavior), but enforcement is inconsistent across entry points and several implementations conflict with the requirement intent (notably SSRF behavior and secret persistence in settings JSON).

The highest-value plan is to define one shared guardrail contract and then migrate all connector/settings/local-IO touchpoints onto it. This aligns with the locked UX decisions (hybrid validation, clear reason + fix, hard-block vs warning split, escalation on repeated failures) and reduces regression risk before later connector/sync phases.

**Primary recommendation:** implement a unified `SecurityValidationResult` pipeline and wire it end-to-end through connector dialogs, settings forms, filesystem entry points, and tests before adding any new connector capabilities.

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `flutter_secure_storage` | `^10.0.0` | Platform-backed secure secret storage | Already in repo; official package supports keychain/keystore-backed storage and is current in pub ecosystem. |
| `path` | `^1.9.0` (repo) / `1.9.1` (latest) | Cross-platform path normalization/join | Existing dependency; safest way to normalize and compare paths on Windows/POSIX semantics. |
| Dart `Uri` + `InternetAddress` APIs | Dart SDK | URI parsing/canonicalization and IP classification | Native SDK primitives for safe parsing and DNS/IP inspection; avoids regex-only security logic. |
| `flutter_test` | Flutter SDK | Security guardrail regression tests | Existing test stack; phase should tighten contracts and add requirement-mapped tests. |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `provider` | `^6.1.2` | App-wide settings/security state propagation | Surface warning/block state and repeated-failure counters across forms/screens. |
| `go_router` | `^16.3.0` | Route-level privacy guardrails | Keep `/adult` blocked when opt-in is off and enforce redirects consistently. |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| SDK `Uri`/`InternetAddress` + `path` | Custom regex parsers | Custom parsers miss edge cases (encoding, IPv6, platform path semantics) and increase bypass risk. |
| `flutter_secure_storage` | Plain `SharedPreferences`/JSON file | Plain storage violates SEC-04 for secrets. |

**Installation:**
```bash
flutter pub get
```

## Architecture Patterns

### Recommended Project Structure
```text
lib/
├── utils/
│   ├── input_validation.dart          # Pure validation rules
│   ├── security_validation_result.dart # Typed result (block/warn/ok + reason + fix)
│   └── security_policies.dart          # Shared constants (blocked CIDRs, metadata hosts, etc.)
├── services/
│   ├── remote_storage_service.dart     # Credential boundary only
│   ├── secure_key_service.dart         # API secret boundary only
│   └── ... connector clients
└── widgets/settings/
    └── ... forms using hybrid validation UX
```

### Pattern 1: Typed Validation Outcomes (Locked UX Aligned)
**What:** Replace nullable-string validation contract with a typed result containing severity, explicit reason, and concrete fix example.  
**When to use:** Every user-editable connector/settings/path field.  
**Example:**
```dart
enum ValidationSeverity { ok, warning, blocking }

class SecurityValidationResult {
  final ValidationSeverity severity;
  final String reason;
  final String fixExample;
  final String? safeDefault;
  const SecurityValidationResult(this.severity, this.reason, this.fixExample, {this.safeDefault});
}
```

### Pattern 2: Hybrid Validation Flow (Typing + Submit)
**What:** Run lightweight checks on `onChanged`, strict checks on submit. Keep warning-only for formatting/non-dangerous issues.  
**When to use:** Remote connection dialog, Stash endpoint dialog, API key fields, backup import/export path fields.

### Pattern 3: Canonicalize Before Security Decisions
**What:** Decode/normalize (`Uri`, `path`) before applying block/allow policies.  
**When to use:** SSRF hostname checks and filesystem path checks.

### Pattern 4: Secret Boundary Split
**What:** Persist secret material only in secure storage; keep operational metadata in persisted JSON.  
**When to use:** TMDB key, Stash API keys, remote passwords/private keys, OAuth tokens.

### Anti-Patterns to Avoid
- **Regex-only SSRF/path security:** current approach is bypass-prone and inconsistent across connectors.
- **String? error contract for validators:** cannot encode warning vs blocking severity or recovery action cleanly.
- **Duplicate validation logic in each dialog/service:** causes drift and contradictory behavior.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Secret encryption at rest | Custom XOR/DIY crypto wrappers | `flutter_secure_storage` platform-backed storage | DIY crypto is fragile and unnecessary when keystore/keychain exists. |
| Path safety | Manual `../` substring checks only | `path.normalize` + root containment checks | Traversal bypasses rely on normalization/encoding tricks that substring checks miss. |
| URI parsing | Custom split/regex parser | `Uri.parse/tryParse`, `Uri.decodeComponent`, `InternetAddress` checks | Handles encoded forms and URI edge cases correctly. |

**Key insight:** this phase should standardize on vetted primitives and shared policy tables; custom one-off parsing/encryption is the main source of guardrail regressions.

## Common Pitfalls

### Pitfall 1: Inverted Security Test Contracts
**What goes wrong:** Security tests currently assert the opposite contract (`blocked` expects `null`, `allowed` expects non-null).  
**Why it happens:** Helper semantics are reversed in `test/helpers/security_test_helpers.dart`.  
**How to avoid:** Fix helper contract first, then re-baseline tests to requirement intent.  
**Warning signs:** Every “blocked attack” test fails while validator returns explicit error text.

### Pitfall 2: SSRF Policy Drift Between UI and Validation
**What goes wrong:** `validateHostname` comments indicate private IPs are warning-only, conflicting with SEC-03 and tests.  
**Why it happens:** Policy changed in code comments/UX without requirement-level contract update.  
**How to avoid:** Define one SSRF policy matrix (blocking/warning by case) and reuse in all host/url validators.  
**Warning signs:** Private IP behavior differs between connection test/save/runtime fetch.

### Pitfall 3: Secret Leakage Through Settings JSON
**What goes wrong:** `SettingsProvider` persists `tmdbApiKey` and Stash `apiKey` in plain JSON.  
**Why it happens:** Legacy settings model stores all fields uniformly.  
**How to avoid:** Introduce non-secret settings DTO + secure-secret side channel migration.  
**Warning signs:** API keys appear in `settings.json` backups/logs.

### Pitfall 4: Path Safety Applied Inconsistently
**What goes wrong:** Local and remote paths use mixed validators with conflicting assumptions (`/` blocked in one path, allowed in another).  
**Why it happens:** One validator tries to cover both local and remote semantics.  
**How to avoid:** Separate local filesystem traversal policy from remote virtual-path policy, both canonicalized first.  
**Warning signs:** Legitimate root remote paths fail, or traversal slips through encoded/malformed path forms.

### Pitfall 5: UX Decisions Not Encoded in Data Model
**What goes wrong:** Can’t implement equal-weight safe default/manual fix, escalation thresholds, or warning-only cases cleanly.  
**Why it happens:** Existing validator API only returns a string.  
**How to avoid:** Validation result must carry severity, fix example, safe-default payload, and attempt-count context.  
**Warning signs:** Generic “Invalid host” messages and no escalation after repeated blocked attempts.

## Code Examples

Verified patterns from official sources and repo-aligned implementation:

### Secure Secret Storage Boundary
```dart
// Source: https://pub.dev/packages/flutter_secure_storage
const storage = FlutterSecureStorage();
await storage.write(key: 'remote_pass_$accountId', value: password);
final secret = await storage.read(key: 'remote_pass_$accountId');
```

### URI + Host Canonicalization Before SSRF Checks
```dart
// Source: https://api.dart.dev/stable/dart-core/Uri-class.html
final uri = Uri.tryParse(input.trim());
if (uri == null || uri.host.isEmpty) return blocking('Invalid URL', 'Use https://example.com');
final host = Uri.decodeComponent(uri.host).toLowerCase();
```

### IP Classification for Loopback/Link-Local Checks
```dart
// Source: https://api.dart.dev/stable/dart-io/InternetAddress-class.html
final ip = InternetAddress.tryParse(host);
if (ip != null && (ip.isLoopback || ip.isLinkLocal || ip.isMulticast)) {
  return blocking('Target is not allowed', 'Use a public host like media.example.com');
}
```

### Path Normalization for Traversal Defense
```dart
// Source: https://pub.dev/packages/path
final normalized = p.normalize(userPath);
final resolved = p.normalize(p.join(allowedRoot, normalized));
if (!p.isWithin(allowedRoot, resolved) && resolved != allowedRoot) {
  return blocking('Path escapes allowed directory', 'Pick a file under your selected backup folder');
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Single-submit-only validation | Hybrid (typing + submit) model required by locked decisions | Phase 1 planning context (2026-02-27) | Better recovery UX without reducing strict safety enforcement. |
| Generic string errors | Reason + concrete fix + severity required | Phase 1 planning context | Enables deterministic UI behavior (warn vs block) and escalation rules. |
| Regex-only security checks | Canonicalization + typed policy checks | Current best practice | Reduces bypass surface and inconsistency. |

**Deprecated/outdated:**
- String-only validator return type as security contract.
- Storing API secrets in general settings JSON payloads.

## Open Questions

1. **Repeated-failure escalation threshold (discretion area)**
   - What we know: escalation is required after repeated blocked attempts.
   - What's unclear: exact trigger count/window per field/session.
   - Recommendation: start with `3` blocked submits per field per session, then tune via UX feedback.

2. **Safe-default actions per field (discretion area)**
   - What we know: safe default and manual fix need equal visual weight.
   - What's unclear: exact defaults for each input class (host, port, URL, path).
   - Recommendation: define per-field default map in one policy file and include concrete examples in copy.

3. **Web secure-storage behavior policy for SEC-04**
   - What we know: package supports web, but guarantees differ by platform and browser context.
   - What's unclear: acceptable risk posture for secrets on web builds in this product.
   - Recommendation: document platform-specific guarantees and, for high-sensitivity secrets, prefer session-scoped handling on web.

## Sources

### Primary (HIGH confidence)
- Repository code audit:
  - `lib/utils/input_validation.dart`
  - `lib/widgets/settings/remote_connection_dialog.dart`
  - `lib/providers/settings_provider.dart`
  - `lib/services/remote_storage_service.dart`
  - `lib/services/graph_auth_service.dart`
  - `lib/services/data_backup_service.dart`
  - `lib/router.dart`
  - `lib/widgets/navigation_dock.dart`
  - `test/security/command_injection_test.dart`
  - `test/security/directory_traversal_test.dart`
  - `test/security/ssrf_test.dart`
  - `test/helpers/security_test_helpers.dart`
- `https://pub.dev/packages/flutter_secure_storage` (platform secure storage behavior)
- `https://api.dart.dev/stable/dart-core/Uri-class.html` (URI parsing/canonicalization)
- `https://api.dart.dev/stable/dart-io/InternetAddress-class.html` (IP parsing/classification)
- `https://pub.dev/packages/path` (cross-platform path normalization)

### Secondary (MEDIUM confidence)
- `https://owasp.org/www-community/attacks/Server_Side_Request_Forgery` (attack model + prevention framing)

### Tertiary (LOW confidence)
- None.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - validated against repo dependencies and official package/API docs.
- Architecture: HIGH - directly mapped to locked phase decisions and existing code structure.
- Pitfalls: HIGH - reproduced via repo code review and `flutter test test/security` execution.

**Research date:** 2026-02-27  
**Valid until:** 2026-03-29
