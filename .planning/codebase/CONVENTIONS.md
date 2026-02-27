# Coding Conventions

**Analysis Date:** 2026-02-27

## Naming Patterns

**Files:**
- Use `snake_case.dart` across app code and tests (examples: `lib/providers/library_provider.dart`, `lib/services/metadata_service.dart`, `test/security/command_injection_test.dart`).
- Name feature folders by domain area (examples: `lib/screens/details/`, `lib/widgets/video_player/`, `test/security/`).

**Functions:**
- Use `camelCase` for methods and top-level functions (examples: `createRouter` in `lib/router.dart`, `validateHostname` in `lib/utils/input_validation.dart`, `refetchAllMetadata` in `lib/providers/library_provider.dart`).
- Use private helpers with `_` prefix for implementation details (examples: `_rebuildFilteredItems` in `lib/providers/library_provider.dart`, `_sanitizeUrl` in `lib/utils/logger.dart`, `_parseMediaItemExtra` in `lib/router.dart`).

**Variables:**
- Use `camelCase` for local/state variables and `final` where possible (examples in `lib/app.dart`, `lib/services/metadata_service.dart`).
- Use `_privateField` for encapsulated state in providers/services (examples: `_allItems` in `lib/providers/library_provider.dart`, `_isTestingTmdbKey` in `lib/providers/settings_provider.dart`).

**Types:**
- Use `PascalCase` for classes/enums (examples: `LibraryProvider`, `SettingsProvider`, `MediaItem`, `TmdbKeyStatus`).
- Use enum names in singular PascalCase with lowercase members (examples: `MediaType.movie`, `TmdbKeyStatus.valid` in `lib/models/media_item.dart`, `lib/providers/settings_provider.dart`).

## Code Style

**Formatting:**
- Tool used: `dart format` / `flutter format` per contributor docs in `CONTRIBUTING.md` and `AGENTS.md`.
- Key settings: no custom formatter config detected (`.prettierrc`, `biome.json`, and ESLint configs are not present at repo root).
- Use single quotes in Dart source by convention (examples in `lib/main.dart`, `lib/router.dart`, `test/security/ssrf_test.dart`).

**Linting:**
- Tool used: Flutter analyzer with `flutter_lints` via `analysis_options.yaml`.
- Key rules in `analysis_options.yaml`: `avoid_print: false`, `prefer_const_declarations: false`.
- File-level lint suppressions are used where required (example: `// ignore_for_file: avoid_print` in `lib/services/metadata_service.dart`).

## Import Organization

**Order:**
1. Preferred order is documented in `AGENTS.md`: `dart:*` first, then `package:flutter/*`, then third-party packages, then local relative imports.
2. Many files use grouped imports with blank lines (example: `lib/app.dart`).
3. Mixed ordering exists in core files, so follow local file style when editing existing code (examples: `lib/main.dart`, `lib/providers/library_provider.dart`).

**Path Aliases:**
- No custom import aliases configured.
- Use relative imports inside `lib/` (`../models/...`, `services/...`) and package imports for tests (`package:freak_flix/...` in `test/security/*.dart`).

## Error Handling

**Patterns:**
- Wrap async I/O and network operations in `try/catch` and preserve app responsiveness with fallback state updates (examples: `loadLibrary` in `lib/providers/library_provider.dart`, `load` in `lib/providers/settings_provider.dart`).
- Return safe defaults on validation failures (example validators returning error message or `null` in `lib/utils/input_validation.dart`).
- Use `finally` blocks to reset flags and notify listeners in provider workflows (examples: `rescanFolder`, `rescanAll` in `lib/providers/library_provider.dart`).

## Logging

**Framework:** `AppLogger` utility in `lib/utils/logger.dart` with fallback `print`/`debugPrint` in selected services.

**Patterns:**
- Prefer structured logger methods (`AppLogger.d/i/w/e/security/...`) with optional `tag`, `error`, and `stackTrace` (examples in `lib/main.dart`, `lib/providers/settings_provider.dart`).
- Sanitize sensitive values before log output using `InputValidation.sanitizeForLogging` (`lib/utils/logger.dart`, `lib/utils/input_validation.dart`).
- For cross-platform startup/runtime errors, wire global handlers (`FlutterError.onError`, `PlatformDispatcher.instance.onError`) as in `lib/main.dart`.

## Comments

**When to Comment:**
- Start files with header comments that include canonical path (pattern appears across most files in `lib/` and all files in `test/`).
- Add short intent comments for non-obvious branches and migration logic (examples: migration notes in `lib/providers/library_provider.dart`, redirect sections in `lib/router.dart`).

**JSDoc/TSDoc:**
- Use Dart doc comments (`///`) on files and selected APIs; no JSDoc/TSDoc tooling is used.

## Function Design

**Size:**
- Providers/services include long orchestration methods for scan/metadata flows (example: `LibraryProvider` in `lib/providers/library_provider.dart`), and helper extraction is used for repeated behaviors (`_queuePersistentMetadata`, `_scanLocalFolder`).

**Parameters:**
- Prefer named optional parameters for readability in async workflows (examples: `rescanFolder({required ...})`, `network(String method, String url, {int? statusCode, String? tag})`).
- Use nullable types explicitly and validate early (examples in `lib/utils/input_validation.dart`, `lib/providers/settings_provider.dart`).

**Return Values:**
- Validation APIs return `String?` error message where `null` means valid (`lib/utils/input_validation.dart`).
- Provider mutation methods typically return `Future<void>` and communicate state via `notifyListeners()` (`lib/providers/*.dart`).

## Module Design

**Exports:**
- Use direct file imports for most modules.
- Use conditional exports for platform-specific implementations:
  - `lib/services/monitoring/monitoring.dart`
  - `lib/utils/platform/platform.dart`
  - `lib/screens/video_player_screen.dart`
  - `lib/utils/downloader/downloader.dart`

**Barrel Files:**
- Barrel usage is limited and primarily for platform abstraction via conditional exports; broad feature barrel files are not a common pattern.

---

*Convention analysis: 2026-02-27*
