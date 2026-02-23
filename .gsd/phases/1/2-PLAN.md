---
phase: 1
plan: 2
wave: 1
---

# Plan 1.2: Extract LibraryFilterService & LibraryImportExportService

## Objective
Extract filtering/statistics logic and import/export/migration logic from LibraryProvider into two dedicated services. These are independent of scanning and can be extracted in parallel with Plan 1.1.

## Context
- .gsd/SPEC.md
- .gsd/DECISIONS.md
- lib/providers/library_provider.dart (lines 38-165, 1465-1568, 1926-2105, 2108-2211)

## Tasks

<task type="auto">
  <name>Create LibraryFilterService</name>
  <files>lib/services/library_filter_service.dart [NEW]</files>
  <action>
    Extract the following from LibraryProvider into a stateless service:

    **Methods/getters to move (accept items + settings as params, return results):**
    - continueWatchingItems (L53-72) → filterContinueWatching(List<MediaItem> items)
    - historyItems (L74-80) → filterHistory(List<MediaItem> items)
    - totalWatchTimeSeconds (L85-95) → calculateWatchTime(List<MediaItem> items)
    - watchedMoviesCount (L98-99) → countWatchedMovies(List<MediaItem> items)
    - watchedEpisodesCount (L101-103) → countWatchedEpisodes(List<MediaItem> items)
    - genreBreakdown (L106-114) → calculateGenreBreakdown(List<MediaItem> items)
    - topGenres (L117-121)
    - recentActivity (L124-127)
    - watchActivityByDay (L130-160) → calculateWatchActivity(Map<String, UserMediaData> userData)
    - movies, tv, anime, adult getters (L1471-1493) → filterByType(...)
    - continueWatching (L1494-1498) → filterContinueWatching(...)
    - recentlyAdded (L1500-1506) → filterRecentlyAdded(...)
    - topRated (L1508-1514) → filterTopRated(...)
    - getRecommendedLocal (L1520-1568) → getRecommended(...)
    - findByTmdbId (L1570-1572)
    - groupedTvShows, groupedAnimeShows (L1486-1492) 

    **Also move these top-level helpers into the service as static methods:**
    - _inferTypeFromPath (L2108-2121)
    - _seriesKey (L2123-2127)
    - _groupShows (L2129-2163)
    - _groupShowsToGroups (L2166-2211)

    **Design:**
    - Stateless — all methods take items/settings as parameters and return results
    - No ChangeNotifier — pure computation
    - User data (watchActivityByDay) needs Map<String, UserMediaData> parameter

    **Do NOT:**
    - Include _rebuildFilteredItems (that stays in provider as it manages _filteredItems state)
    - Include any mutation logic (add/remove items)
  </action>
  <verify>flutter analyze lib/services/library_filter_service.dart</verify>
  <done>File exists, passes analysis, contains all filter/stats/grouping methods as pure functions</done>
</task>

<task type="auto">
  <name>Create LibraryImportExportService</name>
  <files>lib/services/library_import_export_service.dart [NEW]</files>
  <action>
    Extract the following from LibraryProvider into a stateless service:

    **Methods to move:**
    - exportState (L1926-1931) → export(folders, items)
    - importState (L1973-2050) → import(data, currentFolders, currentItems) → returns merged state
    - cleanLibrary (L2052-2105) → cleanOrphanItems(items) → returns items to remove
    - extractLegacyHistory (L1933-1947) → extractHistory(items) → returns Map
    - getFolderStats (L1949-1971) → computeStats(items, folder)
    - _migrateFoldersFromPrefs (L514-526) → migrateFolders() → returns List<LibraryFolder>?
    - _migrateItemsFromPrefs (L528-545) → migrateItems() → returns List<MediaItem>?

    **Design:**
    - Stateless — methods take data in, return results out
    - Provider calls service methods and applies results to _allItems
    - Import method returns a merged result; provider applies it
    - cleanLibrary returns items to remove; provider removes them

    **Do NOT:**
    - Call notifyListeners() — that's the provider's job
    - Call saveLibrary() — provider does that after applying results
  </action>
  <verify>flutter analyze lib/services/library_import_export_service.dart</verify>
  <done>File exists, passes analysis, contains all import/export/migration/clean methods as pure functions</done>
</task>

<task type="auto">
  <name>Wire both services into LibraryProvider</name>
  <files>lib/providers/library_provider.dart</files>
  <action>
    1. Import both new services
    2. Create instances of both services in constructor
    3. Replace all filter/stats getters with delegation to LibraryFilterService:
       - `List<MediaItem> get movies => _filterService.filterMovies(_filteredItems, settings.enableAdultContent);`
       - etc. for tv, anime, adult, continueWatching, recentlyAdded, topRated, getRecommendedLocal
    4. Replace all import/export/clean methods with delegation to LibraryImportExportService:
       - exportState() delegates to _importExportService.export(...)
       - importState(data) calls service, applies returned result
       - cleanLibrary() calls service, removes returned items
    5. Remove all moved methods and top-level helpers from library_provider.dart
    6. Getters that UI uses (movies, tv, etc.) keep their existing names — just delegate internally

    **Do NOT:**
    - Change any method signatures exposed to UI
    - Alter _rebuildFilteredItems — it stays in provider
  </action>
  <verify>flutter analyze lib/providers/library_provider.dart</verify>
  <done>LibraryProvider compiles, all filter/import/export logic delegated, top-level helper functions removed</done>
</task>

## Success Criteria
- [ ] `LibraryFilterService` exists with all filter/stats logic as pure functions
- [ ] `LibraryImportExportService` exists with all import/export/migration logic
- [ ] LibraryProvider delegates to both services
- [ ] `flutter analyze` passes on all modified files
- [ ] App builds successfully: `flutter build web --release`
