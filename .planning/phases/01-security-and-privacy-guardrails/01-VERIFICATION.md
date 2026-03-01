---
phase: 01-security-and-privacy-guardrails
verified: 2026-03-01T10:09:31Z
status: passed
score: 5/5 must-haves verified
---

# Phase 1: Security and Privacy Guardrails Verification Report

**Phase Goal:** Users can trust that library connectors and settings remain safe by default, with adult content hidden unless explicitly enabled.
**Verified:** 2026-03-01T10:09:31Z
**Status:** passed
**Re-verification:** No - initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
| --- | --- | --- | --- |
| 1 | User input in source/settings flows cannot be used to execute shell commands. | ✓ VERIFIED | `lib/utils/input_validation.dart` hard-blocks injection metacharacters and payload patterns in strict validators; submit flow uses strict validation in `lib/widgets/settings/remote_connection_dialog.dart`; `flutter test test/security/command_injection_test.dart` passed. |
| 2 | User cannot access files outside allowed roots via traversal patterns. | ✓ VERIFIED | `lib/utils/path_guard.dart` canonicalizes/decodes candidate paths and enforces containment; `lib/services/persistence_service.dart` and `lib/services/data_backup_service.dart` call `PathGuard.requireContainedPath` before IO; traversal suites passed (`test/security/path_guard_test.dart`, `test/security/directory_traversal_test.dart`). |
| 3 | Remote connector targets block unsafe/internal SSRF-style destinations. | ✓ VERIFIED | `lib/utils/input_validation.dart` blocks internal tokens, private/loopback/link-local IPs, metadata endpoints, and encoded notation; remote dialog strict host/URL checks are wired; `flutter test test/security/ssrf_test.dart` passed. |
| 4 | User credentials/tokens are stored securely and never exposed in repository artifacts. | ✓ VERIFIED | `lib/services/secure_key_service.dart` uses `FlutterSecureStorage`; `lib/providers/settings_provider.dart` migrates legacy plaintext and persists secrets via `SecureKeyService`; `lib/models/stash_endpoint.dart` omits `apiKey` in `toJson`; `test/security/secret_storage_test.dart` passed. |
| 5 | Adult library is hidden by default and appears only after explicit user opt-in. | ✓ VERIFIED | `lib/providers/settings_provider.dart` defaults/coerces `enableAdultContent=false`; explicit setup opt-in wired in `lib/screens/setup_screen.dart`; route gating in `lib/router.dart`; tab visibility gating in `lib/widgets/navigation_dock.dart`; `test/security/adult_privacy_test.dart` passed. |

**Score:** 5/5 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
| --- | --- | --- | --- |
| `lib/utils/security_validation_result.dart` | Typed security validation outcomes | ✓ VERIFIED | Defines `ok/warning/blocking` model used by validators and dialog UX. |
| `lib/utils/security_policies.dart` | Centralized SSRF/security policy constants | ✓ VERIFIED | Host/port block lists consumed by input validation. |
| `lib/utils/input_validation.dart` | Canonical strict validation for command-injection/SSRF/path safety | ✓ VERIFIED | Substantive strict methods; wired into settings connector dialog and tests. |
| `lib/widgets/settings/remote_connection_dialog.dart` | Submit-time strict blocking + warning UX + escalation | ✓ VERIFIED | Calls strict validators; tracks blocked attempts and shows help guidance. |
| `lib/utils/path_guard.dart` | Canonical containment enforcement utility | ✓ VERIFIED | Decodes/normalizes and rejects root escapes; throws contextual exceptions. |
| `lib/services/persistence_service.dart` | Root-constrained app file IO | ✓ VERIFIED | All file access routes through guarded `_getFile`. |
| `lib/services/data_backup_service.dart` | Guarded import/export file path resolution | ✓ VERIFIED | Uses containment guard before read/write backup file operations. |
| `lib/services/secure_key_service.dart` | Secure storage boundary for TMDB/Stash keys | ✓ VERIFIED | Read/write/delete/migration APIs implemented on `flutter_secure_storage`. |
| `lib/providers/settings_provider.dart` | Secure-secret integration + adult privacy defaults | ✓ VERIFIED | Migrates legacy plaintext keys, persists non-secret settings only, coerces adult opt-in to bool false-by-default. |
| `lib/models/stash_endpoint.dart` | Endpoint serialization without secret leakage | ✓ VERIFIED | `toJson()` excludes `apiKey`; runtime key stays in secure storage. |
| `lib/router.dart` | Adult route redirect protection | ✓ VERIFIED | `appRedirectPath` blocks `/adult` when opt-in disabled. |
| `lib/widgets/navigation_dock.dart` | Adult navigation visibility gating | ✓ VERIFIED | Adult tab hidden unless `settings.enableAdultContent` is true. |
| `test/security/*.dart` phase suites | Security/privacy regression coverage | ✓ VERIFIED | All 6 phase security test files passed in this verification run. |

### Key Link Verification

| From | To | Via | Status | Details |
| --- | --- | --- | --- | --- |
| `lib/widgets/settings/remote_connection_dialog.dart` | `lib/utils/input_validation.dart` | Strict and typing-time validation pipeline | ✓ WIRED | Dialog calls `strictValidateHostname/WebDavUrl/Port/Username` and typing warnings. |
| `lib/utils/input_validation.dart` | `lib/utils/security_policies.dart` | Shared host/IP/port block policy checks | ✓ WIRED | Validator reads `blockedExactHosts`, `blockedMetadataHosts`, `blockedHostTokens`, `blockedPorts`. |
| `test/helpers/security_test_helpers.dart` | `test/security/command_injection_test.dart` | Block/allow assertion contract | ✓ WIRED | Tests use `expectSecurityBlocked/Allowed` across payload sets. |
| `lib/services/data_backup_service.dart` | `lib/utils/path_guard.dart` | Canonicalize/validate backup file paths before IO | ✓ WIRED | `resolveBackupPathWithinRoot` calls `PathGuard.requireContainedPath`. |
| `lib/services/persistence_service.dart` | `lib/utils/path_guard.dart` | Constrain app data file operations to app support root | ✓ WIRED | `_getFile` guards every filename before creating `File`. |
| `lib/providers/settings_provider.dart` | `lib/services/secure_key_service.dart` | Secret load/save/migration | ✓ WIRED | Provider uses secure read/write/delete + legacy migration helpers for TMDB/Stash keys. |
| `lib/widgets/settings/settings_metadata_section.dart` | `lib/providers/settings_provider.dart` | TMDB key update flow | ✓ WIRED | UI writes key via `settings.setTmdbApiKey(...)` on submit/test actions. |
| `lib/widgets/settings/settings_advanced_section.dart` | `lib/providers/settings_provider.dart` | Stash endpoint add/update key flow | ✓ WIRED | UI calls `addStashEndpoint`/`updateStashEndpoint`; provider persists secrets securely. |
| `lib/providers/settings_provider.dart` | `lib/router.dart` | `enableAdultContent` drives `/adult` redirect | ✓ WIRED | Router redirect function consumes `settings.enableAdultContent`. |
| `lib/providers/settings_provider.dart` | `lib/widgets/navigation_dock.dart` | Conditional Adult tab rendering | ✓ WIRED | Dock visibility helpers and widget state use `settings.enableAdultContent`. |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
| --- | --- | --- | --- | --- |
| SEC-01 | `01-01-PLAN.md` | User-provided inputs cannot trigger command execution or shell injection paths. | ✓ SATISFIED | Strict username/host validators block shell payloads in `lib/utils/input_validation.dart`; enforced in connector dialog; `test/security/command_injection_test.dart` passed. |
| SEC-02 | `01-02-PLAN.md` | Local file operations reject directory traversal attempts. | ✓ SATISFIED | `PathGuard` containment + pre-IO enforcement in persistence/backup services; `test/security/path_guard_test.dart` and `test/security/directory_traversal_test.dart` passed. |
| SEC-03 | `01-01-PLAN.md` | Remote URL and connector handling prevents SSRF-style unsafe target access. | ✓ SATISFIED | Host/IP/metadata and encoded bypass blocking in strict host/WebDAV validation; `test/security/ssrf_test.dart` passed. |
| SEC-04 | `01-03-PLAN.md` | Secrets/credentials are securely stored and never committed in plaintext artifacts. | ✓ SATISFIED | `SecureKeyService` + provider migration/indirection + `StashEndpoint.toJson()` redaction; `test/security/secret_storage_test.dart` passed. |
| SEC-05 | `01-04-PLAN.md` | Adult library hidden by default and only available through explicit opt-in. | ✓ SATISFIED | Default false + coercion in provider, explicit setup/settings toggles, route and nav gating, regression tests in `test/security/adult_privacy_test.dart`. |

Orphaned requirements for Phase 1 in `REQUIREMENTS.md`: none.

### Anti-Patterns Found

No blocker anti-patterns found in phase artifacts.

Notable non-blocking observation:
- `test/security/adult_privacy_test.dart` logs plugin-channel errors for `flutter_secure_storage`/`path_provider` in unit context, but assertions pass and behavior under test remains verified.

### Human Verification Required

None. All must-haves and requirement-linked behaviors are programmatically verified by code inspection and passing phase security tests.

### Gaps Summary

No gaps found. Phase goal achieved.

---

_Verified: 2026-03-01T10:09:31Z_
_Verifier: Claude (gsd-verifier)_
