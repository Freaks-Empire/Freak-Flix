import 'dart:convert';
import 'dart:io';
import '../utils/platform/platform.dart';
import 'dart:async';
import 'dart:isolate';
import 'package:file_picker/file_picker.dart' hide PlatformFile;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
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
import '../services/remote_storage_service.dart';
import '../services/sftp_client.dart';
import '../services/ftp_client_wrapper.dart';
import '../services/webdav_client_wrapper.dart';
import '../services/scan_orchestration_service.dart';
import '../services/library_filter_service.dart';
import '../services/library_import_export_service.dart';

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
      if (_isVideo(f.path)) {
        newItems.add(_parseFile(f));
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

      // Client-Side Scan
      // 1. Determine Root Endpoint
      // If folder.id looks like a Graph ID (not a timestamp/uuid we generated), use it.
      // But typically we store our own IDs. We rely on path if id is not a Graph ID?
      // Actually, let's just stick to Path-based lookup for simplicity unless we stored the DriveItem ID.
      // Our LibraryFolder.id is usually a timestamp. So we use path.

      String requestUrl;
      final baseUrl = '${auth.graphBaseUrl}/me/drive';

      // Normalize path
      String path = folder.path.trim();
      if (path.startsWith('/')) path = path.substring(1);
      if (path.endsWith('/')) path = path.substring(0, path.length - 1);

      if (path.isEmpty) {
        requestUrl = '$baseUrl/root/children';
      } else {
        requestUrl = '$baseUrl/root:/$path:/children';
      }

      _setScanStatus('Scanning cloud files in $folderLabel...');

      final foundItems = <MediaItem>[];
      await _walkOneDriveFolder(
        token: token,
        url: requestUrl,
        // Use proper path joining prevents double slashes
        baseFolderPath: 'onedrive:${account.id}${path.isEmpty ? '' : '/$path'}',
        accountId: account.id,
        collectedItems: foundItems,
      );

      // Ingest & Enrich (Parallel)
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

  Future<void> _walkOneDriveFolder({
    required String token,
    required String url,
    required String baseFolderPath,
    required String accountId,
    required List<MediaItem> collectedItems,
  }) async {
    if (cancelRequested) return;

    String? nextLink = url;

    while (nextLink != null && !cancelRequested) {
      try {
        final uri = Uri.parse(nextLink);

        final response =
            await http.get(uri, headers: {'Authorization': 'Bearer $token'});
        if (response.statusCode != 200) {
          AppLogger.e('Graph Walk Error: ${response.statusCode} - ${response.body}', tag: 'LibraryProvider');
          return;
        }

        final map = jsonDecode(response.body);
        final List<dynamic> value = map['value'] ?? [];

        for (final item in value) {
          if (cancelRequested) break;

          final name = item['name'] as String;
          final isFolder = item['folder'] != null;
          final isFile = item['file'] != null;
          final id = item['id'] as String;

          if (isFolder) {
            // Recurse
            // "children" usage? Or construct new URL?
            // If folder, we can just append :/children to its item path or use item ID.
            // Using item ID is safer for special chars.
            // URL: /me/drive/items/{item-id}/children
            String childUrl =
                'https://graph.microsoft.com/v1.0/me/drive/items/$id/children';

            await _walkOneDriveFolder(
              token: token,
              url: childUrl,
              baseFolderPath: '$baseFolderPath/$name',
              accountId: accountId,
              collectedItems: collectedItems,
            );
          } else if (isFile) {
            // Check extension
            if (_isVideo(name)) {
              _setScanStatus('Found: $name');
              var newItem =
                  _createMediaItemFromGraph(item, accountId, baseFolderPath);

              // Try to read sibling NFO to lock metadata (stashid, etc.)
              final nfoName = '${p.basenameWithoutExtension(name)}.nfo';
              final nfoEntry = value.cast<Map<String, dynamic>?>().firstWhere(
                    (e) => e != null && (e['name'] as String? ?? '') == nfoName,
                    orElse: () => null,
                  );
              final nfoDownloadUrl = nfoEntry != null
                  ? nfoEntry['@microsoft.graph.downloadUrl'] as String?
                  : null;
              if (nfoDownloadUrl != null) {
                try {
                  final nfoRes = await http.get(Uri.parse(nfoDownloadUrl));
                  if (nfoRes.statusCode == 200) {
                    final nfoData = SidecarService.parseNfo(nfoRes.body);
                    if (nfoData != null) {
                      newItem = newItem.copyWith(
                        stashId: nfoData['stashId'] as String?,
                        tmdbId: nfoData['tmdbId'] as int? ?? newItem.tmdbId,
                        anilistId:
                            nfoData['anilistId'] as int? ?? newItem.anilistId,
                        title: nfoData['title'] as String? ?? newItem.title,
                        year: nfoData['year'] as int? ?? newItem.year,
                      );
                      if (nfoData['stashId'] != null) {
                        AppLogger.d('Found stashid ${nfoData['stashId']} in NFO for $name', tag: 'LibraryProvider');
                      }
                    }
                  }
                } catch (_) {
                  // Ignore NFO fetch errors; continue without lock
                }
              }

              // Determine if adult/anime based on folder type immediately so it shows up in filtered view
              final parentFolder = libraryFolders.firstWhereOrNull((f) {
                if (f.accountId != accountId) return false;
                final fPath = f.path.startsWith('/') ? f.path : '/${f.path}';
                final prefix =
                    'onedrive:${f.accountId}${fPath == '/' ? '/' : fPath}';
                return newItem.folderPath.startsWith(prefix);
              });

              bool initialIsAdult = newItem.isAdult;
              bool initialIsAnime = newItem.isAnime;
              MediaType initialType = newItem.type;

              if (parentFolder != null) {
                if (parentFolder.type == LibraryType.adult) {
                  initialIsAdult = true;
                  initialType = MediaType.scene;
                }
                if (parentFolder.type == LibraryType.anime)
                  initialIsAnime = true;
              }

              final adjustedItem = newItem.copyWith(
                  isAdult: initialIsAdult,
                  isAnime: initialIsAnime,
                  type: initialType);

              await _ingestItems(
                  [adjustedItem], null); // No metadata fetch here!
              collectedItems.add(adjustedItem);

              reportScanProgress(scanned: (_scanService.scannedCount + 1));
              // Throttle saving to avoid UI jank
              if (_scanService.scannedCount % 50 == 0) await saveLibrary();
              notifyListeners();
            }
          }
        }

        nextLink = map['@odata.nextLink'];
      } catch (e) {
        AppLogger.e('Graph Walk Exception: $e', error: e, tag: 'LibraryProvider');
        nextLink = null;
      }
    }
  }

  MediaItem _createMediaItemFromGraph(
      Map<String, dynamic> json, String accountId, String folderPath) {
    final id = json['id'] as String;
    final name = json['name'] as String;
    final size = json['size'] as int? ?? 0;
    final lastModStr = json['lastModifiedDateTime'] as String?;
    final lastMod =
        lastModStr != null ? DateTime.parse(lastModStr) : DateTime.now();

    final parsed = FilenameParser.parse(name);

    // Construct overview with Studio if available
    String? overview;
    if (parsed.studio != null) {
      overview = 'Studio: ${parsed.studio}\n';
    }

    List<CastMember> cast = [];
    if (parsed.performers.isNotEmpty) {
      cast = parsed.performers
          .map<CastMember>((p) => CastMember(
              name: p,
              id: '',
              character: 'Performer',
              source: CastSource.stashDb))
          .toList();
    }
    // Usually: onedrive_{accountId}_{fileId}
    final itemId = 'onedrive_${accountId}_$id';

    return MediaItem(
      id: itemId,
      filePath: name, // Display purpose mostly
      fileName: name,
      folderPath: folderPath, // e.g. onedrive:ACCOUNT/Movies/Action
      sizeBytes: size,
      lastModified: lastMod,
      title: parsed.seriesTitle,
      year: parsed.year, // Use parsed year (from date or YYYY)
      overview: overview,
      cast: cast,
      isAdult:
          parsed.studio != null, // Hint: if studio parsed, likely adult scene
      type: parsed.studio != null ? MediaType.scene : MediaType.unknown,
    );
  }

  bool _isVideo(String path) {
    final ext = p.extension(path).toLowerCase();
    return const ['.mp4', '.mkv', '.avi', '.mov', '.webm', '.m4v']
        .contains(ext);
  }

  MediaItem _parseFile(PlatformFile f) {
    final filePath = f.path;
    final fileName = p.basename(filePath);
    final folder = filePath.isNotEmpty ? p.dirname(filePath) : '';
    final id = filePath.isNotEmpty
        ? filePath.hashCode.toString()
        : fileName.hashCode.toString();

    final size = f.statSync().size;

    final parsed = FilenameParser.parse(fileName);
    final animeHint = folder.toLowerCase().contains('anime');

    String? overview;
    if (parsed.studio != null) {
      overview = 'Studio: ${parsed.studio}\n';
    }

    List<CastMember> cast = [];
    if (parsed.performers.isNotEmpty) {
      cast = parsed.performers
          .map<CastMember>((p) => CastMember(
              name: p,
              id: '',
              character: 'Performer',
              source: CastSource.stashDb))
          .toList();
    }

    final type = parsed.studio != null ? MediaType.scene : MediaType.movie;

    var item = MediaItem(
      id: id,
      filePath: filePath,
      fileName: fileName,
      folderPath: folder,
      sizeBytes: size,
      lastModified: f.statSync().modified,
      title: parsed.seriesTitle,
      year: parsed.year,
      type: type,
      season: parsed.season,
      episode: parsed.episode,
      isAnime: animeHint,
      showKey: folder.toLowerCase(),
      overview: overview,
      cast: cast,
      isAdult: parsed.studio != null,
    );

    // Read sibling NFO sidecar if present to lock identifiers/metadata
    final nfoPath = p.setExtension(filePath, '.nfo');
    final nfoFile = File(nfoPath);
    if (nfoFile.existsSync()) {
      try {
        final nfoData = SidecarService.parseNfo(nfoFile.readAsStringSync());
        if (nfoData != null) {
          item = item.copyWith(
            stashId: nfoData['stashId'] as String?,
            tmdbId: nfoData['tmdbId'] as int? ?? item.tmdbId,
            anilistId: nfoData['anilistId'] as int? ?? item.anilistId,
            title: nfoData['title'] as String? ?? item.title,
            year: nfoData['year'] as int? ?? item.year,
          );
        }
      } catch (_) {
        // Ignore malformed NFOs and continue
      }
    }

    return item;
  }

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
      final port = ReceivePort();
      await Isolate.spawn(
        _scanDirectoryInIsolate,
        _ScanRequest(port.sendPort, path, keywords: keywords),
      );

      final scannedItems = <MediaItem>[];
      await for (final message in port) {
        if (message is String) {
          reportScanProgress(sourceLabel: sourceLabel, currentItem: message);
        } else if (message is List<MediaItem>) {
          scannedItems.addAll(message);
        } else if (message == true) {
          port.close();
          break; // Done signal
        }
      }

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
      // Parse protocol and account ID from path
      // Format: sftp:accountId/path or ftp:accountId/path or webdav:accountId/path
      final pathParts = folder.path.split(':');
      if (pathParts.length < 2) {
        throw Exception('Invalid remote path format: ${folder.path}');
      }
      
      final protocol = pathParts[0];
      final remainder = pathParts.sublist(1).join(':');
      final accountId = folder.accountId;
      
      // Extract the actual remote path (after accountId prefix)
      String remotePath = '/';
      if (remainder.startsWith(accountId)) {
        remotePath = remainder.substring(accountId.length);
        if (remotePath.isEmpty) remotePath = '/';
      } else {
        // Path might just be the full path after protocol:
        remotePath = remainder.startsWith('/') ? remainder : '/$remainder';
      }

      // Get the account
      final account = RemoteStorageService.instance.getAccount(accountId);
      if (account == null) {
        throw Exception('Remote account not found: $accountId');
      }

      // Get password
      final password = await RemoteStorageService.instance.getPassword(accountId);
      if (password == null) {
        throw Exception('No credentials found for account');
      }

      _setScanStatus('Connecting to ${account.host}...');
      notifyListeners();

      // Convert protocol to type
      RemoteStorageType type;
      switch (protocol) {
        case 'sftp':
          type = RemoteStorageType.sftp;
          break;
        case 'ftp':
          type = RemoteStorageType.ftp;
          break;
        case 'webdav':
          type = RemoteStorageType.webdav;
          break;
        default:
          throw Exception('Unknown protocol: $protocol');
      }

      // Scan based on protocol type
      final scannedItems = <MediaItem>[];
      
      switch (type) {
        case RemoteStorageType.sftp:
          final client = SftpClient(account);
          if (await client.connect(password)) {
            await _scanSftpDirectory(client, remotePath, folder, scannedItems, sourceLabel);
            client.disconnect();
          } else {
            throw Exception('Failed to connect to SFTP server');
          }
          break;
          
        case RemoteStorageType.ftp:
          final client = FtpClientWrapper(account);
          if (await client.connect(password)) {
            await _scanFtpDirectory(client, remotePath, folder, scannedItems, sourceLabel);
            await client.disconnect();
          } else {
            throw Exception('Failed to connect to FTP server');
          }
          break;
          
        case RemoteStorageType.webdav:
          final client = WebDavClientWrapper(account);
          if (await client.connect(password)) {
            await _scanWebDavDirectory(client, remotePath, folder, scannedItems, sourceLabel);
            client.disconnect();
          } else {
            throw Exception('Failed to connect to WebDAV server');
          }
          break;
      }

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

  /// Recursively scan SFTP directory
  Future<void> _scanSftpDirectory(
    SftpClient client,
    String path,
    LibraryFolder folder,
    List<MediaItem> items,
    String sourceLabel,
  ) async {
    try {
      final files = await client.listDirectory(path);
      
      for (final file in files) {
        if (cancelRequested) break;
        
        if (file.isDirectory) {
          // Recursively scan subdirectories
          await _scanSftpDirectory(client, file.path, folder, items, sourceLabel);
        } else if (_isMediaFile(file.name)) {
          reportScanProgress(sourceLabel: sourceLabel, currentItem: file.name);
          
          // Create MediaItem for this file
          final item = _createRemoteMediaItem(file, folder);
          items.add(item);
        }
      }
    } catch (e) {
      AppLogger.e('Error scanning SFTP directory $path: $e', error: e, tag: 'LibraryProvider');
    }
  }

  /// Recursively scan FTP directory
  Future<void> _scanFtpDirectory(
    FtpClientWrapper client,
    String path,
    LibraryFolder folder,
    List<MediaItem> items,
    String sourceLabel,
  ) async {
    try {
      final files = await client.listDirectory(path);
      
      for (final file in files) {
        if (cancelRequested) break;
        
        if (file.isDirectory) {
          await _scanFtpDirectory(client, file.path, folder, items, sourceLabel);
        } else if (_isMediaFile(file.name)) {
          reportScanProgress(sourceLabel: sourceLabel, currentItem: file.name);
          
          final item = _createRemoteMediaItem(file, folder);
          items.add(item);
        }
      }
    } catch (e) {
      AppLogger.e('Error scanning FTP directory $path: $e', error: e, tag: 'LibraryProvider');
    }
  }

  /// Recursively scan WebDAV directory
  Future<void> _scanWebDavDirectory(
    WebDavClientWrapper client,
    String path,
    LibraryFolder folder,
    List<MediaItem> items,
    String sourceLabel,
  ) async {
    try {
      final files = await client.listDirectory(path);
      
      for (final file in files) {
        if (cancelRequested) break;
        
        if (file.isDirectory) {
          await _scanWebDavDirectory(client, file.path, folder, items, sourceLabel);
        } else if (_isMediaFile(file.name)) {
          reportScanProgress(sourceLabel: sourceLabel, currentItem: file.name);
          
          final item = _createRemoteMediaItem(file, folder);
          items.add(item);
        }
      }
    } catch (e) {
      AppLogger.e('Error scanning WebDAV directory $path: $e', error: e, tag: 'LibraryProvider');
    }
  }

  /// Create a MediaItem from a remote file
  MediaItem _createRemoteMediaItem(RemoteFile file, LibraryFolder folder) {
    // Parse title from filename
    final parsed = FilenameParser.parse(file.name);
    
    // Determine media type from folder type
    MediaType type;
    switch (folder.type) {
      case LibraryType.movies:
        type = MediaType.movie;
        break;
      case LibraryType.tv:
        type = MediaType.tv;
        break;
      case LibraryType.anime:
        type = MediaType.tv;
        break;
      case LibraryType.adult:
        type = MediaType.scene;
        break;
      case LibraryType.other:
        type = MediaType.movie;
        break;
    }

    // Create unique ID: protocol:accountId:path
    final itemId = '${folder.path.split(':').first}:${folder.accountId}:${file.path}';
    
    // Extract folder path from file path
    final folderPathFromFile = file.path.contains('/') 
        ? file.path.substring(0, file.path.lastIndexOf('/'))
        : '/';

    // Build full filePath with protocol prefix for remote files
    final filePath = '${folder.path.split(':').first}:${folder.accountId}:${file.path}';

    return MediaItem(
      id: itemId,
      title: parsed.movieTitle ?? file.name.replaceAll(RegExp(r'\.[^.]+$'), ''),
      year: parsed.year,
      type: type,
      filePath: filePath,
      fileName: file.name,
      folderPath: folderPathFromFile,
      sizeBytes: file.size ?? 0,
      lastModified: file.modifiedTime ?? DateTime.now(),
      season: parsed.season,
      episode: parsed.episode,
      isAdult: folder.type == LibraryType.adult,
      isAnime: folder.type == LibraryType.anime,
    );
  }

  /// Check if a file is a media file based on extension
  bool _isMediaFile(String filename) {
    final ext = filename.toLowerCase().split('.').lastOrNull ?? '';
    const videoExtensions = [
      'mp4', 'mkv', 'avi', 'mov', 'wmv', 'flv', 'webm', 'm4v',
      'mpg', 'mpeg', 'ts', 'm2ts', 'vob', 'divx', 'xvid', '3gp'
    ];
    return videoExtensions.contains(ext);
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

// --- Top-Level Helpers and Isolate Logic ---

class _ScanRequest {
  final SendPort sendPort;
  final String path;
  final List<String>? keywords;

  _ScanRequest(this.sendPort, this.path, {this.keywords});
}

// Helper for manual recursion to catch errors per-directory and avoid native crash
Future<void> _scanRecursive(
  PlatformDirectory dir,
  List<String>? keywords,
  List<MediaItem> buffer,
  SendPort sendPort,
  int bufferSize,
) async {
  try {
    // Explicitly skip system folders that often cause crashes/hangs
    final name = p.basename(dir.path);
    if (const {
      '\$Recycle.Bin',
      'System Volume Information',
      'Windows',
      'Program Files',
      'Program Files (x86)'
    }.contains(name)) {
      return;
    }

// List non-recursively first
    await for (final fsEntity
        in dir.list(recursive: false, followLinks: false).handleError((e) {
      AppLogger.w('Skip dir error: $e', error: e, tag: 'LibraryProvider');
    })) {
      try {
        if (fsEntity is PlatformFile) {
          final pathStr = fsEntity.path;
          final ext = p.extension(pathStr).toLowerCase();
          final isVideo = const [
            '.mp4',
            '.mkv',
            '.avi',
            '.mov',
            '.webm',
            '.m4v'
          ].contains(ext);

          if (isVideo) {
            if (keywords != null && keywords.isNotEmpty) {
              final fName = p.basename(pathStr).toLowerCase();
              if (!keywords.any((k) => fName.contains(k))) continue;
            }

            final fileName = p.basename(pathStr);
            // Stat might fail too
            final stat = fsEntity.statSync();

            final parsed = FilenameParser.parse(fileName);

            final item = MediaItem(
              id: pathStr.hashCode.toString(),
              filePath: pathStr,
              fileName: fileName,
              folderPath: p.dirname(pathStr),
              sizeBytes: stat.size,
              lastModified: stat.modified,
              title: parsed.seriesTitle,
              year: parsed.year,
              type: parsed.studio != null ? MediaType.scene : MediaType.movie,
              season: parsed.season,
              episode: parsed.episode,
              isAnime: pathStr.toLowerCase().contains('anime'),
              showKey: p.dirname(pathStr).toLowerCase(),
              isAdult: parsed.studio != null,
            );

            buffer.add(item);

            // Debug Log for crash tracing
            // debugPrint('Scanned: $pathStr');

            if (buffer.length >= bufferSize) {
              sendPort.send(List<MediaItem>.from(buffer));
              buffer.clear();
            }
          }
        } else if (fsEntity is PlatformDirectory) {
          // Recurse manually
          await _scanRecursive(
              fsEntity, keywords, buffer, sendPort, bufferSize);
        }
      } catch (innerE) {
        // debugPrint('Skip entity error: $innerE');
      }
    }
  } catch (dirE) {
    // debugPrint('Directory access error: $dirE');
  }
}

Future<void> _scanDirectoryInIsolate(_ScanRequest request) async {
  final root = request.path;
  final keywords = request.keywords;
  final sendPort = request.sendPort;

  AppLogger.d('Isolate calling manual scan on: $root', tag: 'LibraryProvider');

  try {
    final dir = PlatformDirectory(root);
    if (!dir.existsSync()) {
      sendPort.send(true);
      return;
    }

    final buffer = <MediaItem>[];
    const bufferSize = 50;

    await _scanRecursive(dir, keywords, buffer, sendPort, bufferSize);

    if (buffer.isNotEmpty) {
      sendPort.send(List<MediaItem>.from(buffer));
    }

    sendPort.send(true); // DONE signal
  } catch (e) {
    AppLogger.critical('Isolate Fatal Error: $e', error: e, tag: 'LibraryProvider');
    sendPort.send(true);
  }
}


