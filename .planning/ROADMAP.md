# Roadmap: Freak-Flix

## Overview

This roadmap sequences v1 delivery from safe, cross-platform foundations to end-user value: users connect sources, ingest media into a resilient index, enrich with metadata, browse quickly, play reliably, and keep playback state synchronized across devices.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [x] **Phase 1: Security and Privacy Guardrails** - Lock down unsafe input, storage, and adult-default privacy behavior.
- [ ] **Phase 2: Cross-Platform Baseline and Releases** - Ensure core journeys and release outputs work across Windows, Android, and Web.
- [ ] **Phase 3: Onboarding and Source Setup** - Let users complete first run and connect local/remote libraries.
- [ ] **Phase 4: Library Ingestion and Indexing** - Build scalable scan/index workflows for mixed storage libraries.
- [ ] **Phase 5: Metadata and Offline Catalog** - Enrich library items with provider metadata and offline-ready cache.
- [ ] **Phase 6: Discovery and Adult-Aware Browsing** - Deliver browse/search/filter UX with adult visibility controls.
- [ ] **Phase 7: Playback and Progress Continuity** - Provide reliable playback with resume and watched-state visibility.
- [ ] **Phase 8: Cross-Device Sync and Backup Controls** - Sync playback state deterministically with configurable backup settings.

## Phase Details

### Phase 1: Security and Privacy Guardrails
**Goal**: Users can trust that library connectors and settings remain safe by default, with adult content hidden unless explicitly enabled.
**Depends on**: Nothing (first phase)
**Requirements**: SEC-01, SEC-02, SEC-03, SEC-04, SEC-05
**Success Criteria** (what must be TRUE):
  1. User input in source/settings flows cannot be used to execute shell commands.
  2. User cannot access files outside allowed roots via traversal patterns.
  3. Remote connector targets block unsafe/internal SSRF-style destinations.
  4. User credentials/tokens are stored securely and never exposed in repository artifacts.
  5. Adult library is hidden by default and appears only after explicit user opt-in.
**Plans**: 4 plans
Plans:
- [x] 01-01-PLAN.md - Unify typed input validation and enforce command-injection/SSRF guardrails in connector UX.
- [x] 01-02-PLAN.md - Add canonical path containment checks for local file operations and traversal regressions.
- [x] 01-03-PLAN.md - Move secrets to secure storage and remove plaintext credential persistence from settings artifacts.
- [x] 01-04-PLAN.md - Enforce adult-content default-off behavior with explicit opt-in and route/navigation gating tests.

### Phase 2: Cross-Platform Baseline and Releases
**Goal**: Users can complete the core product journey on all target platforms with shippable release outputs.
**Depends on**: Phase 1
**Requirements**: PLAT-01, PLAT-02
**Success Criteria** (what must be TRUE):
  1. User can complete onboarding, browse, details, playback, and settings flows on Windows, Android, and Web.
  2. Windows, Android, and Web release builds complete successfully from the v1 codebase.
**Plans**: TBD

### Phase 3: Onboarding and Source Setup
**Goal**: New users can finish setup and connect at least one content source across local and remote options.
**Depends on**: Phase 2
**Requirements**: ONB-01, ONB-02, ONB-03, ONB-04
**Success Criteria** (what must be TRUE):
  1. User can complete first-run setup and choose enabled library types, with adult as opt-in.
  2. User can add at least one local folder source during onboarding.
  3. User can connect OneDrive via Device Code Flow on supported platforms.
  4. User can create and save SFTP, FTP, or WebDAV source profiles from onboarding or settings.
**Plans**: TBD

### Phase 4: Library Ingestion and Indexing
**Goal**: Users can ingest and maintain large mixed-source libraries with responsive incremental scans.
**Depends on**: Phase 3
**Requirements**: ONB-05, LIB-01, LIB-02, LIB-03, LIB-04, LIB-05, PLAT-03
**Success Criteria** (what must be TRUE):
  1. User can start an initial scan and monitor progress through completion.
  2. User can manage multiple libraries with correct type/source associations.
  3. Scanner correctly recognizes common movie and TV/anime naming patterns.
  4. Indexed items preserve unified local/remote source references for later access.
  5. Re-scan updates changed content incrementally while remaining responsive on large libraries.
**Plans**: TBD

### Phase 5: Metadata and Offline Catalog
**Goal**: Users get rich, source-appropriate metadata and artwork that remains available offline after initial fetch.
**Depends on**: Phase 4
**Requirements**: META-01, META-02, META-03, META-04, META-05, META-06, META-07
**Success Criteria** (what must be TRUE):
  1. User can view movie/TV metadata from TMDB and anime metadata from AniList in matching libraries.
  2. User with adult mode enabled can view optional adult metadata from StashDB.
  3. User can open cast/performer profiles and related filmography where provider data exists.
  4. User can browse previously fetched metadata/artwork while offline.
  5. Metadata fetching gracefully handles provider failures/rate limits with retry and fallback behavior.
**Plans**: TBD

### Phase 6: Discovery and Adult-Aware Browsing
**Goal**: Users can quickly discover relevant items via home rails, search, and filters while honoring adult-mode visibility.
**Depends on**: Phase 5
**Requirements**: DISC-01, DISC-02, DISC-03, DISC-04
**Success Criteria** (what must be TRUE):
  1. User sees home sections including Continue Watching and Recently Added.
  2. User can search across indexed library items and open matching results.
  3. User can filter and sort by available attributes such as genre, year, rating, and language.
  4. Adult rails/results are only visible when adult mode is enabled.
**Plans**: TBD

### Phase 7: Playback and Progress Continuity
**Goal**: Users can play content reliably and resume where they left off with clear watch-progress signals.
**Depends on**: Phase 6
**Requirements**: PLAY-01, PLAY-02, PLAY-03, PLAY-04
**Success Criteria** (what must be TRUE):
  1. User can play indexed media files on supported platforms via the app player.
  2. User playback position is saved per media item (and per episode when applicable).
  3. User can resume playback from saved position on later sessions.
  4. User sees watched/progress indicators in browse and detail screens.
**Plans**: TBD

### Phase 8: Cross-Device Sync and Backup Controls
**Goal**: Users can keep playback state consistent across devices with deterministic sync behavior and controllable settings.
**Depends on**: Phase 7
**Requirements**: SYNC-01, SYNC-02, SYNC-03
**Success Criteria** (what must be TRUE):
  1. User can sync playback state and watched markers across devices using OneDrive-backed app data.
  2. When sync conflicts occur, user-observed final state follows deterministic last-write-wins timestamp behavior.
  3. User can enable, disable, and configure backup/sync settings in app settings.
**Plans**: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 1 -> 2 -> 3 -> 4 -> 5 -> 6 -> 7 -> 8

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Security and Privacy Guardrails | 4/4 | Complete | 2026-02-27 |
| 2. Cross-Platform Baseline and Releases | 0/TBD | Not started | - |
| 3. Onboarding and Source Setup | 0/TBD | Not started | - |
| 4. Library Ingestion and Indexing | 0/TBD | Not started | - |
| 5. Metadata and Offline Catalog | 0/TBD | Not started | - |
| 6. Discovery and Adult-Aware Browsing | 0/TBD | Not started | - |
| 7. Playback and Progress Continuity | 0/TBD | Not started | - |
| 8. Cross-Device Sync and Backup Controls | 0/TBD | Not started | - |
