# Architectural Decision Records

> Decisions made during the v2.0 refactoring project.

## Phase 1 Decisions

**Date:** 2026-02-23

### Service Boundaries
- Split `LibraryProvider` into 6 extracted services:
  - `ScanOrchestrationService` — progress tracking, notifications, foreground tasks, wakelock
  - `LocalScanService` — local folder scanning, file parsing, video detection
  - `OneDriveScanService` — OneDrive folder walking and item creation
  - `RemoteScanService` — SFTP/FTP/WebDAV scanning
  - `LibraryFilterService` — filtered views, statistics, recommendations
  - `LibraryImportExportService` — state export/import, legacy migration, library cleaning
- `LibraryProvider` remains as thin coordinator (~300 lines): folder CRUD, item CRUD, save/load, reclassify

### Coupling Approach
- Chose: **Option A — stateless services returning data**
- Services return `List<MediaItem>` or results; `LibraryProvider` merges into `_allItems` and calls `notifyListeners()`
- Reason: Safer migration, keeps notification pattern unchanged, sets up cleanly for Phase 4 (Riverpod migration)

### Metadata Orchestration
- Chose: **Keep in LibraryProvider** as coordinator logic
- `refetchAllMetadata` and `_ingestItems` stay in provider — natural coordinator boundary
- Reason: These methods bridge scanning results and metadata enrichment, which is coordinator responsibility
