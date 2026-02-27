# Architecture

**Analysis Date:** 2026-02-27

## Pattern Overview

**Overall:** Layered Flutter client with Provider-driven state, service-oriented integrations, and platform-adapter boundaries via conditional imports.

**Key Characteristics:**
- UI routing and composition are centralized in `lib/router.dart`, `lib/app.dart`, and screen modules under `lib/screens/`.
- Stateful application logic lives in `ChangeNotifier` providers under `lib/providers/`, with providers orchestrating service calls and persistence.
- Integrations and infrastructure concerns are isolated in `lib/services/` (TMDB, AniList, StashDB, Graph/OneDrive, remote protocols, persistence, monitoring).

## Layers

**Application Bootstrap Layer:**
- Purpose: Initialize runtime services, load persisted state, wire dependencies, and mount the app.
- Location: `lib/main.dart`, `lib/app.dart`
- Contains: Startup sequence, global error wiring, `MultiProvider` dependency graph, theme setup, router creation.
- Depends on: `lib/services/monitoring/monitoring.dart`, provider classes in `lib/providers/`, service classes in `lib/services/`.
- Used by: Flutter runtime entrypoint (`main()`).

**Navigation & Screen Composition Layer:**
- Purpose: Map URLs and app state to screens, enforce access/setup/profile redirects, and host tab shell navigation.
- Location: `lib/router.dart`, `lib/screens/main_screen.dart`, `lib/screens/*.dart`, `lib/screens/details/*.dart`
- Contains: `GoRouter` routes, `StatefulShellRoute` tab branches, details route normalization, feature screens.
- Depends on: Providers (`SettingsProvider`, `ProfileProvider`, `LibraryProvider`) and screen widgets.
- Used by: `MaterialApp.router` in `lib/app.dart`.

**State Orchestration Layer (Provider):**
- Purpose: Own mutable application state and coordinate side effects between UI and services.
- Location: `lib/providers/library_provider.dart`, `lib/providers/settings_provider.dart`, `lib/providers/profile_provider.dart`, `lib/providers/playback_provider.dart`
- Contains: Library item lifecycle, scan orchestration delegation, profile/session state, playback progress updates, persisted settings.
- Depends on: Models in `lib/models/`, services in `lib/services/`, utility modules in `lib/utils/`.
- Used by: Screens/widgets via `context.watch`, `context.read`, and `Consumer`.

**Domain Service Layer:**
- Purpose: Hold stateless or integration-focused business logic that providers call.
- Location: `lib/services/library_filter_service.dart`, `lib/services/library_import_export_service.dart`, `lib/services/local_scan_service.dart`, `lib/services/remote_scan_service.dart`, `lib/services/metadata_service.dart`, `lib/services/scan_orchestration_service.dart`
- Contains: Filtering/grouping/statistics logic, import/export merge rules, filesystem/remote scanning, metadata enrichment strategy, background scan state.
- Depends on: Models, protocol clients, external API services, utility helpers.
- Used by: `LibraryProvider` and screen-level workflows.

**Integration & Infrastructure Layer:**
- Purpose: Encapsulate external systems, credentials, and storage mechanisms.
- Location: `lib/services/tmdb_service.dart`, `lib/services/tmdb_discover_service.dart`, `lib/services/anilist_service.dart`, `lib/services/stash_db_service.dart`, `lib/services/trakt_service.dart`, `lib/services/graph_auth_service.dart`, `lib/services/remote_storage_service.dart`, `lib/services/persistence_service.dart`
- Contains: HTTP clients, GraphQL adapters, OAuth/device-code flows, secure token/password storage, file-based persistence abstraction.
- Depends on: `http`, `flutter_secure_storage`, `shared_preferences`, platform APIs.
- Used by: Providers and orchestration services.

**Platform Adapter Layer:**
- Purpose: Keep platform-specific logic isolated behind common API surfaces.
- Location: `lib/services/monitoring/monitoring.dart`, `lib/services/graph_auth_service.dart` + `lib/services/graph_auth_web.dart`/`lib/services/graph_auth_stub.dart`, `lib/utils/platform/platform.dart`, `lib/screens/video_player_screen.dart`, `lib/screens/remote_player_screen.dart`, `lib/utils/downloader/downloader.dart`
- Contains: Conditional exports/imports for web vs IO behavior.
- Depends on: Dart conditional libraries (`dart.library.io`, `dart.library.html`).
- Used by: App bootstrap, playback screens, scanning/runtime utilities.

## Data Flow

**Startup and Dependency Wiring:**

1. `lib/main.dart` initializes logging, dotenv loading, monitoring, media engine, auth/settings/profile providers, and library preload.
2. `lib/main.dart` creates service instances (`TmdbService`, `TmdbDiscoverService`, `MetadataService`) and injects providers/services through `MultiProvider`.
3. `lib/app.dart` creates the `GoRouter` via `createRouter` and renders `MaterialApp.router`.

**Library Scan and Ingestion:**

1. UI actions in screens/settings call `LibraryProvider` methods in `lib/providers/library_provider.dart`.
2. `LibraryProvider` dispatches scans to `LocalScanService`, `OneDriveScanService`, or `RemoteScanService`, while `ScanOrchestrationService` emits progress state.
3. Scanned `MediaItem` objects are merged into `_allItems`, optionally enriched through `MetadataService`, persisted via `PersistenceService`, then exposed as filtered `items` for UI.

**Playback and Watch-State Persistence:**

1. Screens call `PlaybackProvider.start`/`updateProgress` using `MediaItem` from library/discover flows.
2. `PlaybackProvider` writes watch progress to `ProfileProvider` (`profile_<id>_data.json`) and updates library item duration through `LibraryProvider.updateItem`.
3. `LibraryProvider.updateProfile` overlays user media data onto visible library items and notifies UI listeners.

**Discover and Remote Metadata Fetch:**

1. `DiscoverScreen` in `lib/screens/discover_screen.dart` calls `TmdbDiscoverService.fetchAll` with `DiscoverFilterNotifier` state.
2. `TmdbDiscoverService` fetches category lists, applies cache (memory + `SharedPreferences`), and returns `DiscoverBundle`.
3. `DetailsScreen` resolves by local library ID first; if missing, it fetches via `TmdbService`/`StashDbService` depending on route prefix.

**State Management:**
- Use `ChangeNotifier` providers as single-writer state owners (`lib/providers/*.dart`) and expose derived state/getters for screens/widgets.

## Key Abstractions

**Media Domain Objects:**
- Purpose: Represent library content, grouping, and user progress in serializable models.
- Examples: `lib/models/media_item.dart`, `lib/models/library_folder.dart`, `lib/models/user_profile.dart`
- Pattern: Mutable app state wrapped around mostly immutable/copy-with model instances and JSON mappers.

**Provider-Orchestrated Use Cases:**
- Purpose: Centralize workflows (scan, metadata refresh, profile filtering, playback progress).
- Examples: `lib/providers/library_provider.dart`, `lib/providers/playback_provider.dart`, `lib/providers/profile_provider.dart`
- Pattern: `ChangeNotifier` mediators call service layer, persist state, and emit UI updates.

**Stateless Service Utilities:**
- Purpose: Keep pure or reusable logic outside providers.
- Examples: `lib/services/library_filter_service.dart`, `lib/services/library_import_export_service.dart`
- Pattern: Static service classes with deterministic transformations and no widget/runtime dependencies.

**Protocol Client Wrappers:**
- Purpose: Hide transport-specific file browsing/streaming behavior.
- Examples: `lib/services/sftp_client.dart`, `lib/services/ftp_client_wrapper.dart`, `lib/services/webdav_client_wrapper.dart`
- Pattern: Shared `RemoteFile`/`RemoteStorageAccount` abstractions with protocol-specific implementations.

## Entry Points

**Flutter Runtime Entry:**
- Location: `lib/main.dart`
- Triggers: App process start on all Flutter targets.
- Responsibilities: Initialize runtime services, load persisted state, construct dependency graph, mount `FreakFlixApp`.

**Router and Navigation Entry:**
- Location: `lib/router.dart`
- Triggers: Route changes and app boot router resolution.
- Responsibilities: Redirect setup/profile/adult flows, map tab branches and global detail routes.

**Web OAuth Callback Entry:**
- Location: `web/auth-callback.html`
- Triggers: OAuth redirect completion in popup flow.
- Responsibilities: Parse auth response, post message to opener window, close popup.

**Serverless OAuth Exchange Entry:**
- Location: `netlify/functions/oauth-token.js`
- Triggers: POST calls from web OAuth client.
- Responsibilities: Exchange authorization code for Graph tokens, return CORS-enabled JSON payload.

## Error Handling

**Strategy:** Fail-soft with local fallback and UI continuity; log errors while returning safe defaults (`null`, empty collections, or unchanged models).

**Patterns:**
- Wrap IO/network operations in `try/catch` and degrade gracefully in services/providers (for example `lib/services/tmdb_service.dart`, `lib/services/persistence_service.dart`, `lib/providers/library_provider.dart`).
- Centralize startup/runtime crash capture with `runZonedGuarded`, `FlutterError.onError`, and `PlatformDispatcher.instance.onError` in `lib/main.dart`.

## Cross-Cutting Concerns

**Logging:** Structured app logging via `AppLogger` (`lib/utils/logger.dart`) and sensitive-safe logging via `SecureLogger` (`lib/utils/secure_logger.dart`).
**Validation:** Input and protocol safety checks via `lib/utils/input_validation.dart`, URL/video validators under `lib/utils/`.
**Authentication:** Microsoft Graph OAuth/device-code + token refresh in `lib/services/graph_auth_service.dart`, with web popup OAuth adapter in `lib/services/graph_auth_web.dart`.

---

*Architecture analysis: 2026-02-27*
