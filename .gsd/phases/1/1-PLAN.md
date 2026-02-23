---
phase: 1
plan: 1
wave: 1
---

# Plan 1.1: Extract ScanOrchestrationService

## Objective
Extract all scan progress tracking, notification, foreground task, and wakelock logic from `LibraryProvider` into a dedicated `ScanOrchestrationService`. This is the foundation that all scan services will depend on.

## Context
- .gsd/SPEC.md
- .gsd/ARCHITECTURE.md
- .gsd/DECISIONS.md
- lib/providers/library_provider.dart (lines 238-465 — scan state, notifications, foreground tasks)

## Tasks

<task type="auto">
  <name>Create ScanOrchestrationService</name>
  <files>lib/services/scan_orchestration_service.dart [NEW]</files>
  <action>
    Extract the following from LibraryProvider into a new stateless service class:

    **State fields to move:**
    - isScanning, scannedCount, totalToScan, currentScanSource, currentScanItem
    - _cancelScanRequested, scanningStatus
    - _notifications (FlutterLocalNotificationsPlugin)

    **Methods to move:**
    - beginScan() (L246-270)
    - reportScanProgress() (L272-288)
    - finishScan() (L290-314)
    - requestCancelScan() (L359-364)
    - _updateScanningStatus() (L366-391)
    - _setScanStatus() (L393-396)
    - _requestNotificationPermission() (L316-331)
    - _showCompletionNotification() (L333-355)
    - _initNotifications() (L420-442)
    - _initForegroundTask() (L444-465)
    - cancelRequested getter (L357)

    **Design:**
    - Class extends ChangeNotifier so UI can listen to scan progress independently
    - Constructor takes no parameters — it's self-contained
    - All platform-conditional logic (isAndroid, isIOS, isWeb) stays in the service
    - Expose status getter and a Stream<ScanProgress> for consumers

    **Do NOT:**
    - Include any item mutation logic (that stays in provider)
    - Include any folder scanning logic
    - Import MetadataService or SettingsProvider
  </action>
  <verify>flutter analyze lib/services/scan_orchestration_service.dart</verify>
  <done>File exists at lib/services/scan_orchestration_service.dart, passes static analysis, contains all scan progress methods</done>
</task>

<task type="auto">
  <name>Wire ScanOrchestrationService into LibraryProvider</name>
  <files>lib/providers/library_provider.dart, lib/main.dart</files>
  <action>
    1. Add `ScanOrchestrationService` as a field on LibraryProvider (injected via constructor or created internally)
    2. Replace all inline scan progress calls in LibraryProvider with delegation to the service:
       - beginScan() → _scanService.beginScan()
       - reportScanProgress() → _scanService.reportScanProgress()
       - finishScan() → _scanService.finishScan()
       - etc.
    3. Expose scan state via getters that delegate to the service:
       - `bool get isScanning => _scanService.isScanning;`
       - `String get scanningStatus => _scanService.scanningStatus;`
       - etc.
    4. Forward notifyListeners from service changes: listen to _scanService and call notifyListeners() when it fires
    5. Remove all moved fields and methods from LibraryProvider
    6. Update lib/main.dart if constructor changes

    **Do NOT:**
    - Change any scanner method signatures (rescanAll, _scanLocalFolder etc.) — those are extracted in later plans
    - Alter test files
  </action>
  <verify>flutter analyze lib/providers/library_provider.dart && flutter analyze lib/main.dart</verify>
  <done>LibraryProvider compiles with ScanOrchestrationService dependency, all scan progress state delegated, no duplicated notification logic</done>
</task>

## Success Criteria
- [ ] `ScanOrchestrationService` exists as a standalone, testable class
- [ ] LibraryProvider delegates all scan progress to the service
- [ ] `flutter analyze` passes on both files
- [ ] App builds successfully: `flutter build web --release`
