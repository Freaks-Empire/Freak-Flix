---
phase: 1
plan: 3
wave: 2
---

# Plan 1.3: Extract Scanning Services (Local + OneDrive + Remote)

## Objective
Extract all scanning logic from LibraryProvider into three dedicated services: LocalScanService, OneDriveScanService, and RemoteScanService. These depend on ScanOrchestrationService from Plan 1.1.

## Context
- .gsd/SPEC.md
- .gsd/DECISIONS.md
- .gsd/phases/1/1-PLAN.md (ScanOrchestrationService must exist)
- lib/providers/library_provider.dart (lines 862-999, 1139-1385, 1386-1463, 1613-1924, 2213-2343)
- lib/services/scan_orchestration_service.dart (created in Plan 1.1)

## Tasks

<task type="auto">
  <name>Create LocalScanService</name>
  <files>lib/services/local_scan_service.dart [NEW]</files>
  <action>
    Extract local scanning logic into a service that returns scanned items:

    **Methods to move:**
    - _scanLocalFolder (L1613-1659) → scanFolder(path, keywords?, libraryType?) → List<MediaItem>
    - _isVideo (L1386-1390) → isVideo(path) (static or instance)
    - _parseFile (L1392-1463) → parseFile(PlatformFile) → MediaItem
    - pickAndScan (L862-902) — move file-picking + folder-creation logic; the method returns scanned items instead of directly mutating _allItems

    **Also move these top-level functions into the service:**
    - _ScanRequest class (L2215-2221)
    - _scanRecursive (L2224-2313)
    - _scanDirectoryInIsolate (L2315-2343)

    **Design:**
    - Constructor takes ScanOrchestrationService for progress reporting
    - Methods return List<MediaItem> — provider merges results into _allItems
    - Isolate scanning logic moves entirely into this service
    - pickAndScan delegates folder creation back to provider via a callback or returns a tuple of (folder, items)

    **Do NOT:**
    - Call _ingestItems — that stays in provider  
    - Call saveLibrary() or notifyListeners()
    - Include metadata enrichment logic
  </action>
  <verify>flutter analyze lib/services/local_scan_service.dart</verify>
  <done>File exists, compiles, contains all local/isolate scanning as pure service methods</done>
</task>

<task type="auto">
  <name>Create OneDriveScanService</name>
  <files>lib/services/onedrive_scan_service.dart [NEW]</files>
  <action>
    Extract OneDrive scanning logic:

    **Methods to move:**
    - rescanOneDriveFolder (L1139-1200) → scan(auth, folder) → List<MediaItem>
    - _walkOneDriveFolder (exists between L1200-1380) → walkFolder(token, url, basePath, accountId) → List<MediaItem>
    - _createMediaItemFromOneDrive (within walkOneDriveFolder logic)

    **Design:**
    - Constructor takes ScanOrchestrationService for progress reporting
    - Methods return List<MediaItem>
    - Uses GraphAuthService for auth (already a singleton)
    - The http calls stay unchanged

    **Do NOT:**
    - Call _ingestItems — provider does that
    - Modify Graph API URL construction logic — keep it identical
  </action>
  <verify>flutter analyze lib/services/onedrive_scan_service.dart</verify>
  <done>File exists, compiles, contains all OneDrive walk/scan logic</done>
</task>

<task type="auto">
  <name>Create RemoteScanService</name>
  <files>lib/services/remote_scan_service.dart [NEW]</files>
  <action>
    Extract remote storage scanning logic:

    **Methods to move:**
    - _scanRemoteFolder (L1662-1775) → scan(folder) → List<MediaItem>
    - _scanSftpDirectory (L1778-1805) → scanSftp(client, path, folder) → List<MediaItem>
    - _scanFtpDirectory (L1808-1833) → scanFtp(client, path, folder)
    - _scanWebDavDirectory (L1836-1861) → scanWebDav(client, path, folder)
    - _createRemoteMediaItem (L1864-1914) → createItem(file, folder) → MediaItem
    - _isMediaFile (L1917-1924) → isMediaFile(filename) (static)

    **Design:**
    - Constructor takes ScanOrchestrationService for progress reporting
    - Protocol dispatch (sftp/ftp/webdav) stays in service
    - Account/password resolution via RemoteStorageService singleton
    - Returns List<MediaItem>

    **Do NOT:**
    - Handle library type classification (adult/anime) — provider does that after receiving items
    - Call _ingestItems or saveLibrary
  </action>
  <verify>flutter analyze lib/services/remote_scan_service.dart</verify>
  <done>File exists, compiles, contains all SFTP/FTP/WebDAV scanning with protocol dispatch</done>
</task>

## Success Criteria
- [ ] Three scan services exist as standalone, testable classes
- [ ] Each accepts ScanOrchestrationService for progress
- [ ] Each returns List<MediaItem> without mutating provider state
- [ ] `flutter analyze` passes on all new files
