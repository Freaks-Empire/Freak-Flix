# Technology Stack

**Analysis Date:** 2026-02-27

## Languages

**Primary:**
- Dart (SDK constraint `>=3.10.3 <4.0.0` in `pubspec.lock`) - app logic and UI in `lib/**/*.dart`

**Secondary:**
- Kotlin (Android host app) - Android entrypoint/build integration in `android/app/src/main/kotlin/com/freak/freakflix/MainActivity.kt` and `android/app/build.gradle.kts`
- C++/CMake (Windows host app) - Windows runner and packaging glue in `windows/runner/*` and `windows/CMakeLists.txt`
- JavaScript (serverless function) - Netlify OAuth token exchange in `netlify/functions/oauth-token.js`
- YAML/TOML/Bash/PowerShell (automation) - CI/CD and deployment scripts in `.github/workflows/*.yml`, `netlify.toml`, and `netlify/build.sh`

## Runtime

**Environment:**
- Flutter SDK `>=3.38.4` and Dart `>=3.10.3` (from `pubspec.lock`)
- Multi-platform runtime targets: Windows, Android, Web (declared in `README.md` and build workflows in `.github/workflows/*.yml`)

**Package Manager:**
- Dart/Flutter Pub (`flutter pub get` used in `.github/workflows/flutter-windows.yml` and `.github/workflows/flutter-android.yml`)
- Lockfile: present at `pubspec.lock`

## Frameworks

**Core:**
- Flutter - cross-platform UI/runtime (`pubspec.yaml`, `lib/main.dart`)
- Provider (`provider`) - state management (`lib/main.dart` providers and `lib/providers/*.dart`)
- GoRouter (`go_router`) - client-side routing (`lib/router.dart`)

**Testing:**
- `flutter_test` - unit/widget test runner (`pubspec.yaml`)
- `flutter_lints` - static lint baseline (`analysis_options.yaml`)

**Build/Dev:**
- Flutter CLI - build and run commands in `README.md` and `.github/workflows/*.yml`
- MSIX (`msix`) - Windows installer packaging in `pubspec.yaml` (`msix_config`)
- Netlify build pipeline - web deploy build in `netlify.toml` and `netlify/build.sh`
- GitHub Actions - CI/build/release automation in `.github/workflows/build-windows.yml`, `.github/workflows/flutter-windows.yml`, `.github/workflows/flutter-android.yml`

## Key Dependencies

**Critical:**
- `http` - external API calls across metadata/auth/storage services (`lib/services/tmdb_service.dart`, `lib/services/anilist_service.dart`, `lib/services/graph_auth_service.dart`)
- `media_kit` + platform libs - video playback runtime (`pubspec.yaml`, `lib/main.dart`)
- `flutter_dotenv` - environment variable loading (`lib/main.dart`, `lib/services/graph_auth_service.dart`, `lib/providers/settings_provider.dart`)
- `shared_preferences` + `path_provider` - local persistence/cache (`lib/services/persistence_service.dart`, `lib/providers/settings_provider.dart`)

**Infrastructure:**
- `flutter_secure_storage` - secure storage for tokens/passwords/API keys (`lib/services/graph_auth_service.dart`, `lib/services/remote_storage_service.dart`, `lib/services/secure_key_service.dart`)
- `dartssh2`, `ftpconnect`, `webdav_client` - remote storage protocol clients (`lib/services/sftp_client.dart`, `lib/services/ftp_client_wrapper.dart`, `lib/services/webdav_client_wrapper.dart`)
- `newrelic_mobile` - mobile observability SDK integration point (`lib/services/monitoring/monitoring_mobile.dart`, Android plugin in `android/app/build.gradle.kts`)

## Configuration

**Environment:**
- App loads `.env` at startup via `dotenv.load` in `lib/main.dart`
- Required/used keys in code: `TMDB_API_KEY` (`lib/providers/settings_provider.dart`, `lib/services/secure_key_service.dart`), `GRAPH_CLIENT_ID`/`GRAPH_TENANT_ID` (`lib/services/graph_auth_service.dart`), `TRAKT_CLIENT_ID` (`lib/services/trakt_service.dart`)
- Alternative compile-time injection uses `--dart-define` in `.github/workflows/build-windows.yml` and `.github/workflows/flutter-windows.yml`
- `.env` and `.env.example` are present at repo root and used for environment configuration

**Build:**
- Lint/analyzer config: `analysis_options.yaml`
- Android build config: `android/app/build.gradle.kts`
- Windows build config: `windows/CMakeLists.txt`
- Web deploy config: `netlify.toml` and `netlify/build.sh`
- Firebase project metadata file exists at `firebase.json`; app runtime Firebase config in `lib/firebase_options.dart` is marked removed

## Platform Requirements

**Development:**
- Flutter SDK version aligned with `pubspec.lock` (`>=3.38.4`)
- Android pipeline requires Java 17 (`.github/workflows/flutter-android.yml`)
- Windows desktop development/build support is enabled in workflows (`flutter config --enable-windows-desktop` in `.github/workflows/flutter-windows.yml`)

**Production:**
- Windows desktop executable and ZIP/MSIX distribution (`.github/workflows/build-windows.yml`, `pubspec.yaml`)
- Android APK release artifact (`.github/workflows/flutter-android.yml`)
- Web static deployment on Netlify (`netlify.toml`, `netlify/build.sh`)

---

*Stack analysis: 2026-02-27*
