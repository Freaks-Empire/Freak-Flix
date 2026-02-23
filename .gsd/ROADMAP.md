# ROADMAP.md

> **Current Phase**: Not started
> **Milestone**: v2.0 — Clean Architecture

## Must-Haves (from SPEC)
- [ ] `LibraryProvider` decomposed into focused services (<300 lines)
- [ ] `settings_library_section.dart` decomposed into sub-widgets (<500 lines each)
- [ ] Detail screens deduplicated via shared base components
- [ ] State management re-architected
- [ ] Unit tests for all extracted services
- [ ] Zero behavior change verified

## Phases

### Phase 1: Extract LibraryProvider Services
**Status**: ⬜ Not Started
**Objective**: Decompose the 2,346-line `LibraryProvider` god class into focused, single-responsibility services while keeping `LibraryProvider` as a thin coordinator.

**Deliverables:**
- `lib/services/scan_service.dart` — Local folder scanning, file parsing, video detection
- `lib/services/onedrive_scan_service.dart` — OneDrive folder walking and item creation
- `lib/services/remote_scan_service.dart` — SFTP/FTP/WebDAV scanning
- `lib/services/library_filter_service.dart` — Filtered views, type filtering, genre extraction
- `lib/services/library_import_export_service.dart` — State export/import, legacy migration
- `lib/services/scan_notification_service.dart` — Scan progress, foreground tasks, notifications
- Lean `LibraryProvider` (<300 lines) coordinating above services

---

### Phase 2: Decompose Settings Library Section
**Status**: ⬜ Not Started
**Objective**: Split the 81KB `settings_library_section.dart` widget into focused sub-widgets, each handling a single settings concern.

**Deliverables:**
- `lib/widgets/settings/library/folder_management_section.dart` — Add/remove/edit library folders
- `lib/widgets/settings/library/scan_controls_section.dart` — Scan triggers, progress display
- `lib/widgets/settings/library/remote_storage_section.dart` — SFTP/FTP/WebDAV folder config
- `lib/widgets/settings/library/onedrive_section.dart` — OneDrive account and folder management
- `lib/widgets/settings/library/metadata_actions_section.dart` — Refetch, clean, sidecar actions
- `lib/widgets/settings/library/library_stats_section.dart` — Library statistics display
- Lean `settings_library_section.dart` composing sub-widgets

---

### Phase 3: Deduplicate Detail Screens
**Status**: ⬜ Not Started
**Objective**: Extract shared layout patterns from `MovieDetailsScreen` (33KB), `AnimeDetailsScreen` (30KB), and `SceneDetailsScreen` (34KB) into reusable base components.

**Deliverables:**
- `lib/widgets/details/detail_scaffold.dart` — Shared layout scaffold (backdrop, poster, info columns)
- `lib/widgets/details/detail_header.dart` — Shared header (title, year, rating, genres)
- `lib/widgets/details/detail_cast_section.dart` — Shared cast/performers section
- `lib/widgets/details/detail_action_bar.dart` — Shared action buttons (play, trailer, identify)
- Refactored detail screens using shared components (<500 lines each)

---

### Phase 4: State Management Migration
**Status**: ⬜ Not Started
**Objective**: Evaluate and migrate from `provider` to Riverpod (or chosen alternative) across the application, leveraging the clean service boundaries from Phases 1-3.

**Deliverables:**
- Technology decision documented in DECISIONS.md
- All providers migrated to new state management
- Router integration updated
- All screens updated to use new state access pattern

---

### Phase 5: Test Coverage & Verification
**Status**: ⬜ Not Started  
**Objective**: Add unit tests for extracted services, widget tests for decomposed UI, and verify zero behavior change across platforms.

**Deliverables:**
- Unit tests for all Phase 1 services
- Widget tests for Phase 2 sub-widgets
- Widget tests for Phase 3 shared detail components
- Integration test: full app build on Web, Windows, Android
- `flutter analyze` clean pass
