# Stack Research

**Domain:** Cross-platform personal media library manager/player (Flutter), local + cloud backends, serverless-first
**Researched:** 2026-02-27
**Confidence:** MEDIUM-HIGH

## Recommended Stack

### Core Technologies

| Technology | Version | Purpose | Why Recommended | Confidence |
|------------|---------|---------|-----------------|------------|
| Flutter | 3.38.x (pin to `3.38.4`) | Cross-platform app runtime for Windows/Android/Web | Already the project baseline, mature desktop/mobile/web support, and keeps one UI + state codebase. | HIGH |
| Dart | 3.10.x (pin to `3.10.3`) | Language/runtime | Matches current Flutter toolchain and enables modern async/FFI support needed by media + storage plugins. | HIGH |
| Provider | `6.1.5+1` | App state management | Existing architecture already uses Provider; incremental scaling with `ChangeNotifier` + selectors is lower-risk than a state rewrite. | HIGH |
| go_router | `17.1.0` | Declarative navigation + deep links | Official Flutter-maintained router with strong deep-link/web URL support (critical for Web parity). | HIGH |
| media_kit + media_kit_video | `1.2.6` + `2.0.1` | Media playback engine and video rendering | Broad codec/platform support (Windows/Android/Web included), active releases, and good fit for local + remote streams. | HIGH |
| Drift | `2.31.0` | Typed local metadata DB (library index, watch-state, sync queues) | Best fit for SQL-heavy metadata/search and migration safety; first-class web support via WASM path. | HIGH |

### Supporting Libraries

| Library | Version | Purpose | When to Use | Confidence |
|---------|---------|---------|-------------|------------|
| http | `1.6.0` | API client layer (TMDB/AniList/Graph/StashDB) | Keep for lightweight REST calls with strict URI validation wrappers. | HIGH |
| flutter_secure_storage | `10.0.0` | Secure token/secret storage | Store OAuth refresh tokens and backend credentials; never keep secrets in SharedPreferences. | HIGH |
| dartssh2 | `2.13.0` | SFTP transport | Use for SSH-backed media sources and remote file enumeration. | MEDIUM |
| ftpconnect | `2.0.10` | FTP fallback backend | Use only for legacy NAS/server targets where SFTP/WebDAV unavailable. | MEDIUM |
| webdav_client | `1.2.2` | WebDAV backend | Use for Nextcloud/WebDAV-compatible providers. | MEDIUM |
| file_picker | `10.3.10` | User-selected local paths/files | Use for explicit user-selected imports on desktop/mobile. | HIGH |
| connectivity_plus | `7.0.0` | Network awareness | Use for queueing sync retries and offline UX states. | HIGH |
| Firebase (optional): `firebase_core` + `firebase_crashlytics` + `firebase_analytics` | `4.4.0` + `5.0.7` + `12.1.2` | Serverless telemetry/crash pipeline | Use only if cloud telemetry is in scope; keep product usable without backend dependency. | MEDIUM |

### Development Tools

| Tool | Purpose | Notes | Confidence |
|------|---------|-------|------------|
| flutter_lints | Static analysis baseline | Keep CI gate with `flutter analyze`; extend rules for URI/path validation hotspots. | HIGH |
| flutter_test | Unit/widget/security tests | Keep security regression suites for command injection, traversal, SSRF. | HIGH |
| msix | Windows packaging | Keep for first-class Windows deliverable from CI. | HIGH |

## Installation

```bash
# Core runtime
flutter pub add provider go_router media_kit media_kit_video drift drift_flutter http flutter_secure_storage

# Storage backends + platform helpers
flutter pub add dartssh2 ftpconnect webdav_client file_picker connectivity_plus

# Optional serverless observability
flutter pub add firebase_core firebase_crashlytics firebase_analytics

# Dev dependencies
flutter pub add --dev flutter_lints
```

## Alternatives Considered

| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|-------------------------|
| Provider | Riverpod | Choose Riverpod only if you are planning a broad architecture refactor anyway; not worth migration cost for roadmap phase 1. |
| Drift | sqflite | Use sqflite only for mobile-only projects with minimal schema complexity; weaker first-class Windows/Web story for this product target. |
| media_kit | video_player (+ custom wrappers) | Use only if playback requirements are basic and codec/desktop coverage is narrow. |
| SFTP/WebDAV-first cloud file access | FTP-first | FTP only for unavoidable legacy endpoints; prefer encrypted transports. |

## What NOT to Use

| Avoid | Why | Use Instead | Confidence |
|-------|-----|-------------|------------|
| `sqlite3_flutter_libs` as a new dependency | Package is marked obsolete/EOL for sqlite3 v3 path; adds confusion without value in new builds. | Use current Drift/sqlite3 setup and follow sqlite3 v3 migration guidance. | HIGH |
| FTP as default remote protocol | Insecure by design (credentials/data in clear text unless tunneled); high risk for personal media credentials. | SFTP or HTTPS/WebDAV with TLS. | HIGH |
| Raw shell command execution for file/media ops | Directly violates command-injection constraints and expands attack surface. | Dart/Flutter APIs and strict argumentized process invocations only where unavoidable. | HIGH |
| Trusting user-provided full URLs for backend fetches | SSRF risk (private IP/metadata endpoints, redirect bypasses). | Allowlist host/scheme + IP range blocking + redirect controls. | HIGH |
| Direct path concatenation from user input | Path traversal risk and cross-platform path ambiguity. | Normalize/canonicalize and enforce base-directory boundaries. | HIGH |

## Stack Patterns by Variant

**If local-first single-user (default Freak-Flix mode):**
- Use Flutter + Provider + go_router + media_kit + Drift.
- Because this gives best offline behavior and lowest ops cost while supporting Windows/Android/Web from one codebase.

**If optional cloud sync/telemetry is enabled (serverless-first expansion):**
- Add Firebase core/crash/analytics only, keep playback and metadata logic local-first.
- Because product reliability should not depend on backend availability; cloud augments instead of gating core functionality.

**If enterprise/self-hosted connectors become priority:**
- Keep protocol adapters isolated (OneDrive Graph, SFTP, FTP, WebDAV) behind repository interfaces.
- Because connector churn should not force UI/state rewrites.

## Version Compatibility

| Package A | Compatible With | Notes |
|-----------|-----------------|-------|
| `flutter@3.38.x` | `dart@3.10.x` | Verified from local toolchain (`flutter --version`). |
| `provider@6.1.5+1` | Flutter SDK `>=1.16.0`, Dart `<4.0.0` | Safely within current toolchain constraints. |
| `go_router@17.1.0` | Flutter apps across Android/iOS/Linux/macOS/web/Windows | Track migration guides for major version jumps. |
| `media_kit@1.2.6` + `media_kit_video@2.0.1` | Android/iOS/Linux/macOS/web/Windows | Keep platform-specific `media_kit_libs_*` package versions aligned. |
| `drift@2.31.0` | Web via WASM worker + `sqlite3.wasm` | Web deployment requires correct `application/wasm`; COOP/COEP can conflict with popup-based auth flows. |

## Security Baseline (Mandatory for This Project)

- **Command injection:** no shell interpolation from user input; strict allowlists and API-based operations.
- **Path traversal:** canonicalize/normalize paths and enforce allowlisted roots before file access.
- **SSRF:** validate scheme/host/IP, block private/link-local/metadata ranges, and restrict redirects.

## Sources

- `flutter --version` (local environment, 2026-02-27) - verified active project baseline (`Flutter 3.38.4`, `Dart 3.10.3`) - **HIGH**
- https://pub.dev/packages/provider - package positioning and current release metadata - **HIGH**
- https://pub.dev/packages/go_router - routing capabilities, migration notes, feature-complete status - **HIGH**
- https://pub.dev/packages/media_kit - platform coverage and modular installation requirements - **HIGH**
- https://pub.dev/packages/drift and https://drift.simonbinder.eu/platforms/web/ - web WASM architecture, worker requirements, COOP/COEP caveats - **HIGH**
- https://pub.dev/packages/sqlite3_flutter_libs - deprecation/EOL notice for v3 migration path - **HIGH**
- https://pub.dev/packages/sqflite - platform scope and limitations for this target matrix - **HIGH**
- https://learn.microsoft.com/en-us/graph/api/resources/onedrive - OneDrive/DriveItem Graph model scope - **HIGH**
- https://owasp.org/www-community/attacks/Command_Injection - command injection baseline guidance - **HIGH**
- https://owasp.org/www-community/attacks/Path_Traversal - traversal prevention baseline guidance - **HIGH**
- https://cheatsheetseries.owasp.org/cheatsheets/Server_Side_Request_Forgery_Prevention_Cheat_Sheet.html - SSRF defensive controls and allowlist strategy - **HIGH**

---
*Stack research for: Freak-Flix (cross-platform personal media library manager/player)*
*Researched: 2026-02-27*
