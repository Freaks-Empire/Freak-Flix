# Codebase Structure

**Analysis Date:** 2026-02-27

## Directory Layout

```text
Freak-Flix/
├── lib/                    # Flutter application source (entry, state, services, UI)
│   ├── main.dart           # Runtime bootstrap and dependency wiring
│   ├── app.dart            # MaterialApp and theme shell
│   ├── router.dart         # GoRouter graph and redirect rules
│   ├── models/             # Data models and JSON mappers
│   ├── providers/          # ChangeNotifier state orchestrators
│   ├── services/           # Integrations, scanning, persistence, orchestration
│   ├── screens/            # Route-level UI screens
│   ├── widgets/            # Reusable UI components
│   └── utils/              # Shared helpers, validators, platform adapters
├── test/                   # Automated tests (security-first currently)
├── web/                    # Flutter web host assets and OAuth callback page
├── netlify/                # Serverless web support (OAuth token exchange)
├── android/ ios/ macos/ linux/ windows/  # Platform host runners/build configs
├── assets/                 # Packaged app assets (logo, icons)
├── docs/                   # Docs and release artifacts
├── scripts/                # Validation and search helper scripts
├── .github/workflows/      # CI/CD workflows
├── pubspec.yaml            # Flutter package manifest
└── analysis_options.yaml   # Lint configuration
```

## Directory Purposes

**`lib/`:**
- Purpose: All production Dart/Flutter application code.
- Contains: Runtime bootstrap, navigation, business state, integrations, UI, utility helpers.
- Key files: `lib/main.dart`, `lib/app.dart`, `lib/router.dart`.

**`lib/models/`:**
- Purpose: Core domain and API DTO models.
- Contains: JSON serializers, enum mappers, immutable/copy-with model classes.
- Key files: `lib/models/media_item.dart`, `lib/models/library_folder.dart`, `lib/models/user_profile.dart`.

**`lib/providers/`:**
- Purpose: App state owners and orchestration boundaries.
- Contains: `ChangeNotifier` classes for library/settings/profile/playback state.
- Key files: `lib/providers/library_provider.dart`, `lib/providers/settings_provider.dart`, `lib/providers/profile_provider.dart`, `lib/providers/playback_provider.dart`.

**`lib/services/`:**
- Purpose: Integration and domain services used by providers/screens.
- Contains: Metadata/API clients, scan services, persistence/auth/storage wrappers, monitoring adapters.
- Key files: `lib/services/metadata_service.dart`, `lib/services/tmdb_service.dart`, `lib/services/graph_auth_service.dart`, `lib/services/remote_storage_service.dart`, `lib/services/persistence_service.dart`.

**`lib/screens/`:**
- Purpose: Route-level feature screens and screen-specific wiring.
- Contains: Top-level tabs, setup/profile/details/player flows.
- Key files: `lib/screens/discover_screen.dart`, `lib/screens/setup_screen.dart`, `lib/screens/details_screen.dart`, `lib/screens/main_screen.dart`.

**`lib/widgets/`:**
- Purpose: Reusable visual components shared across screens.
- Contains: Cards, navigation controls, settings sections, player controls.
- Key files: `lib/widgets/navigation_dock.dart`, `lib/widgets/home_media_card.dart`, `lib/widgets/settings/`, `lib/widgets/video_player/`.

**`lib/utils/`:**
- Purpose: Shared utilities and platform abstraction modules.
- Contains: Validation/logging/parser helpers and conditional exports for platform-specific behavior.
- Key files: `lib/utils/input_validation.dart`, `lib/utils/logger.dart`, `lib/utils/secure_logger.dart`, `lib/utils/platform/platform.dart`.

**`test/`:**
- Purpose: Automated test suite.
- Contains: Security regression tests and test helper utilities.
- Key files: `test/security/command_injection_test.dart`, `test/security/directory_traversal_test.dart`, `test/security/ssrf_test.dart`, `test/helpers/security_test_helpers.dart`.

**`web/`:**
- Purpose: Flutter web shell assets and auth callback handler.
- Contains: `index.html`, PWA manifest, OAuth callback page.
- Key files: `web/auth-callback.html`, `web/index.html`.

**`netlify/`:**
- Purpose: Serverless support for web OAuth token exchange.
- Contains: Netlify build script and function handlers.
- Key files: `netlify/functions/oauth-token.js`, `netlify/build.sh`.

## Key File Locations

**Entry Points:**
- `lib/main.dart`: Primary runtime entrypoint and dependency initialization.
- `lib/router.dart`: Central route graph and redirect logic.
- `web/auth-callback.html`: OAuth callback entry for web popup flow.
- `netlify/functions/oauth-token.js`: Serverless OAuth code-to-token exchange endpoint.

**Configuration:**
- `pubspec.yaml`: Dependency graph, assets, app versioning, MSIX metadata.
- `analysis_options.yaml`: Linter baseline and project-level lint overrides.
- `.github/workflows/flutter-windows.yml`: Windows CI pipeline.
- `.github/workflows/flutter-android.yml`: Android CI pipeline.
- `.github/workflows/build-windows.yml`: Windows release/build automation.

**Core Logic:**
- `lib/providers/library_provider.dart`: Scan orchestration + library ingest + persistence + filtering pivot.
- `lib/services/metadata_service.dart`: Metadata routing policy (TMDB/AniList/StashDB/Trakt interplay).
- `lib/services/local_scan_service.dart`: Isolate-based local file scanning.
- `lib/services/remote_scan_service.dart`: Protocol-dispatched remote scan recursion.
- `lib/services/graph_auth_service.dart`: OneDrive auth/token lifecycle and Graph operations.

**Testing:**
- `test/security/`: Security-focused input validation and SSRF/path traversal checks.
- `test/helpers/security_test_helpers.dart`: Shared security assertion helpers.

## Naming Conventions

**Files:**
- `snake_case.dart` for Dart sources: `library_provider.dart`, `tmdb_discover_service.dart`, `actor_details_screen.dart`.
- Platform-variant suffixes for conditional implementations: `*_stub.dart`, `*_web.dart`, `*_native.dart`, `*_mpv.dart` (for example `lib/screens/video_player_screen_stub.dart`, `lib/screens/remote_player_native.dart`).

**Directories:**
- Category-based plural folders under `lib/`: `models/`, `providers/`, `services/`, `screens/`, `widgets/`, `utils/`.
- Feature subfolders for focused UI/service domains: `lib/screens/details/`, `lib/widgets/settings/`, `lib/widgets/video_player/`, `lib/services/monitoring/`.

## Where to Add New Code

**New Feature:**
- Primary code: Add route-level screen to `lib/screens/` and wire route in `lib/router.dart`; add state workflow to `lib/providers/` if persistent/multi-screen state is required.
- Tests: Add security/regression tests under `test/security/` or domain-specific tests under `test/unit/`.

**New Component/Module:**
- Implementation: Add reusable UI component in `lib/widgets/` (or feature subdir like `lib/widgets/settings/`) and consume from screen files in `lib/screens/`.

**Utilities:**
- Shared helpers: Add pure utility functions to `lib/utils/`; for external integration logic, place in `lib/services/` instead of `lib/utils/`.

## Special Directories

**`.planning/codebase/`:**
- Purpose: Generated architecture/stack/convention mapping docs for GSD orchestration.
- Generated: Yes (by mapping commands).
- Committed: Yes.

**`.dart_tool/`:**
- Purpose: Flutter/Dart build metadata and tool state.
- Generated: Yes.
- Committed: No.

**`android/build/`:**
- Purpose: Android build outputs and reports.
- Generated: Yes.
- Committed: No.

**`docs/`:**
- Purpose: Human documentation and release artifacts (includes `.msix` outputs currently present).
- Generated: Mixed (manual docs + packaged artifacts).
- Committed: Yes.

**`windows/`, `android/`, `ios/`, `macos/`, `linux/`:**
- Purpose: Platform host project files and native runner/configuration.
- Generated: Mixed (Flutter-generated baseline plus project customizations).
- Committed: Yes.

---

*Structure analysis: 2026-02-27*
