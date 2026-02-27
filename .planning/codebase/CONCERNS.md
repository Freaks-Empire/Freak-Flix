# Codebase Concerns

**Analysis Date:** 2026-02-27

## Tech Debt

**Monolithic UI/feature files:**
- Issue: Several screens/widgets contain 500-2250+ lines with mixed UI, state, networking, and navigation logic, which increases change blast radius.
- Files: `lib/widgets/settings/settings_library_section.dart`, `lib/providers/library_provider.dart`, `lib/services/stash_db_service.dart`, `lib/services/graph_auth_service.dart`, `lib/screens/details/actor_details_screen.dart`, `lib/screens/details/scene_details_screen.dart`, `lib/screens/details/movie_details_screen.dart`, `lib/screens/details/anime_details_screen.dart`
- Impact: Small feature edits are high-risk, code review is slower, and regressions are harder to isolate.
- Fix approach: Extract service/use-case classes from widget files, split large widgets into focused sections, and enforce max file/function size thresholds in CI.

**Silent exception handling in core flows:**
- Issue: Multiple `catch (_) {}` blocks swallow failures without observability.
- Files: `lib/providers/library_provider.dart`, `lib/services/local_scan_service.dart`, `lib/services/onedrive_scan_service.dart`, `lib/services/library_import_export_service.dart`, `lib/services/sftp_client.dart`, `lib/services/webdav_client_wrapper.dart`, `lib/screens/details_screen.dart`
- Impact: Data migration, scanning, and metadata failures can appear as missing content rather than actionable errors.
- Fix approach: Replace silent catches with typed exceptions and structured logging via `SecureLogger`/`AppLogger` including operation context.

**High analyzer warning volume:**
- Issue: `flutter analyze` reports widespread unused imports/fields, deprecated APIs (`withOpacity`, `dart:html`, `dart:js`), and async context safety warnings.
- Files: `lib/` (repo-wide; examples: `lib/main.dart`, `lib/screens/details/scene_details_screen.dart`, `lib/services/graph_auth_web.dart`, `lib/widgets/discover_card.dart`)
- Impact: Signal-to-noise in static checks is low, real regressions are easier to miss, and migration to newer Flutter SDKs is riskier.
- Fix approach: Establish warning budget, fix by category (unused/deprecated/async), and fail CI on new warnings.

## Known Bugs

**Security test assertions are inverted and fail baseline:**
- Symptoms: `flutter test` fails across security suites; blocked inputs are asserted as `null` and safe inputs as non-null.
- Files: `test/helpers/security_test_helpers.dart`, `test/security/command_injection_test.dart`, `test/security/directory_traversal_test.dart`, `test/security/ssrf_test.dart`
- Trigger: Run `flutter test` or any `test/security/*.dart` file.
- Workaround: None in tests; update helper expectations (`blocked => isNotNull`, `allowed => isNull`) and regenerate baselines.

**Local playback can be rejected by URL validation:**
- Symptoms: Local filesystem paths can be flagged as invalid protocol before playback starts.
- Files: `lib/screens/video_player_screen_mpv.dart`, `lib/utils/url_validator.dart`, `lib/services/local_scan_service.dart`
- Trigger: Play a local media item where `filePath` is a native OS path (e.g., Windows drive path) and no `file://` scheme is present.
- Workaround: Use `streamUrl` when available; otherwise normalize local paths to `file://` before validation.

**Backup/export drops playback state fields:**
- Symptoms: `lastPositionSeconds`, `totalDurationSeconds`, and `streamUrl` can be lost after export/import or persistence round-trips.
- Files: `lib/models/media_item.dart`, `lib/services/data_backup_service.dart`
- Trigger: Serialize with `MediaItem.toJson()` and restore with `MediaItem.fromJson()`.
- Workaround: Not reliable; add missing fields to `toJson()` and validate with regression tests.

**Incomplete remote feature paths visible in UI:**
- Symptoms: Quick actions display "Coming Soon"; remote folder add flow explicitly skips scan after add.
- Files: `lib/screens/user_panel_screen.dart`, `lib/widgets/settings/settings_library_section.dart`
- Trigger: Use quick actions or add remote folder from settings.
- Workaround: Manual rescan via library actions.

## Security Considerations

**Credentials embedded in stream URLs:**
- Risk: WebDAV stream URL includes username/password in URI, which can leak via logs, crash reports, process lists, and URL handlers.
- Files: `lib/services/webdav_client_wrapper.dart`
- Current mitigation: Connection validation and secure storage for credentials.
- Recommendations: Remove credential-in-URL pattern; stream via authenticated client/session or short-lived signed proxy URL.

**Insecure transport protocol (FTP) remains enabled:**
- Risk: FTP transmits credentials/data in plaintext; MITM and credential reuse exposure remain possible.
- Files: `lib/services/ftp_client_wrapper.dart`, `lib/services/remote_storage_service.dart`
- Current mitigation: User-facing warning text only.
- Recommendations: Gate FTP behind explicit unsafe-mode setting, default disabled; prefer SFTP/WebDAV only.

**`.env` packaged into app assets:**
- Risk: Runtime bundle may include secrets if `.env` contains production keys.
- Files: `.env` (present), `pubspec.yaml`
- Current mitigation: `.env` is not tracked in git (`.env.example` is tracked).
- Recommendations: Stop bundling `.env` in `flutter.assets`; inject secrets through build-time configuration/secure runtime channels.

**Custom key "encryption" is reversible and fallback weakens guarantees:**
- Risk: XOR with derived key is obfuscation, not strong encryption; fallback returns deterministic key material.
- Files: `lib/services/secure_key_service.dart`
- Current mitigation: Uses `flutter_secure_storage` for at-rest storage.
- Recommendations: Remove custom cryptography; rely on platform keystore only or standard audited crypto with authenticated encryption.

## Performance Bottlenecks

**Full-library rewrites on updates:**
- Problem: Entire media list is serialized/compressed and written on save paths, including item updates.
- Files: `lib/providers/library_provider.dart`, `lib/services/persistence_service.dart`, `lib/providers/playback_provider.dart`
- Cause: `saveLibrary()` rewrites full `library_items.gz`; `updateItem()` invokes full save.
- Improvement path: Use incremental persistence (chunked DB/file segments) and debounce/batch save operations.

**Frequent fire-and-forget profile writes:**
- Problem: Playback progress updates trigger immediate disk writes without coalescing.
- Files: `lib/providers/profile_provider.dart`, `lib/providers/playback_provider.dart`, `lib/services/persistence_service.dart`
- Cause: `updateProgress()` calls `_saveUserData()` on each update and does not await/coalesce.
- Improvement path: Debounce writes (e.g., 2-5s), batch by media ID, and flush on app background/exit.

**Recursive remote scans without paging/depth guards:**
- Problem: Large remote hierarchies can create long scans and memory growth.
- Files: `lib/services/remote_scan_service.dart`
- Cause: Recursive traversal accumulates full `List<MediaItem>` in memory; no depth/page limits.
- Improvement path: Stream results incrementally, add depth/entry limits, and support resumable scans.

## Fragile Areas

**Remote path/id conventions are string-coupled across modules:**
- Files: `lib/services/remote_scan_service.dart`, `lib/services/sftp_streaming_service.dart`, `lib/providers/library_provider.dart`, `lib/widgets/settings/settings_library_section.dart`
- Why fragile: Multiple ad-hoc formats (`sftp:accountId:/path`, `protocol:accountId:path`, `onedrive_{account}_{id}`) are parsed via split/substrings in many places.
- Safe modification: Centralize parse/format into one typed value object and migrate all call sites.
- Test coverage: No targeted parser contract tests in `test/`.

**Web/video platform-specific code uses deprecated web APIs:**
- Files: `lib/screens/video_player_screen_stub.dart`, `lib/screens/remote_player_web.dart`, `lib/services/graph_auth_web.dart`, `lib/widgets/ads/web_banner_impl.dart`
- Why fragile: Direct `dart:html`/`dart:js` usage is deprecated and can break with future Flutter web runtime changes.
- Safe modification: Move to `package:web` and `dart:js_interop`; isolate platform bridges behind stable interfaces.
- Test coverage: No web player integration tests detected.

**Long-lived timers/services with limited lifecycle ownership:**
- Files: `lib/services/auto_backup_manager.dart`, `lib/services/scan_orchestration_service.dart`, `lib/main.dart`
- Why fragile: Timer/foreground task lifecycle is not clearly tied to app lifecycle teardown paths.
- Safe modification: Register explicit dispose/teardown hooks at app shutdown and provider disposal boundaries.
- Test coverage: No lifecycle tests for timer/task cleanup.

## Scaling Limits

**Library data model scales in-memory first:**
- Current capacity: Entire catalog loaded into `_allItems` and repeatedly copied/filtered in memory.
- Limit: Large libraries increase startup time, memory pressure, and save latency.
- Scaling path: Move to indexed local database (SQLite/Drift/Isar), load paged views, and query by folder/type/profile filters.

**Remote streaming cache lacks eviction policy:**
- Current capacity: SFTP cache grows by downloaded files only.
- Limit: Temp storage can grow unbounded over time.
- Scaling path: Add TTL/size-based eviction and enforce quota in `SftpStreamingService`.

## Dependencies at Risk

**Web API dependency surface relies on deprecated Dart web libraries:**
- Risk: `dart:html` and `dart:js` deprecations increase break risk on Flutter upgrades.
- Impact: Web playback/auth/ads code paths may fail during SDK migration.
- Migration plan: Replace with `package:web` + JS interop wrappers and add smoke tests for auth and playback.

## Missing Critical Features

**Production observability is effectively disabled:**
- Problem: Monitoring and analytics are currently stubbed/no-op in active paths.
- Blocks: Reliable incident triage, error-rate monitoring, and feature usage tracking.
- Files: `lib/services/monitoring/monitoring_mobile.dart`, `lib/services/monitoring/monitoring_web.dart`, `lib/services/analytics_service.dart`

**FTP playback/download path is incomplete:**
- Problem: Byte download for FTP throws `UnimplementedError`.
- Blocks: Consistent remote playback behavior for FTP sources.
- Files: `lib/services/ftp_client_wrapper.dart`

## Test Coverage Gaps

**Core providers/services are largely untested:**
- What's not tested: Library scanning/ingestion, remote scan path parsing, backup/restore round-trip, playback persistence behavior.
- Files: `lib/providers/library_provider.dart`, `lib/providers/profile_provider.dart`, `lib/services/remote_scan_service.dart`, `lib/services/data_backup_service.dart`, `lib/services/sftp_streaming_service.dart`
- Risk: Regressions in persistence and scanning are likely to ship undetected.
- Priority: High

**No widget/integration test coverage for major UI flows:**
- What's not tested: Settings connection flows, details screens, player screens, quick actions, profile management.
- Files: `lib/screens/`, `lib/widgets/`
- Risk: Navigation and UI regressions are discovered only manually.
- Priority: Medium

**Security tests currently provide false confidence:**
- What's not tested: Correct pass/fail semantics due to helper inversion and absent CI gating.
- Files: `test/helpers/security_test_helpers.dart`, `test/security/*.dart`
- Risk: Security regressions can be masked by invalid test assertions.
- Priority: High

---

*Concerns audit: 2026-02-27*
