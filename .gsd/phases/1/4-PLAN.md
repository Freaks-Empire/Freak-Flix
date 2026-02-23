---
phase: 1
plan: 4
wave: 3
---

# Plan 1.4: Finalize Lean LibraryProvider

## Objective
Wire all extracted services into LibraryProvider, remove all moved code, and verify the provider is under 300 lines. This is the final integration step for Phase 1.

## Context
- .gsd/SPEC.md
- .gsd/DECISIONS.md
- All Plan 1.1-1.3 services (must exist and compile)
- lib/providers/library_provider.dart
- lib/main.dart

## Tasks

<task type="auto">
  <name>Wire scanning services and clean up LibraryProvider</name>
  <files>lib/providers/library_provider.dart, lib/main.dart</files>
  <action>
    1. Import all 5 extracted services
    2. Add service instances as fields, initialized in constructor
    3. Replace all scanning entry points with service delegation:
       - rescanFolder(folder, auth, metadata) → dispatches to LocalScanService, OneDriveScanService, or RemoteScanService based on folder type
       - rescanAll(auth, metadata) → iterates folders, calls appropriate service
       - pickAndScan(metadata, forcedType) → calls LocalScanService.pickAndScan()
       - rescanItem(item, metadata) → calls LocalScanService
    4. Keep in provider (coordinator logic):
       - _ingestItems (merges scan results into _allItems)
       - _rebuildFilteredItems
       - loadLibrary / saveLibrary / _saveLibraryFolders
       - _reclassifyItems
       - folder CRUD (addLibraryFolder, removeLibraryFolder, updateLibraryFolder, etc.)
       - updateItem, clear, updateProfile
       - refetchAllMetadata, refetchMetadataForFolder, _refetchMetadataForItems (metadata orchestration)
       - _queuePersistentMetadata, enforceSidecarsAndNaming
    5. Remove ALL moved code:
       - Scan progress fields/methods (now in ScanOrchestrationService)
       - Filter/stats getters (now in LibraryFilterService)
       - Import/export methods (now in LibraryImportExportService)
       - Local scan methods and isolate functions (now in LocalScanService)
       - OneDrive scan methods (now in OneDriveScanService)
       - Remote scan methods (now in RemoteScanService)
       - Top-level helpers (_inferTypeFromPath, _seriesKey, _groupShows, _groupShowsToGroups, _ScanRequest, _scanRecursive, _scanDirectoryInIsolate)
    6. Update lib/main.dart if LibraryProvider constructor signature changed

    **Do NOT:**
    - Change any method signatures that screens/widgets call directly
    - Remove metadata orchestration methods (those stay per DECISIONS.md)
  </action>
  <verify>flutter analyze lib/providers/library_provider.dart && flutter analyze lib/main.dart</verify>
  <done>LibraryProvider compiles, all extracted code removed, provider file is under 300 lines</done>
</task>

<task type="checkpoint:human-verify">
  <name>Verify full app build and run</name>
  <files>N/A</files>
  <action>
    1. Run `flutter build web --release` to verify web build
    2. Run `flutter run -d windows` (or user's preferred platform) to verify app launches
    3. Verify:
       - Library loads existing items
       - Folder management works (add/remove)
       - Scan progress UI appears when scanning
       - Filter tabs work (Movies, TV, Anime)
       - Import/export functions work
    4. Count lines: LibraryProvider should be ≤300 lines
  </action>
  <verify>flutter build web --release && (Get-Content lib/providers/library_provider.dart | Measure-Object -Line).Lines</verify>
  <done>App builds + runs on at least one platform, LibraryProvider ≤300 lines, zero behavior change</done>
</task>

## Success Criteria
- [ ] LibraryProvider is ≤300 lines
- [ ] All 5 services are wired and delegated
- [ ] No extracted code remains in library_provider.dart
- [ ] `flutter analyze` passes with no new warnings
- [ ] `flutter build web --release` succeeds
- [ ] App runs and all features work identically
