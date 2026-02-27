# Requirements: Freak-Flix

**Defined:** 2026-02-27
**Core Value:** Users can connect their own local or cloud storage and immediately get a polished, metadata-rich, serverless streaming-library experience with reliable cross-platform playback.

## v1 Requirements

Requirements for initial release scope. Each requirement must map to exactly one roadmap phase.

### Onboarding

- [ ] **ONB-01**: User can complete first-run setup and select enabled library types (Movies, TV, Anime, Adult opt-in).
- [ ] **ONB-02**: User can add at least one local folder source from onboarding.
- [ ] **ONB-03**: User can connect OneDrive using Device Code Flow on supported platforms.
- [ ] **ONB-04**: User can add a remote source profile for SFTP, FTP, or WebDAV from onboarding/settings.
- [ ] **ONB-05**: User can start an initial scan and see progress status until completion.

### Library Ingestion

- [ ] **LIB-01**: User can manage multiple libraries with type and source association.
- [ ] **LIB-02**: Scanner can parse movie filenames in `Title (Year)` style and common variants.
- [ ] **LIB-03**: Scanner can parse TV/Anime season-episode naming including `SxxExx` patterns.
- [ ] **LIB-04**: Scanner can persist source references for local and remote files in a unified index.
- [ ] **LIB-05**: Scanner supports incremental re-scan without rebuilding the full index every time.

### Metadata and Catalog

- [ ] **META-01**: User can fetch and display movie metadata from TMDB.
- [ ] **META-02**: User can fetch and display TV show and episode metadata from TMDB.
- [ ] **META-03**: User can fetch and display anime metadata from AniList for anime libraries.
- [ ] **META-04**: User can fetch and display optional adult metadata from StashDB when adult library is enabled.
- [ ] **META-05**: User can view cast/performer profiles with filmography from available metadata sources.
- [ ] **META-06**: Metadata and artwork are cached locally for offline browsing after initial fetch.
- [ ] **META-07**: Metadata fetch pipeline handles API failures with retries, rate-limit awareness, and graceful fallback.

### Browsing and Discovery

- [ ] **DISC-01**: User can browse home sections including Continue Watching and Recently Added.
- [ ] **DISC-02**: User can search across indexed library items.
- [ ] **DISC-03**: User can filter/sort by core attributes (genre, year, rating, language) where data exists.
- [ ] **DISC-04**: User sees separate adult rails and results only when adult mode is enabled.

### Playback

- [ ] **PLAY-01**: User can play media files cross-platform using the app player baseline.
- [ ] **PLAY-02**: User playback position is persisted per item (and per episode where applicable).
- [ ] **PLAY-03**: User can resume playback from saved position on next play.
- [ ] **PLAY-04**: User can see watched/progress indicators in browse and detail views.

### Sync and Backup

- [ ] **SYNC-01**: User playback state and watched markers can sync across devices via OneDrive-backed app data.
- [ ] **SYNC-02**: Sync conflict resolution follows deterministic last-write-wins behavior with timestamps.
- [ ] **SYNC-03**: Backup/sync settings can be enabled, disabled, and configured in app settings.

### Security and Privacy

- [ ] **SEC-01**: User-provided inputs cannot trigger command execution or shell injection paths.
- [ ] **SEC-02**: Local file operations reject directory traversal attempts.
- [ ] **SEC-03**: Remote URL and connector handling prevents SSRF-style unsafe target access.
- [ ] **SEC-04**: Secrets and credentials are stored with platform-appropriate secure handling and never committed.
- [ ] **SEC-05**: Adult library remains hidden by default and requires explicit opt-in toggle.

### Platform and Performance

- [ ] **PLAT-01**: Core flows (onboarding, browse, details, play, settings) work on Windows, Android, and Web builds.
- [ ] **PLAT-02**: Release builds complete successfully for Windows, Android, and Web targets.
- [ ] **PLAT-03**: Library operations remain responsive for large collections via incremental scanning/indexing strategy.

## v2 Requirements

Deferred capabilities acknowledged but not committed for this roadmap.

### Discovery Enhancements

- **DISC-05**: User can create and manage collections or playlists.
- **DISC-06**: User receives smarter recommendations using metadata-derived relevance.

### Playback Enhancements

- **PLAY-05**: User can reliably control subtitle, audio track, and playback speed with polished UX on all platforms.

### Account and Access

- **SEC-06**: User can protect adult section with PIN or biometric gate.

### Ecosystem Features

- **SYNC-04**: Optional Firebase-backed analytics/crash reporting/feature flags can be configured without breaking local-first mode.

## Out of Scope

Explicit exclusions to prevent scope creep.

| Feature | Reason |
|---------|--------|
| Pirated content aggregation, torrenting, or streaming-site scraping | Violates legal/safety boundaries and product intent |
| Mandatory always-on hosted media server architecture | Conflicts with serverless-first core value |
| Heavy transcoding pipeline as baseline | High complexity/cost and not required for v1 usability |
| DRM playback for commercial streaming platforms | Outside target product capability and legal scope |
| Social/watch-party platform features in v1 | Not core to current personal-library focus |

## Traceability

Which phases cover which requirements. Populated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| ONB-01 | TBD | Pending |
| ONB-02 | TBD | Pending |
| ONB-03 | TBD | Pending |
| ONB-04 | TBD | Pending |
| ONB-05 | TBD | Pending |
| LIB-01 | TBD | Pending |
| LIB-02 | TBD | Pending |
| LIB-03 | TBD | Pending |
| LIB-04 | TBD | Pending |
| LIB-05 | TBD | Pending |
| META-01 | TBD | Pending |
| META-02 | TBD | Pending |
| META-03 | TBD | Pending |
| META-04 | TBD | Pending |
| META-05 | TBD | Pending |
| META-06 | TBD | Pending |
| META-07 | TBD | Pending |
| DISC-01 | TBD | Pending |
| DISC-02 | TBD | Pending |
| DISC-03 | TBD | Pending |
| DISC-04 | TBD | Pending |
| PLAY-01 | TBD | Pending |
| PLAY-02 | TBD | Pending |
| PLAY-03 | TBD | Pending |
| PLAY-04 | TBD | Pending |
| SYNC-01 | TBD | Pending |
| SYNC-02 | TBD | Pending |
| SYNC-03 | TBD | Pending |
| SEC-01 | TBD | Pending |
| SEC-02 | TBD | Pending |
| SEC-03 | TBD | Pending |
| SEC-04 | TBD | Pending |
| SEC-05 | TBD | Pending |
| PLAT-01 | TBD | Pending |
| PLAT-02 | TBD | Pending |
| PLAT-03 | TBD | Pending |

**Coverage:**
- v1 requirements: 36 total
- Mapped to phases: 0
- Unmapped: 36 ⚠

---
*Requirements defined: 2026-02-27*
*Last updated: 2026-02-27 after initial definition*
