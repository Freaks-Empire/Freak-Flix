import 'dart:convert';
import 'dart:io';
import '../utils/platform/platform.dart';
import 'dart:async';
import 'package:file_picker/file_picker.dart' hide PlatformFile;
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/library_folder.dart';
import '../models/user_profile.dart';
import '../models/media_item.dart';
import '../models/discover_type.dart';
import '../models/cast_member.dart';
import '../services/graph_auth_service.dart' as graph_auth;
import '../services/persistence_service.dart';
import '../services/tmdb_discover_service.dart';
import '../services/metadata_service.dart';
import '../services/sidecar_service.dart';
import '../services/task_queue_service.dart';
import '../services/scan_orchestration_service.dart';
import '../services/library_filter_service.dart';
import '../services/library_import_export_service.dart';
import '../services/local_scan_service.dart';
import '../services/onedrive_scan_service.dart';
import '../services/remote_scan_service.dart';

import 'settings_provider.dart';
import '../utils/filename_parser.dart';
import 'package:collection/collection.dart';
import 'package:archive/archive.dart';
import '../utils/logger.dart';

class LibraryProvider extends ChangeNotifier {
  static const _prefsKey = 'library_v1';
  static const _libraryFoldersKey = 'library_folders_v1';

  final SettingsProvider settings;
  final ScanOrchestrationService _scanService;

  // backing store
  List<MediaItem> _allItems = [];

  // exposed to UI (filtered + user data applied)
  List<MediaItem> _filteredItems = [];

  List<MediaItem> get items => _filteredItems;
  List<MediaItem> get allItems => List.unmodifiable(_allItems);

  List<MediaItem> get continueWatchingItems =>
      LibraryFilterService.filterContinueWatchingDetailed(_filteredItems);

  List<MediaItem> get historyItems =>
      LibraryFilterService.filterHistory(_filteredItems);

  // --- Profile Statistics ---

  int get totalWatchTimeSeconds =>
      LibraryFilterService.calculateTotalWatchTime(_filteredItems);

  int get watchedMoviesCount =>
      LibraryFilterService.countWatchedMovies(_filteredItems);

  int get watchedEpisodesCount =>
      LibraryFilterService.countWatchedEpisodes(_filteredItems);

  Map<String, int> get genreBreakdown =>
      LibraryFilterService.calculateGenreBreakdown(_filteredItems);

  List<MapEntry<String, int>> topGenres([int limit = 5]) =>
      LibraryFilterService.topGenres(_filteredItems, limit);

  List<MediaItem> get recentActivity =>
      LibraryFilterService.recentActivity(_filteredItems);

  Map<String, int> get watchActivityByDay =>
      LibraryFilterService.calculateWatchActivityByDay(_currentUserData);

  int get totalLibraryCount => _allItems.length;

  List<LibraryFolder> libraryFolders = [];
  bool isLoading = false;
  String? error;

  // Delegate scan state to ScanOrchestrationService
  bool get isScanning => _scanService.isScanning;
  String get scanningStatus => _scanService.scanningStatus;
  bool get cancelRequested => _scanService.cancelRequested;

  final _configChangedController = StreamController<void>.broadcast();
  Stream<void> get onConfigChanged => _configChangedController.stream;

  // Profile State
  UserProfile? _currentProfile;
  Map<String, UserMediaData> _currentUserData = {};

  void updateProfile(
      UserProfile? profile, Map<String, UserMediaData> userData) {
    _currentProfile = profile;
    _currentUserData = userData;
    _rebuildFilteredItems();
  }

  void _rebuildFilteredItems() {
    // 1. Filter by Access Control
    Iterable<MediaItem> visible = _allItems;

    if (_currentProfile?.allowedFolderIds != null) {
      final allowed = _currentProfile!.allowedFolderIds!.toSet();
      // Need to map items to their folder IDs.
      // Current MediaItem doesn't strictly store folder ID, but it stores 'onedrive_ACCOUNTID_FOLDERID' logic or paths.
      // We need to check if the item's folder path matches any allowed folder path.

      // Optimization: Build a list of allowed paths prefixes
      final allowedPaths = libraryFolders
          .where((f) => allowed.contains(f.id))
          .map((f) => f.path.toLowerCase())
          .toList();

      if (allowedPaths.isEmpty && allowed.isNotEmpty) {
        // Profile has restrictions but we found no matching folder objects? Block all.
        visible = [];
      } else {
        visible = visible.where((item) {
          final itemPath = item.folderPath.toLowerCase();
          for (final p in allowedPaths) {
            if (itemPath.startsWith(p)) return true;
          }
          return false;
        });
      }
    }

    // 1b. Hide adult content if disabled in settings
    if (!settings.enableAdultContent) {
      visible = visible.where((item) => !item.isAdult);
    }

    // 2. Apply User Data (Watch History)
    _filteredItems = visible.map((item) {
      final data = _currentUserData[item.id];
      if (data != null) {
        return item.copyWith(
          lastPositionSeconds: data.positionSeconds,
          isWatched: data.isWatched,
        );
      }
      return item; // Item default is unwatched / 0 pos
    }).toList();

    notifyListeners();
  }

  void _onSettingsChanged() {
    _rebuildFilteredItems();
  }

  // ── Scan delegation ────────────────────────────────────────────────

  void beginScan({String? sourceLabel, int? total}) {
    isLoading = true;
    _scanService.beginScan(sourceLabel: sourceLabel, total: total);
    notifyListeners();
  }

  void reportScanProgress({
    int? scanned,
    int? total,
    String? currentItem,
    String? sourceLabel,
  }) {
    _scanService.reportScanProgress(
      scanned: scanned,
      total: total,
      currentItem: currentItem,
      sourceLabel: sourceLabel,
    );
  }

  void finishScan() {
    isLoading = false;
    _scanService.finishScan();
    notifyListeners();
  }

  void requestCancelScan() {
    _scanService.requestCancelScan();
  }

  void _setScanStatus(String message) {
    _scanService.setScanStatus(message);
  }

  @override
  void dispose() {
    settings.removeListener(_onSettingsChanged);
    _scanService.removeListener(_onScanServiceChanged);
    _configChangedController.close();
    super.dispose();
  }

  void _onScanServiceChanged() {
    notifyListeners();
  }

  LibraryProvider(this.settings, {ScanOrchestrationService? scanService})
      : _scanService = scanService ?? ScanOrchestrationService() {
    settings.addListener(_onSettingsChanged);
    _scanService.addListener(_onScanServiceChanged);
  }

  static const _foldersFile = 'library_folders.json';
  static const _itemsFile = 'library_items.gz';

  Future<void> loadLibrary() async {
    AppLogger.d('Loading library from file storage...', tag: 'LibraryProvider');

    // 1. Load Folders
    try {
      final folderJson =
          await PersistenceService.instance.loadString(_foldersFile);
      if (folderJson != null) {
        libraryFolders = (jsonDecode(folderJson) as List<dynamic>)
            .map((e) => LibraryFolder.fromJson(e as Map<String, dynamic>))
            .toList();
        AppLogger.d('Loaded ${libraryFolders.length} folders from file', tag: 'LibraryProvider');
      } else {
        // Migration check
        await _migrateFoldersFromPrefs();
      }
    } catch (e) {
      AppLogger.e('Error loading folders: $e', error: e, tag: 'LibraryProvider');
      libraryFolders = [];
    }

    // 2. Load Items
    try {
      final itemsJson =
          await PersistenceService.instance.loadCompressed(_itemsFile);
      if (itemsJson != null) {
        AppLogger.d('Found compressed items file. Parsing...', tag: 'LibraryProvider');
        _allItems = MediaItem.listFromJson(itemsJson);
        AppLogger.d('Loaded ${_allItems.length} items from file', tag: 'LibraryProvider');
      } else {
        AppLogger.d('No items file found. Checking legacy...', tag: 'LibraryProvider');
        await _migrateItemsFromPrefs();
      }
    } catch (e) {
      AppLogger.e('Error loading items: $e', error: e, tag: 'LibraryProvider');
      // items = []; // Keep empty?
    }

    // Reclassify/Update
    await _reclassifyItems();

    notifyListeners();
  }

  Future<void> _migrateFoldersFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_libraryFoldersKey);
    if (raw == null) return;

    try {
      libraryFolders = (jsonDecode(raw) as List<dynamic>)
          .map((e) => LibraryFolder.fromJson(e as Map<String, dynamic>))
          .toList();
      await _saveLibraryFolders();
      AppLogger.d('Migrated folders from SharedPreferences', tag: 'LibraryProvider');
    } catch (_) {}
  }

  Future<void> _migrateItemsFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null) return;

    try {
      if (raw.trim().startsWith('[')) {
        _allItems = MediaItem.listFromJson(raw);
      } else {
        final bytes = base64Decode(raw);
        final decompressed = GZipDecoder().decodeBytes(bytes);
        final jsonStr = utf8.decode(decompressed);
        _allItems = MediaItem.listFromJson(jsonStr);
      }
      await saveLibrary();
      AppLogger.d('Migrated items from SharedPreferences', tag: 'LibraryProvider');
    } catch (_) {}
  }

  Future<void> _reclassifyItems() async {
    bool updated = false;
    for (var i = 0; i < _allItems.length; i++) {
      final item = _allItems[i];
      final parsed = FilenameParser.parse(item.fileName);

      // Find parent folder to determine strict type
      LibraryFolder? parentFolder;

      // Check Cloud Folders
      if (item.id.startsWith('onedrive_')) {
        parentFolder = libraryFolders.firstWhereOrNull((f) {
          if (f.accountId.isEmpty) return false;
          // Ensure path has leading slash for consistency
          final fPath = f.path.startsWith('/') ? f.path : '/${f.path}';
          // If f.path is empty/root, it becomes '/'.
          final prefix = 'onedrive:${f.accountId}${fPath == '/' ? '/' : fPath}';
          return item.folderPath.startsWith(prefix);
        });
      }
      // Check Local Folders
      else {
        parentFolder = libraryFolders.firstWhereOrNull((f) {
          if (f.accountId.isNotEmpty) return false;
          return item.filePath.toLowerCase().startsWith(f.path.toLowerCase());
        });
      }

      bool newIsAnime = item.isAnime;
      bool newIsAdult = item.isAdult;
      MediaType newType = item.type;

      if (parentFolder != null) {
        newIsAnime = parentFolder.type == LibraryType.anime;
        newIsAdult = parentFolder.type == LibraryType.adult;

        // Re-infer type based on folder strictness + filename hints
        if (parentFolder.type == LibraryType.movies) {
          newType = MediaType.movie;
        } else if (parentFolder.type == LibraryType.tv ||
            parentFolder.type == LibraryType.anime) {
          newType = MediaType.tv;
        } else if (parentFolder.type == LibraryType.adult) {
          newType = MediaType.scene;
        } else {
          // Other/Unknown: Keep inference but remove anime guessing if not strictly anime?
          // Actually we'll keep inference for 'Other'.
          newType = LibraryFilterService.inferTypeFromPath(item);
        }
      }

      final updatedItem = _allItems[i].copyWith(
        title: parsed.seriesTitle.isNotEmpty
            ? parsed.seriesTitle
            : _allItems[i].title,
        season: _allItems[i].season ??
            parsed.season ??
            (parsed.episode != null ? 1 : null),
        episode: _allItems[i].episode ?? parsed.episode,
        type: newType,
        isAnime: newIsAnime,
        isAdult: newIsAdult,
        year: _allItems[i].year ?? parsed.year,
      );
      if (updatedItem != _allItems[i]) {
        _allItems[i] = updatedItem;
        updated = true;
      }
    }
    if (updated) await saveLibrary();
  }

  Future<void> saveLibrary() async {
    // Save items compressed
    final jsonStr = MediaItem.listToJson(_allItems);
    await PersistenceService.instance.saveCompressed(_itemsFile, jsonStr);
    _rebuildFilteredItems(); // Ensure view is updated
  }

  Future<void> _saveLibraryFolders() async {
    final jsonStr = jsonEncode(libraryFolders.map((f) => f.toJson()).toList());
    await PersistenceService.instance.saveString(_foldersFile, jsonStr);
  }

  List<LibraryFolder> libraryFoldersForAccount(String accountId) {
    return libraryFolders.where((f) => f.accountId == accountId).toList();
  }

  Future<void> addLibraryFolder(LibraryFolder folder) async {
    libraryFolders.removeWhere(
      (f) => f.id == folder.id && f.accountId == folder.accountId,
    );
    libraryFolders.add(folder);
    await _saveLibraryFolders();
    _configChangedController.add(null);
    notifyListeners();
  }

  Future<void> updateLibraryFolder(LibraryFolder folder) async {
    final index = libraryFolders.indexWhere(
      (f) => f.id == folder.id && f.accountId == folder.accountId,
    );
    if (index != -1) {
      libraryFolders[index] = folder;
      await _saveLibraryFolders();
      _configChangedController.add(null);
      notifyListeners();
    }
  }

  Future<void> removeLibraryFolder(LibraryFolder folder) async {
    libraryFolders.removeWhere(
      (f) => f.id == folder.id && f.accountId == folder.accountId,
    );
    await _saveLibraryFolders();

    // Remove associated items
    final bool isCloud = folder.accountId.isNotEmpty;
    if (isCloud) {
      // Cloud items: ID format onedrive_{accountId}_{id}
      // We need to be careful not to remove items from OTHER folders of same account if they exist
      // But usually we filter by path.
      // Let's rely on path matching.
      final prefix =
          'onedrive:${folder.accountId}${folder.path.isEmpty ? '/' : folder.path}';
      _allItems.removeWhere((i) {
        if (!i.id.startsWith('onedrive_${folder.accountId}_')) return false;
        // Check if item belongs to this folder hierarchy
        // item.folderPath example: 'onedrive:ACCOUNTID/Movies/Action'
        // prefix: 'onedrive:ACCOUNTID/Movies'
        return i.folderPath.startsWith(prefix);
      });
    } else {
      // Local items
      _allItems.removeWhere((i) => i.filePath.startsWith(folder.path));
    }

    _configChangedController.add(null);
    notifyListeners();
    await saveLibrary();
  }

  Future<void> removeLibraryFoldersForAccount(String accountId) async {
    libraryFolders.removeWhere((f) => f.accountId == accountId);
    await _saveLibraryFolders();

    // Remove all items for this account
    _allItems.removeWhere((i) => i.id.startsWith('onedrive_${accountId}_'));

    _configChangedController.add(null);
    notifyListeners();
    await saveLibrary();
  }

  Future<void> updateItem(MediaItem item) async {
    final index = _allItems.indexWhere((i) => i.id == item.id);
    if (index != -1) {
      _allItems[index] = item;
      await saveLibrary();
      notifyListeners();
    }
  }

  Future<void> rescanFolder(LibraryFolder folder,
      {required graph_auth.GraphAuthService auth,
      MetadataService? metadata}) async {
    isLoading = true;
    notifyListeners();
    try {
      // Check for remote storage protocols (SFTP, FTP, WebDAV)
      if (folder.path.startsWith('sftp:') ||
          folder.path.startsWith('ftp:') ||
          folder.path.startsWith('webdav:')) {
        await _scanRemoteFolder(folder, metadata: metadata);
        return;
      }

      if (folder.accountId.isNotEmpty) {
        await rescanOneDriveFolder(
            auth: auth, folder: folder, metadata: metadata);
      } else {
        await _scanLocalFolder(folder.path, metadata: metadata);
      }
    } catch (e) {
      error = e.toString();
    } finally {
      finishScan(); // Resets flags
      await saveLibrary();
      notifyListeners();
    }
  }

  Future<void> rescanAll({
    required graph_auth.GraphAuthService auth,
    MetadataService? metadata,
  }) async {
    error = null;
    isLoading = true;
    notifyListeners();

    try {
      // 1. Prune orphans (Items not belonging to any active folder)
      _pruneOrphans();

      for (final folder in libraryFolders) {
        if (folder.accountId.isNotEmpty) {
          // Cloud folder (OneDrive)
          await rescanOneDriveFolder(
            auth: auth,
            folder: folder,
            metadata: metadata,
          );
        } else {
          // Local folder
          await _scanLocalFolder(folder.path, metadata: metadata);
        }
      }
    } catch (e) {
      error = e.toString();
    } finally {
      finishScan();
      await saveLibrary();
      _configChangedController.add(null);
    }
  }

  void _pruneOrphans() {
    final before = _allItems.length;
    _allItems.removeWhere((item) {
      // OneDrive
      if (item.id.startsWith('onedrive_')) {
        return !libraryFolders.any((f) {
          if (f.accountId.isEmpty) return false;
          // item.id format: onedrive_{accountId}_{fileId}
          // Ensure access to this specific account folder
          // And strictly, check if folder path covers it.
          final prefix =
              'onedrive:${f.accountId}${f.path.isEmpty ? '/' : f.path}';
          return item.folderPath.startsWith(prefix);
        });
      }

      // Local
      return !libraryFolders.any((f) {
        if (f.accountId.isNotEmpty) return false;
        // Case-insensitive check for Windows friendliness
        return item.filePath.toLowerCase().startsWith(f.path.toLowerCase());
      });
    });

    if (_allItems.length != before) {
      AppLogger.d('Pruned ${before - _allItems.length} orphan items', tag: 'LibraryProvider');
      notifyListeners();
    }
  }

  Future<void> refetchAllMetadata(MetadataService metadata,
      {bool onlyMissing = false}) async {
    isLoading = true;
    _setScanStatus('Refreshing metadata...');
    notifyListeners();

    try {
      final itemsToProcess = onlyMissing
          ? _allItems
              .where(
                  (i) => i.tmdbId == null && i.anilistId == null && !i.isAdult)
              .toList()
          : _allItems;

      if (itemsToProcess.isEmpty) {
        _setScanStatus('No missing metadata found.');
        notifyListeners();
        return;
      }

      // Parallelize metadata enrichment with a concurrency limit
      const batchSize = 5;
      for (int i = 0; i < itemsToProcess.length; i += batchSize) {
        final batch = itemsToProcess.skip(i).take(batchSize).toList();
        _setScanStatus(
            'Refreshing metadata (${i + 1}/${itemsToProcess.length}) ${batch.first.title ?? batch.first.fileName}');
        notifyListeners();

        final enrichedBatch =
            await Future.wait(batch.map((item) => metadata.enrich(item)));

        for (int j = 0; j < batch.length; j++) {
          final enriched = enrichedBatch[j];
          final index = _allItems.indexWhere((e) => e.id == enriched.id);
          if (index != -1) {
            _allItems[index] = enriched;
          }
        }
        notifyListeners();

        // Incremental save every 25 items
        if ((i + batch.length) % 25 == 0) {
          await saveLibrary();
        }
      }

      await saveLibrary();
      _setScanStatus('Metadata refresh complete.');
      notifyListeners();
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      // Clear status after a delay? For now, leave it or clear it.
      // _setScanStatus('');
      _configChangedController.add(null);
    }
  }

  Future<void> pickAndScan(
      {MetadataService? metadata, LibraryType? forcedType}) async {
    error = null;
    beginScan(sourceLabel: 'Local files');
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        final result = await FilePicker.platform.pickFiles(
          allowMultiple: true,
          type: FileType.custom,
          allowedExtensions: ['mp4', 'mkv', 'avi', 'mov', 'webm'],
        );
        if (result == null) return;
        final files =
            result.paths.whereType<String>().map(PlatformFile.new).toList();
        await _ingestFiles(files, metadata);
      } else {
        final path = await FilePicker.platform.getDirectoryPath();
        if (path == null) return;

        // Add to persistent library folders if not exists
        final exists = libraryFolders.any((f) => f.path == path);
        if (!exists) {
          await addLibraryFolder(LibraryFolder(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              path: path,
              accountId: '',
              type:
                  forcedType ?? LibraryType.other // Use forcedType if provided
              ));
        }

        await _scanLocalFolder(path, metadata: metadata);
      }
    } catch (e) {
      error = e.toString();
    } finally {
      finishScan();
      await saveLibrary(); // Redundant but safe
      _configChangedController.add(null);
    }
  }

  Future<void> updateLibraryFolderType(
      String folderId, LibraryType newType) async {
    final index = libraryFolders.indexWhere((f) => f.id == folderId);
    if (index != -1) {
      final old = libraryFolders[index];
      libraryFolders[index] = LibraryFolder(
        id: old.id,
        path: old.path,
        accountId: old.accountId,
        type: newType,
      );
      await saveLibrary();
      notifyListeners();
    }
  }

  Future<void> _ingestFiles(
      List<PlatformFile> files, MetadataService? metadata) async {
    final newItems = <MediaItem>[];
    for (final f in files) {
      if (LocalScanService.isVideo(f.path)) {
        newItems.add(LocalScanService.parseFile(f));
      }
    }
    await _ingestItems(newItems, metadata);
  }

  Future<void> _ingestItems(
      List<MediaItem> newItems, MetadataService? metadata) async {
    final existingPaths = {for (var i in _allItems) i.filePath};
    final itemsToEnrich = <MediaItem>[];

    // Identify items that are actually new to the library
    for (final item in newItems) {
      if (!existingPaths.contains(item.filePath)) {
        itemsToEnrich.add(item);
      }
    }

    final map = {for (var i in _allItems) i.filePath: i};
    for (final newItem in newItems) {
      if (!map.containsKey(newItem.filePath)) {
        map[newItem.filePath] = newItem;
      } else {
        // Merge Check: If existing item has WRONG classification vs new item (which comes from strict folder), update it.
        final existing = map[newItem.filePath]!;
        if (existing.isAdult != newItem.isAdult ||
            existing.isAnime != newItem.isAnime ||
            (existing.type != newItem.type &&
                newItem.type != MediaType.unknown)) {
          map[newItem.filePath] = existing.copyWith(
            isAdult: newItem.isAdult,
            isAnime: newItem.isAnime,
            type: newItem.type != MediaType.unknown
                ? newItem.type
                : existing.type,
          );
        }
      }
    }
    _allItems = map.values.toList()
      ..sort((a, b) => b.lastModified.compareTo(a.lastModified));

    _rebuildFilteredItems(); // Update filtered view immediately
    notifyListeners();

    if (settings.autoFetchAfterScan &&
        metadata != null &&
        itemsToEnrich.isNotEmpty) {
      // Parallelize metadata enrichment with a concurrency limit
      const batchSize = 5;
      for (int i = 0; i < itemsToEnrich.length; i += batchSize) {
        final batch = itemsToEnrich.skip(i).take(batchSize).toList();
        _setScanStatus(
            'Fetching metadata: ${batch.first.title ?? batch.first.fileName} ...');
        final enrichedBatch =
            await Future.wait(batch.map((item) => metadata.enrich(item)));

        for (int j = 0; j < batch.length; j++) {
          final enriched = enrichedBatch[j];
          final index = _allItems.indexWhere((e) => e.id == enriched.id);
          if (index != -1) _allItems[index] = enriched;

          // --- Persistent Metadata (Sidecar) & Renaming Logic ---
          _queuePersistentMetadata(enriched);
        }

        notifyListeners();

        // Incremental save every 25 items
        if ((i + batch.length) % 25 == 0) {
          await saveLibrary();
        }
      }
    }
  }

  /// Manually runs the Sidecar Write & Auto-Rename logic on ALL current items.
  void enforceSidecarsAndNaming() {
    _setScanStatus('Generating NFO files...');
    notifyListeners();

    int processed = 0;
    for (final item in _allItems) {
      _queuePersistentMetadata(item);
      processed++;
      if (processed % 50 == 0) notifyListeners();
    }

    // We don't await the queue here, just the scheduling.
    Future.delayed(const Duration(seconds: 3), () {
      _setScanStatus('Queued $processed items for generation.'); // Clear status
      notifyListeners();
      
      Future.delayed(const Duration(seconds: 2), () {
         _setScanStatus('');
         notifyListeners();
      });
    });
  }

  /// Helper to queue Sidecar writes and Renaming for an item
  void _queuePersistentMetadata(MediaItem enriched) {
    if (!enriched.id.startsWith('onedrive_')) return;

    // Check if we have enough metadata to be useful
    final hasMeta = enriched.tmdbId != null ||
        enriched.anilistId != null ||
        enriched.type == MediaType.scene;
    if (!hasMeta) return;

    final parts = enriched.id.split('_');
    if (parts.length < 3) return;

    final accountId = parts[1];
    final itemId = parts[2];

    // 1. Write NFO Sidecar
    final prefix = 'onedrive:$accountId';
    if (enriched.folderPath.startsWith(prefix)) {
      var relPath = enriched.folderPath.substring(prefix.length);
      // Robustly remove all leading slashes
      while (relPath.startsWith('/')) {
        relPath = relPath.substring(1);
      }
      final parentRef = relPath.isEmpty ? 'root' : 'root:/$relPath';

      final nfoName = '${p.basenameWithoutExtension(enriched.fileName)}.nfo';

      // "Enforce" implies ensuring it exists.
      final nfoContent = SidecarService.generateNfo(enriched);

      TaskQueueService.instance.run('Saving metadata: $nfoName', () async {
        await graph_auth.GraphAuthService.instance.uploadString(
          accountId: accountId,
          parentId: parentRef,
          filename: nfoName,
          content: nfoContent,
        );
      });
    }


  }

  /// Refetch metadata only for items inside a specific library folder.
  /// [folderPath] is the root path, [label] is a friendly name: e.g. 'Anime'.
  Future<void> refetchMetadataForFolder(
    String folderPath,
    String label,
    MetadataService metadata,
  ) async {
    var normalized = folderPath.trim();
    if (normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }

    final targetItems = _allItems.where((item) {
      final path = item.folderPath.trim();
      // Match exact folder or any subfolder
      if (path == normalized || path == '$normalized/') return true;
      return path.startsWith('$normalized/');
    }).toList();

    await _refetchMetadataForItems(targetItems, metadata, label);
  }

  /// Internal helper: refetch only for the given items.
  Future<void> _refetchMetadataForItems(
    List<MediaItem> targetItems,
    MetadataService metadata,
    String label,
  ) async {
    if (targetItems.isEmpty) return;

    isLoading = true;
    _setScanStatus(
        'Refreshing $label metadata (${targetItems.length} items)...');
    notifyListeners();

    try {
      // Parallelize metadata enrichment with a concurrency limit
      const batchSize = 5;
      for (int i = 0; i < targetItems.length; i += batchSize) {
        final batch = targetItems.skip(i).take(batchSize).toList();
        _setScanStatus(
            '[$label] (${i + 1}/${targetItems.length}) ${batch.first.title ?? batch.first.fileName} ...');
        notifyListeners();
        final enrichedBatch =
            await Future.wait(batch.map((item) => metadata.enrich(item)));
        for (int j = 0; j < batch.length; j++) {
          final index = _allItems.indexWhere((e) => e.id == batch[j].id);
          if (index != -1) {
            _allItems[index] = enrichedBatch[j];
          }
        }
        notifyListeners();

        // Incremental save every 25 items
        if ((i + batch.length) % 25 == 0) {
          await saveLibrary();
        }
      }

      await saveLibrary();

      _setScanStatus('Finished refreshing $label metadata.');
      notifyListeners();
    } finally {
      isLoading = false;
      // Let the finished message linger briefly; UI may clear it after delay.
      _configChangedController.add(null);
    }
  }

  Future<void> rescanOneDriveFolder({
    required graph_auth.GraphAuthService auth,
    required LibraryFolder folder,
    MetadataService? metadata,
  }) async {
    error = null;
    isLoading = true;
    final folderLabel = folder.path.isEmpty ? '/' : folder.path;
    _setScanStatus('Scanning Cloud: $folderLabel...');

    try {
      final account = auth.accounts.firstWhere(
        (a) => a.id == folder.accountId,
        orElse: () =>
            throw Exception('No account found for id ${folder.accountId}'),
      );
      final token = await auth.getFreshAccessToken(account.id);

      String requestUrl;
      final baseUrl = '${auth.graphBaseUrl}/me/drive';

      String path = folder.path.trim();
      if (path.startsWith('/')) path = path.substring(1);
      if (path.endsWith('/')) path = path.substring(0, path.length - 1);

      if (path.isEmpty) {
        requestUrl = '$baseUrl/root/children';
      } else {
        requestUrl = '$baseUrl/root:/$path:/children';
      }

      _setScanStatus('Scanning cloud files in $folderLabel...');

      // Delegate scanning to OneDriveScanService
      final foundItems = await OneDriveScanService.walkFolder(
        token: token,
        url: requestUrl,
        baseFolderPath: 'onedrive:${account.id}${path.isEmpty ? '' : '/$path'}',
        accountId: account.id,
        cancelRequested: () => cancelRequested,
        onProgress: (status) => _setScanStatus(status),
        onItemFound: (item) async {
          // Apply folder type classification
          final parentFolder = libraryFolders.firstWhereOrNull((f) {
            if (f.accountId != account.id) return false;
            final fPath = f.path.startsWith('/') ? f.path : '/${f.path}';
            final prefix =
                'onedrive:${f.accountId}${fPath == '/' ? '/' : fPath}';
            return item.folderPath.startsWith(prefix);
          });

          bool initialIsAdult = item.isAdult;
          bool initialIsAnime = item.isAnime;
          MediaType initialType = item.type;

          if (parentFolder != null) {
            if (parentFolder.type == LibraryType.adult) {
              initialIsAdult = true;
              initialType = MediaType.scene;
            }
            if (parentFolder.type == LibraryType.anime) {
              initialIsAnime = true;
            }
          }

          final adjustedItem = item.copyWith(
              isAdult: initialIsAdult,
              isAnime: initialIsAnime,
              type: initialType);

          await _ingestItems([adjustedItem], null);
          reportScanProgress(scanned: (_scanService.scannedCount + 1));
          if (_scanService.scannedCount % 50 == 0) await saveLibrary();
          notifyListeners();
        },
      );

      // Final ingest for any remaining items
      await _ingestItems(foundItems, metadata);
    } catch (e) {
      error = 'Cloud scan failed: $e';
      AppLogger.e('OneDrive Scan Error: $e', error: e, tag: 'LibraryProvider');
    } finally {
      isLoading = false;
      _setScanStatus('');
      await saveLibrary();
      _configChangedController.add(null);
    }
  }

  // _isVideo and _parseFile extracted → LocalScanService

  Future<void> clear() async {
    _allItems = [];
    await saveLibrary();
    notifyListeners();
  }

  List<MediaItem> get movies =>
      LibraryFilterService.filterMovies(items, settings.enableAdultContent);

  List<MediaItem> get adult => LibraryFilterService.filterAdult(items);

  List<MediaItem> get tv =>
      LibraryFilterService.filterTv(items, settings.enableAdultContent);

  List<MediaItem> get anime => LibraryFilterService.filterAnime(items);

  List<TvShowGroup> get groupedTvShows =>
      LibraryFilterService.groupedTvShows(items, settings.enableAdultContent);

  List<TvShowGroup> get groupedAnimeShows =>
      LibraryFilterService.groupedAnimeShows(items);

  List<MediaItem> get continueWatching =>
      LibraryFilterService.filterContinueWatching(
          items, settings.enableAdultContent);

  List<MediaItem> get recentlyAdded =>
      LibraryFilterService.filterRecentlyAdded(
          items, settings.enableAdultContent);

  List<MediaItem> get topRated =>
      LibraryFilterService.filterTopRated(items, settings.enableAdultContent);

  List<MediaItem> getRecommendedLocal(DiscoverType type) =>
      LibraryFilterService.getRecommendedLocal(
          items, type, settings.enableAdultContent);

  MediaItem? findByTmdbId(int tmdbId) =>
      LibraryFilterService.findByTmdbId(items, tmdbId);

  // --- Sync Methods ---

  Future<void> rescanItem(MediaItem item, {MetadataService? metadata}) async {
    bool targetSpecificFolder = false;
    String? scanPath;

    if (item.folderPath.isNotEmpty &&
        PlatformDirectory(item.folderPath).existsSync()) {
      scanPath = item.folderPath;
      targetSpecificFolder = true;
    }

    final keywords = <String>[];
    if (!targetSpecificFolder) {
      final clean = (item.title ?? item.fileName)
          .replaceAll(RegExp(r'[^a-zA-Z0-9\s]'), ' ');
      final parts =
          clean.toLowerCase().split(' ').where((s) => s.isNotEmpty).toList();
      keywords.addAll(parts);
    }

    if (targetSpecificFolder && scanPath != null) {
      await _scanLocalFolder(scanPath, metadata: metadata);
    } else {
      for (final folder in libraryFolders) {
        if (folder.accountId.isEmpty) {
          await _scanLocalFolder(folder.path,
              metadata: metadata, keywords: keywords, libraryType: folder.type);
        }
      }
    }
  }

  /// Explicitly rescan a single item for metadata updates (Cloud or local).
  Future<void> rescanSingleItem(
      MediaItem item, MetadataService metadata) async {
    await _refetchMetadataForItems([item], metadata, 'Single Item');
  }

  Future<void> _scanLocalFolder(String path,
      {MetadataService? metadata,
      List<String>? keywords,
      LibraryType? libraryType}) async {
    final sourceLabel = 'Folder: $path';
    beginScan(sourceLabel: sourceLabel);

    try {
      final scannedItems = await LocalScanService.scanFolder(
        path,
        keywords: keywords,
        onProgress: (currentItem) {
          reportScanProgress(sourceLabel: sourceLabel, currentItem: currentItem);
        },
      );

      if (libraryType != null) {
        for (var i = 0; i < scannedItems.length; i++) {
          final item = scannedItems[i];
          if (libraryType == LibraryType.adult) {
            scannedItems[i] =
                item.copyWith(isAdult: true, type: MediaType.scene);
          } else if (libraryType == LibraryType.anime) {
            scannedItems[i] = item.copyWith(isAnime: true);
          }
        }
      }

      await _ingestItems(scannedItems, metadata);
    } catch (e) {
      error = e.toString();
    } finally {
      finishScan();
      await saveLibrary();
      _configChangedController.add(null);
    }
  }

  /// Scan a remote storage folder (SFTP, FTP, WebDAV)
  Future<void> _scanRemoteFolder(LibraryFolder folder,
      {MetadataService? metadata}) async {
    final sourceLabel = 'Remote: ${folder.displayName}';
    beginScan(sourceLabel: sourceLabel);

    try {
      _setScanStatus('Connecting...');
      notifyListeners();

      final scannedItems = await RemoteScanService.scanFolder(
        folder,
        cancelRequested: () => cancelRequested,
        onProgress: (status) {
          reportScanProgress(sourceLabel: sourceLabel, currentItem: status);
        },
      );

      // Apply library type classifications
      for (var i = 0; i < scannedItems.length; i++) {
        final item = scannedItems[i];
        if (folder.type == LibraryType.adult) {
          scannedItems[i] = item.copyWith(isAdult: true, type: MediaType.scene);
        } else if (folder.type == LibraryType.anime) {
          scannedItems[i] = item.copyWith(isAnime: true);
        }
      }

      await _ingestItems(scannedItems, metadata);
    } catch (e) {
      error = e.toString();
      AppLogger.e('Remote scan error: $e', error: e, tag: 'LibraryProvider');
    } finally {
      finishScan();
      await saveLibrary();
      _configChangedController.add(null);
    }
  }

  Map<String, dynamic> exportState() =>
      LibraryImportExportService.export(libraryFolders, _allItems);

  Map<String, UserMediaData> extractLegacyHistory() =>
      LibraryImportExportService.extractLegacyHistory(_allItems);

  ({int count, int sizeBytes}) getFolderStats(LibraryFolder folder) =>
      LibraryImportExportService.computeFolderStats(_allItems, folder);

  Future<void> importState(Map<String, dynamic> data) async {
    AppLogger.d('Importing library state...', tag: 'LibraryProvider');
    final result = LibraryImportExportService.importState(
      data: data,
      currentFolders: libraryFolders,
      currentItems: _allItems,
    );

    libraryFolders = result.mergedFolders;
    await _saveLibraryFolders();
    _allItems = result.mergedItems;
    await saveLibrary();
    notifyListeners();
    _configChangedController.add(null);
  }

  Future<int> cleanLibrary() async {
    final toRemove =
        await LibraryImportExportService.findOrphanItems(_allItems);

    if (toRemove.isNotEmpty) {
      _allItems.removeWhere((item) => toRemove.contains(item));
      _filteredItems = List.from(_allItems)
        ..sort((a, b) => b.lastModified.compareTo(a.lastModified));
      await saveLibrary();
      notifyListeners();
    }

    return toRemove.length;
  }
}

// Isolate scanning logic extracted → LocalScanService
// Remote scanning logic extracted → RemoteScanService
// OneDrive scanning logic extracted → OneDriveScanService
