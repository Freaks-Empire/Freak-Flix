# Phase 4 Research: Library Ingestion and Indexing

**Phase:** 4 - Library Ingestion and Indexing
**Researched:** 2026-03-07
**Requirements addressed:** ONB-05, LIB-01, LIB-02, LIB-03, LIB-04, LIB-05, PLAT-03

## Scope

Build scalable scan/index workflows for mixed storage libraries. Users can start scans, monitor progress, manage multiple libraries, and maintain responsive performance on large collections through incremental updates.

## Key Technical Areas

### 1. Scan Engine Architecture

**Current state:**
- LibraryProvider has `pickAndScan` method
- RemoteStorageService manages SFTP/FTP/WebDAV connections
- GraphAuthService handles OneDrive

**Needed:**
- Unified scan orchestrator that handles local + remote sources
- Progress tracking with cancellable operations
- Background task support for long-running scans
- Platform-specific considerations (foreground service on Android, web limitations)

**Recommendations:**
- Extend ScanOrchestrationService (already exists in codebase)
- Add scan job queue for multiple libraries
- Use platform channels for native file watching on desktop

### 2. Filename Parsing Patterns

**Movie patterns to support:**
- `Movie Title (2024).mp4`
- `Movie.Title.2024.1080p.BluRay.x264-RARBG.mp4`
- `Movie.Title.2024.PROPER.2160p.WEB.h264-NOGRP.mkv`

**TV/Anime patterns:**
- `Show S01E01 Episode Title.mp4`
- `Show 1x01 Episode Title.mkv`
- `Show Season 1 Episode 01 Episode Title.mp4`
- `Anime - 001 [720p].mkv`
- `Anime S01E01 [1080p].mkv`

**Recommendations:**
- Use regex-based parser (e.g., `file_name_parser` package or custom)
- Build pattern library with priority ordering
- Support common scene release naming conventions

### 3. Library Management

**Current state:**
- LibraryFolder model exists with type, path, accountId
- Multiple library types: movies, tv, anime, adult, other

**Needed:**
- CRUD operations for library management
- Type/source association validation
- Library metadata (name, path, type, enabled)
- Delete/cancel scan operations

**Recommendations:**
- Add Library model with metadata, scan state, item count
- Extend LibraryProvider with library CRUD methods
- Store library config in SharedPreferences/JSON

### 4. Incremental Scanning

**Challenge:** Large libraries need responsive re-scans without full rebuilds.

**Approaches:**
- File hash + size + modification time for change detection
- Database with timestamps for incremental updates
- Background periodic scans with platform notifications

**Recommendations:**
- Use SQLite (sqflite) for local database
- Track: file_path, file_hash, size, mod_time, media_item_id
- Delta detection: new, changed, deleted since last scan
- Configurable scan interval (manual, hourly, daily)

### 5. Platform Performance

**Requirements from PLAT-03:**
- Responsive UI during scans
- Cancellable long operations
- Progress reporting

**Platform considerations:**
- Android: Foreground service + notification
- Windows: Background isolate for scanning
- Web: Limited - use chunked scanning with progress

## Integration Points

### Existing Services
- `RemoteStorageService` - remote file enumeration
- `GraphAuthService` - OneDrive file access
- `ScanOrchestrationService` - progress tracking (extend)
- `LibraryProvider` - library state management

### New Dependencies Needed
- `file_name_parser` or custom regex library
- `sqflite` for local database (if not already)
- `path` package for cross-platform path handling

## Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|-------------|
| Slow scans on large libraries | User frustration | Incremental scanning, background processing |
| Parsing edge cases | Missing metadata | Multiple pattern support, fallback to filename |
| Remote timeout | Incomplete scan | Retry logic, partial result persistence |
| Memory pressure | Crash on large dirs | Streaming/chunked file enumeration |

## Suggested Plan Structure

1. **Scan Engine Foundation** - Progress tracking, unified scan entry point, job queue
2. **Library Management** - CRUD, type/source associations, UI integration
3. **Filename Parsing** - Movie/TV/Anime pattern matching, metadata extraction
4. **Incremental Updates** - Change detection, delta scanning, performance optimization
