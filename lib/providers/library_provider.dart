/// lib/providers/library_provider.dart
import 'dart:convert';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import '../utils/platform/platform.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'dart:async';
import 'dart:isolate';
import 'package:file_picker/file_picker.dart' hide PlatformFile;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/library_folder.dart';
import '../models/user_profile.dart'; // Import for UserProfile and UserMediaData
import '../models/media_item.dart';
import '../services/graph_auth_service.dart' as graph_auth;
import '../services/persistence_service.dart';
import '../services/metadata_service.dart';

import 'settings_provider.dart';
import '../utils/filename_parser.dart';
import 'package:collection/collection.dart';
import 'package:archive/archive.dart';

class LibraryProvider extends ChangeNotifier {
  static const _prefsKey = 'library_v1';
  static const _libraryFoldersKey = 'library_folders_v1';

  final SettingsProvider settings;
  
  // backing store
  List<MediaItem> _allItems = [];
  
  // exposed to UI (filtered + user data applied)
  List<MediaItem> _filteredItems = [];
  
  List<MediaItem> get items => _filteredItems;
  List<MediaItem> get allItems => List.unmodifiable(_allItems);

  List<LibraryFolder> libraryFolders = [];
  bool isLoading = false;
  String? error;
  String scanningStatus = '';

  final _configChangedController = StreamController<void>.broadcast();
  Stream<void> get onConfigChanged => _configChangedController.stream;

  // Profile State
  UserProfile? _currentProfile;
  Map<String, UserMediaData> _currentUserData = {};

  void updateProfile(UserProfile? profile, Map<String, UserMediaData> userData) {
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


  // Scan progress state
  bool isScanning = false;
  int scannedCount = 0;
  int totalToScan = 0;
  String? currentScanSource;
  String? currentScanItem;
  bool _cancelScanRequested = false;

  void beginScan({String? sourceLabel, int? total}) {
    isLoading = true;
    isScanning = true;
    _cancelScanRequested = false;

    scannedCount = 0;
    totalToScan = total ?? 0;
    currentScanSource = sourceLabel;
    currentScanItem = null;

    if (Platform.isAndroid || Platform.isIOS) {
       WakelockPlus.enable();
       _requestNotificationPermission();
    }

    if (Platform.isAndroid) {
      FlutterForegroundTask.startService(
        notificationTitle: 'Scanning Library',
        notificationText: 'Starting scan...',
      );
    }

    _updateScanningStatus();
    notifyListeners();
  }

  void reportScanProgress({
    int? scanned,
    int? total,
    String? currentItem,
    String? sourceLabel,
  }) {
    if (scanned != null) scannedCount = scanned;
    if (total != null) totalToScan = total;
    if (sourceLabel != null && sourceLabel.isNotEmpty) {
      currentScanSource = sourceLabel;
    }
    if (currentItem != null && currentItem.isNotEmpty) {
      currentScanItem = currentItem;
    }
    _updateScanningStatus();
    notifyListeners();
  }

  void finishScan() {
    isScanning = false;
    isLoading = false;
    _cancelScanRequested = false;

    scannedCount = 0;
    totalToScan = 0;
    currentScanSource = null;
    currentScanItem = null;
    scanningStatus = '';

    if (Platform.isAndroid || Platform.isIOS) {
       WakelockPlus.disable();
    }
    
    if (Platform.isAndroid) {
      FlutterForegroundTask.stopService();
      _showCompletionNotification();
    }

    notifyListeners();
  }

  Future<void> _requestNotificationPermission() async {
    if (Platform.isAndroid) {
      if (await Permission.notification.isDenied) {
        await Permission.notification.request();
      }
    }
  }

  Future<void> _showCompletionNotification() async {
    const androidDetails = AndroidNotificationDetails(
      'scan_complete_channel',
      'Scan Complete',
      channelDescription: 'Notifies when library scan is finished',
      importance: Importance.high,
      priority: Priority.high,
    );
    const details = NotificationDetails(android: androidDetails);
    await _notifications.show(
      0,
      'Scan Complete',
      'Library scan finished successfully.',
      details,
    );
  }

  bool get cancelRequested => _cancelScanRequested;

  void requestCancelScan() {
    if (!isScanning) return;
    _cancelScanRequested = true;
    scanningStatus = 'Cancelling…';
    notifyListeners();
  }



  void _updateScanningStatus() {
    if (!isScanning) {
      scanningStatus = '';
      return;
    }

    final where = currentScanSource ?? '';
    final item = currentScanItem ?? '';
    String statusMsg = '';

    if (totalToScan > 0) {
      statusMsg = 'Scanning $where  ($scannedCount / $totalToScan)… ${item.isEmpty ? '' : item}';
    } else {
      statusMsg = 'Scanning $where… ${item.isEmpty ? '' : item}';
    }

    scanningStatus = statusMsg;
    
    if (Platform.isAndroid) {
        FlutterForegroundTask.updateService(
          notificationTitle: 'Freak-Flix Scanning',
          notificationText: statusMsg,
        );
    }
  }

  void _setScanStatus(String message) {
    scanningStatus = message;
    notifyListeners();
  }

  @override
  void dispose() {
    _configChangedController.close();
    super.dispose();
  }

  LibraryProvider(this.settings) {
    if (Platform.isAndroid) {
      _initForegroundTask();
    }
  }

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();

  void _initForegroundTask() {
    // Init Local Notifications
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestSoundPermission: false,
      requestBadgePermission: false,
      requestAlertPermission: false,
    );
    const initSettings = InitializationSettings(android: androidSettings, iOS: iosSettings);
    _notifications.initialize(initSettings);

    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'scanning_channel',
        channelName: 'Library Scanning',
        channelDescription: 'Shows progress when scanning library in background',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(5000),
        autoRunOnBoot: false,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  static const _foldersFile = 'library_folders.json';
  static const _itemsFile = 'library_items.gz';

  Future<void> loadLibrary() async {
    debugPrint('LibraryProvider: Loading library from file storage...');
    
    // 1. Load Folders
    try {
      final folderJson = await PersistenceService.instance.loadString(_foldersFile);
      if (folderJson != null) {
        libraryFolders = (jsonDecode(folderJson) as List<dynamic>)
            .map((e) => LibraryFolder.fromJson(e as Map<String, dynamic>))
            .toList();
        debugPrint('LibraryProvider: Loaded ${libraryFolders.length} folders from file.');
      } else {
        // Migration check
        await _migrateFoldersFromPrefs();
      }
    } catch (e) {
      debugPrint('LibraryProvider: Error loading folders: $e');
      libraryFolders = [];
    }
    
    // 2. Load Items
    try {
      final itemsJson = await PersistenceService.instance.loadCompressed(_itemsFile);
      if (itemsJson != null) {
          debugPrint('LibraryProvider: Found compressed items file. Parsing...');
          _allItems = MediaItem.listFromJson(itemsJson);
          debugPrint('LibraryProvider: Loaded ${_allItems.length} items from file.');
      } else {
         debugPrint('LibraryProvider: No items file found. Checking legacy...');
         await _migrateItemsFromPrefs();
      }
    } catch (e) {
      debugPrint('LibraryProvider: Error loading items: $e');
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
      debugPrint('LibraryProvider: Migrated folders from SharedPreferences.');
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
        debugPrint('LibraryProvider: Migrated items from SharedPreferences.');
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
                 final prefix = 'onedrive:${f.accountId}${f.path.isEmpty ? '/' : f.path}';
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
            } else if (parentFolder.type == LibraryType.tv || parentFolder.type == LibraryType.anime) {
               newType = MediaType.tv;
            } else if (parentFolder.type == LibraryType.adult) {
               newType = MediaType.scene;
            } else {
               // Other/Unknown: Keep inference but remove anime guessing if not strictly anime?
               // Actually we'll keep inference for 'Other'.
               newType = _inferTypeFromPath(item); 
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
       final prefix = 'onedrive:${folder.accountId}${folder.path.isEmpty ? '/' : folder.path}';
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
             final prefix = 'onedrive:${f.accountId}${f.path.isEmpty ? '/' : f.path}';
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
        debugPrint('LibraryProvider: Pruned ${before - _allItems.length} orphan items.');
        notifyListeners();
    }
  }

  Future<void> refetchAllMetadata(MetadataService metadata) async {
    isLoading = true;
    scanningStatus = 'Refreshing metadata for all items...';
    notifyListeners();

    try {
      // Parallelize metadata enrichment with a concurrency limit
      const batchSize = 5;
      for (int i = 0; i < _allItems.length; i += batchSize) {
        final batch = _allItems.skip(i).take(batchSize).toList();
        scanningStatus =
            'Refreshing metadata (${i + 1}/${_allItems.length}) ${batch.first.title ?? batch.first.fileName}';
        notifyListeners();
        
        final enrichedBatch = await Future.wait(batch.map((item) => metadata.enrich(item)));
        
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
      scanningStatus = 'Metadata refresh complete.';
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



  Future<void> pickAndScan({MetadataService? metadata}) async {
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
        final files = result.paths.whereType<String>().map(PlatformFile.new).toList();
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
                type: LibraryType.other // Default
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

  Future<void> _ingestFiles(List<PlatformFile> files, MetadataService? metadata) async {
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
    for (final item in newItems) {
      // If item exists, preserve its ID and user data (handled by Profile user data apply later, 
      // but we should preserve ID at least if generated from path is stable).
      // MediaItem IDs are usually hash of filePath, so they should be stable.
      // But let's trust the new item's data structure, merging if necessary?
      // Current logic just overwrites. We stick to that.
      map[item.filePath] = item;
    }
    _allItems = map.values.toList()
      ..sort((a, b) => b.lastModified.compareTo(a.lastModified));
    notifyListeners();

    if (settings.autoFetchAfterScan && metadata != null && itemsToEnrich.isNotEmpty) {
      // Parallelize metadata enrichment with a concurrency limit
      const batchSize = 5;
      for (int i = 0; i < itemsToEnrich.length; i += batchSize) {
        final batch = itemsToEnrich.skip(i).take(batchSize).toList();
        _setScanStatus('Fetching metadata: ${batch.first.title ?? batch.first.fileName} ...');
        final enrichedBatch = await Future.wait(batch.map((item) => metadata.enrich(item)));
        
        for (int j = 0; j < batch.length; j++) {
          final enriched = enrichedBatch[j];
          final idx = _allItems.indexWhere((e) => e.filePath == enriched.filePath);
          if (idx != -1) _allItems[idx] = enriched;
        }
        notifyListeners();

        // Incremental save every 25 items
        if ((i + batch.length) % 25 == 0) {
           await saveLibrary();
        }
      }
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
    scanningStatus =
        'Refreshing $label metadata (${targetItems.length} items)...';
    notifyListeners();

    try {
      // Parallelize metadata enrichment with a concurrency limit
      const batchSize = 5;
      for (int i = 0; i < targetItems.length; i += batchSize) {
        final batch = targetItems.skip(i).take(batchSize).toList();
        scanningStatus =
            '[$label] (${i + 1}/${targetItems.length}) ${batch.first.title ?? batch.first.fileName} ...';
        notifyListeners();
        final enrichedBatch = await Future.wait(batch.map((item) => metadata.enrich(item)));
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

      scanningStatus = 'Finished refreshing $label metadata.';
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
      
      await _walkOneDriveFolder(
        token: token, 
        url: requestUrl, 
        baseFolderPath: 'onedrive:${account.id}/${path.isEmpty ? '' : path}',
        accountId: account.id,
        metadata: metadata,
      );


    } catch (e) {
      error = 'Cloud scan failed: $e';
      debugPrint('OneDrive Scan Error: $e');
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
    MetadataService? metadata,
  }) async {
    if (_cancelScanRequested) return;
    
    String? nextLink = url;
    
    while (nextLink != null && !_cancelScanRequested) {
      try {
        // Use direct HTTP to avoid GraphAuthService proxy confusion if on Native (URL is absolute)
        // If on Web, we might need proxy? 
        // GraphAuthService.graphBaseUrl handles proxy prefix.
        // But here we constructed full URL.
        // If kIsWeb, we need to strip 'https://graph.microsoft.com/v1.0' and prepend proxy?
        // Actually, let's rely on http.get handling it if CORS is allowed directly (usually not).
        // WE NEED GraphAuthService HELPER TO CALL WITH CORRECT PROXY IF WEB.
        
        // Helper:
        final uri = Uri.parse(nextLink);
        // On Web, we must route these calls through our proxy if NOT using implicit flow/direct.
        // But our GraphAuthService is configured to use /api/graph/v1.0 proxy on web.
        // So we should construct relative URLs or use a helper.
        // Let's use a quick helper to "proxify" if needed.
        
        Uri finalUri = uri;
        if (kIsWeb && uri.host == 'graph.microsoft.com') {
             // Replace host/scheme with relative proxy path
             // Path usually starts with /v1.0/...
             final path = uri.path; // /v1.0/me/drive...
             // Proxy logic: /api/graph/v1.0/me... 
             // graphBaseUrl returns '/api/graph/v1.0'
             // So we just need to append the path part AFTER v1.0?
             // Or just replace the base.
             // Simple: 
             final newPath = path.replaceFirst('/v1.0', graph_auth.GraphAuthService.instance.graphBaseUrl);
             // Preserve query
             finalUri = Uri(path: newPath, query: uri.query);
        }

        final response = await http.get(finalUri, headers: {'Authorization': 'Bearer $token'});
        if (response.statusCode != 200) {
           debugPrint('Graph Walk Error: ${response.statusCode} - ${response.body}');
           return;
        }

        final map = jsonDecode(response.body);
        final List<dynamic> value = map['value'] ?? [];
        
        for (final item in value) {
            if (_cancelScanRequested) break;
            
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
               String childUrl = 'https://graph.microsoft.com/v1.0/me/drive/items/$id/children';
               
               await _walkOneDriveFolder(
                 token: token,
                 url: childUrl,
                 baseFolderPath: '$baseFolderPath/$name',
                 accountId: accountId,
                 metadata: metadata,
               );
            } else if (isFile) {
               // Check extension
               if (_isVideo(name)) {
                  _setScanStatus('Found: $name');
                  final newItem = _createMediaItemFromGraph(item, accountId, baseFolderPath);
                  await _ingestItems([newItem], metadata);
                  scannedCount++;
                  if (scannedCount % 10 == 0) await saveLibrary();
                  notifyListeners();
               }
            }
        }
        
        nextLink = map['@odata.nextLink'];
        
      } catch (e) {
        debugPrint('Graph Walk Exception: $e');
        nextLink = null;
      }
    }
  }

  MediaItem _createMediaItemFromGraph(Map<String, dynamic> json, String accountId, String folderPath) {
    final id = json['id'] as String;
    final name = json['name'] as String;
    final size = json['size'] as int? ?? 0;
    final lastModStr = json['lastModifiedDateTime'] as String?;
    final lastMod = lastModStr != null ? DateTime.parse(lastModStr) : DateTime.now();
    
    // Construct a unique ID consistent with current app logic
    // Usually: onedrive_{accountId}_{fileId}
    final itemId = 'onedrive_${accountId}_$id';
    
    return MediaItem(
      id: itemId,
      filePath: name, // Display purpose mostly
      fileName: name,
      folderPath: folderPath, // e.g. onedrive:ACCOUNT/Movies/Action
      sizeBytes: size,
      lastModified: lastMod,
      // Store actual download Url? It expires. 
      // We rely on getting it fresh via GraphAuthService.getDownloadUrl using the ID part.
      // We need to store original ID somewhere? 
      // MediaItem ID has it.
    );
  }

  bool _isVideo(String path) {
    final ext = p.extension(path).toLowerCase();
    return const ['.mp4', '.mkv', '.avi', '.mov', '.webm', '.m4v'].contains(ext);
  }



  Future<void> clear() async {
    _allItems = [];
    await saveLibrary();
    notifyListeners();
  }

  Future<void> updateItem(MediaItem updated) async {
    final index = _allItems.indexWhere((i) => i.id == updated.id);
    if (index == -1) return;
    _allItems[index] = updated;
    notifyListeners();
    await saveLibrary();
  }



  List<MediaItem> get movies =>
      items.where((i) => i.type == MediaType.movie && !i.isAdult).toList();

  List<MediaItem> get adult =>
      items.where((i) => i.isAdult).toList();

  // Group TV/anime by showKey and aggregate episodes under one show card.
  // TV tab excludes anime; Anime tab shows only anime.
  List<MediaItem> get tv =>
      _groupShows(items.where((i) => i.type == MediaType.tv && !i.isAnime && !i.isAdult));

  List<MediaItem> get anime =>
      _groupShows(items.where((i) => i.type == MediaType.tv && i.isAnime));

  List<TvShowGroup> get groupedTvShows => _groupShowsToGroups(
      items.where((i) => i.type == MediaType.tv && !i.isAnime && !i.isAdult));

  List<TvShowGroup> get groupedAnimeShows => _groupShowsToGroups(
      items.where((i) => i.type == MediaType.tv && i.isAnime));

  List<MediaItem> get continueWatching =>
      items.where((i) => i.lastPositionSeconds > 0 && !i.isWatched && !i.isAdult).toList();

  List<MediaItem> get recentlyAdded {
    final sorted = items.where((i) => !i.isAdult).toList()
      ..sort((a, b) => b.lastModified.compareTo(a.lastModified));
    return sorted.take(20).toList();
  }

  List<MediaItem> get topRated {
    final sorted = items.where((i) => !i.isAdult).toList()
      ..sort((a, b) => (b.rating ?? 0).compareTo(a.rating ?? 0));
    return sorted.take(20).toList();
  }





  MediaItem? findByTmdbId(int tmdbId) {
    return items.firstWhereOrNull((i) => i.tmdbId == tmdbId);
  }

  // --- Sync Methods ---

  Future<void> rescanItem(MediaItem item, {MetadataService? metadata}) async {
    bool targetSpecificFolder = false;
    String? scanPath;
    
    if (item.folderPath.isNotEmpty && PlatformDirectory(item.folderPath).existsSync()) {
      scanPath = item.folderPath;
      targetSpecificFolder = true;
    }

    final keywords = <String>[];
    if (!targetSpecificFolder) {
      final clean = (item.title ?? item.fileName).replaceAll(RegExp(r'[^a-zA-Z0-9\s]'), ' ');
      final parts = clean.toLowerCase().split(' ').where((s) => s.isNotEmpty).toList();
      keywords.addAll(parts);
    }

    if (targetSpecificFolder && scanPath != null) {
        await _scanLocalFolder(scanPath, metadata: metadata);
    } else {
      for (final folder in libraryFolders) {
        if (folder.accountId.isEmpty) {
          await _scanLocalFolder(folder.path, metadata: metadata, keywords: keywords, libraryType: folder.type);
        }
      }
    }
  }

  Future<void> _scanLocalFolder(String path, {MetadataService? metadata, List<String>? keywords, LibraryType? libraryType}) async {
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
          port.close();
          break;
        }
      }

      if (libraryType != null) {
        for (var i = 0; i < scannedItems.length; i++) {
          final item = scannedItems[i];
          if (libraryType == LibraryType.adult) {
            scannedItems[i] = item.copyWith(isAdult: true, type: MediaType.scene);
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

  Map<String, dynamic> exportState() {
    return {
      'folders': libraryFolders.map((f) => f.toJson()).toList(),
      'items': MediaItem.listToJson(_allItems),
    };
  }

  Map<String, UserMediaData> extractLegacyHistory() {
    final map = <String, UserMediaData>{};
    for (final item in _allItems) {
       if (item.isWatched || item.lastPositionSeconds > 0) {
           map[item.id] = UserMediaData(
               mediaId: item.id,
               positionSeconds: item.lastPositionSeconds,
               isWatched: item.isWatched,
               lastUpdated: DateTime.now(),
           );
           // Optional: clear legacy data from item? No, keep it as backup or for legacy readers.
       }
    }
    return map;
  }

  ({int count, int sizeBytes}) getFolderStats(LibraryFolder folder) {
    // Defines which items belong to this folder
    final relevant = _allItems.where((i) {
      if (folder.accountId.isNotEmpty) {
        // OneDrive items use ID convention: onedrive_{accountId}_{itemId}
        // But checking by path is safer for nested folders? 
        // Our folderPath logic is 'onedrive:{accountId}:{path}'
        // Let's verify if item belongs to this library folder tree.
        // Actually, scanOneDrive uses 'onedrive:{accountId}' prefix for all items from that account.
        // To distinguish between two folders from SAME account, we need path check.
        final rootPath = 'onedrive:${folder.accountId}${folder.path.isEmpty ? '/' : folder.path}';
        return i.folderPath.startsWith(rootPath);
      } else {
        // Local: path starts with folder.path
        return i.filePath.startsWith(folder.path);
      }
    });

    final count = relevant.length;
    final size = relevant.fold<int>(0, (sum, item) => sum + item.sizeBytes);
    return (count: count, sizeBytes: size);
  }

  Future<void> importState(Map<String, dynamic> data) async {
    debugPrint('LibraryProvider: Importing library state...');
    
    // 1. Import Folders
    final rawFolders = data['folders'] as List<dynamic>?;
    if (rawFolders != null) {
      debugPrint('LibraryProvider: Processing ${rawFolders.length} folders from backup');
      final incomingFolders = rawFolders
          .map((e) => LibraryFolder.fromJson(e as Map<String, dynamic>))
          .toList();

      // Merge Strategy:
      // Start with a copy of current folders.
      // Add incoming folders if they don't already exist (by ID/Account or Path).
      final mergedFolders = <LibraryFolder>[...libraryFolders];

      for (final inc in incomingFolders) {
        // Check if exists by unique ID + Account
        final existsById = mergedFolders.any((curr) => 
            curr.id == inc.id && curr.accountId == inc.accountId);
            
        if (!existsById) {
           // For local folders, also check by Path to avoid duplicates just because ID is different
           if (inc.accountId.isEmpty) {
              final existsByPath = mergedFolders.any((curr) => 
                  curr.accountId.isEmpty && 
                  curr.path.toLowerCase() == inc.path.toLowerCase()); // Windows insensitive
              
              if (!existsByPath) {
                 mergedFolders.add(inc);
              }
           } else {
              // Cloud folder: Add if ID didn't match
              mergedFolders.add(inc);
           }
        }
      }
      
      libraryFolders = mergedFolders;
      debugPrint('LibraryProvider: Final folder count: ${libraryFolders.length}');
      
      await _saveLibraryFolders();
      notifyListeners();
    }


    // 2. Import Items
    final rawItems = data['items'];
    if (rawItems != null) {
      List<MediaItem> cloudItems = [];
      
      if (rawItems is List) {
         // Already decoded List
         cloudItems = rawItems
             .map((e) => MediaItem.fromJson(e as Map<String, dynamic>))
             .toList();
      } else if (rawItems is String) {
         // Encoded String (Edge case if passed differently)
         cloudItems = MediaItem.listFromJson(rawItems);
      }
      
      debugPrint('LibraryProvider: Processing ${cloudItems.length} items from backup');
      
      final map = {for (var i in _allItems) i.id: i};
      for (final i in cloudItems) {
        // Overwrite local with cloud/backup version
        map[i.id] = i; 
      }
      _allItems = map.values.toList()
        ..sort((a, b) => b.lastModified.compareTo(a.lastModified));
      
      debugPrint('LibraryProvider: Final item count: ${_allItems.length}');
      
      await saveLibrary();
      notifyListeners();
      _configChangedController.add(null);
    }
  }
}

typedef _ProgressCallback = void Function(String path, int filesFound);
typedef _ItemsFoundCallback = Future<void> Function(List<MediaItem> items);

Future<void> _walkOneDriveFolder({
  required String token,
  required String folderId,
  required String currentPath,
  required List<MediaItem> out,
  required String accountPrefix,
  required LibraryFolder libraryFolder,
  _ProgressCallback? onProgress,
  _ItemsFoundCallback? onBatchFound,
}) async {
  final baseUrl = graph_auth.GraphAuthService.instance.graphBaseUrl;
  final url = Uri.parse(
      '$baseUrl/me/drive/items/$folderId/children');
  await _walkOneDrivePage(
    token: token,
    url: url,
    currentPath: currentPath,
    out: out,
    accountPrefix: accountPrefix,
    libraryFolder: libraryFolder,
    onProgress: onProgress,
    onBatchFound: onBatchFound,
  );
}

Future<void> _walkOneDrivePage({
  required String token,
  required Uri url,
  required String currentPath,
  required List<MediaItem> out,
  required String accountPrefix,
  required LibraryFolder libraryFolder,
  _ProgressCallback? onProgress,
  _ItemsFoundCallback? onBatchFound,
}) async {
  final res = await http.get(url, headers: {'Authorization': 'Bearer $token'});
  if (res.statusCode != 200) {
    throw Exception('Graph error: ${res.statusCode} ${res.body}');
  }

  final body = jsonDecode(res.body) as Map<String, dynamic>;
  final values = body['value'] as List<dynamic>? ?? <dynamic>[];

  final pageItems = <MediaItem>[];

  for (final raw in values) {
    final m = raw as Map<String, dynamic>;
    final isFolder = m['folder'] != null;
    final name = m['name'] as String? ?? '';
    final id = m['id'] as String? ?? '';
    final nextPath = currentPath == '/' ? '/$name' : '$currentPath/$name';

    onProgress?.call(nextPath, out.length);

    if (isFolder) {
      await _walkOneDriveFolder(
        token: token,
        folderId: id,
        currentPath: nextPath,
        out: out,
        accountPrefix: accountPrefix,
        libraryFolder: libraryFolder,
        onProgress: onProgress,
        onBatchFound: onBatchFound,
      );
      continue;
    }

    if (!_isVideo(name)) continue;

    final downloadUrl = m['@microsoft.graph.downloadUrl'] as String?;
    if (downloadUrl == null) continue;

    final lastModifiedRaw = m['lastModifiedDateTime'] as String?;
    final lastModified =
        DateTime.tryParse(lastModifiedRaw ?? '') ?? DateTime.now();
    final size = (m['size'] as num?)?.toInt() ?? 0;
    final parsed = FilenameParser.parse(name);
    final mediaType = _typeForFolder(libraryFolder, parsed.season != null || parsed.episode != null);
    final isAnime = libraryFolder.type == LibraryType.anime;
    final isAdult = libraryFolder.type == LibraryType.adult;
    final accountScopedFolderPath = '$accountPrefix$currentPath';
    final accountScopedFilePath = '$accountPrefix$nextPath';
    final showKey = mediaType == MediaType.tv
        ? '$accountPrefix:${currentPath.toLowerCase()}'
        : null;

    final item = MediaItem(
      id: 'onedrive_${libraryFolder.accountId}_$id',
      filePath: accountScopedFilePath,
      streamUrl: downloadUrl,
      fileName: name,
      folderPath: accountScopedFolderPath,
      sizeBytes: size,
      lastModified: lastModified,
      title: parsed.seriesTitle,
      year: parsed.year,
      type: mediaType,
      season: parsed.season,
      episode: parsed.episode,
      isAnime: isAnime,
      isAdult: isAdult,
      showKey: showKey,
    );

    out.add(item);
    pageItems.add(item);

    onProgress?.call(nextPath, out.length);
  }

  // Realtime update: Ingest items found so far on this page
  if (pageItems.isNotEmpty && onBatchFound != null) {
    await onBatchFound(pageItems);
  }

  final nextLink = body['@odata.nextLink'] as String?;
  if (nextLink != null) {
    await _walkOneDrivePage(
      token: token,
      url: Uri.parse(nextLink),
      currentPath: currentPath,
      out: out,
      accountPrefix: accountPrefix,
      libraryFolder: libraryFolder,
      onProgress: onProgress,
      onBatchFound: onBatchFound,
    );
  }
}

MediaType _typeForFolder(LibraryFolder folder, bool hasTvHints) {
  switch (folder.type) {
    case LibraryType.movies:
      return MediaType.movie;
    case LibraryType.tv:
    case LibraryType.anime:
      return MediaType.tv;
    case LibraryType.adult:
      return MediaType.scene;
    case LibraryType.other:
      return hasTvHints ? MediaType.tv : MediaType.movie;
  }
}

class _ScanRequest {
  final SendPort sendPort;
  final String path;
  final List<String>? keywords;
  _ScanRequest(this.sendPort, this.path, {this.keywords});
}

// Top-level function for background isolate
void _scanDirectoryInIsolate(_ScanRequest request) {
  final dir = PlatformDirectory(request.path);
  if (!dir.existsSync()) {
    request.sendPort.send(<MediaItem>[]);
    return;
  }

  final items = <MediaItem>[];
  int count = 0;

  try {
    request.sendPort.send('Scanning: ${request.path}...');

    final entities = dir.listSync(recursive: true, followLinks: false);
    request.sendPort.send('Found ${entities.length} files. Parsing...');

    for (final f in entities) {
      // Filter optimization
      if (request.keywords != null && request.keywords!.isNotEmpty) {
          final pLower = f.path.toLowerCase();
          // Match ALL keywords? Or ANY?
          // Title: "Star Wars" -> File: "Star.Wars.mkv"
          // "Star", "Wars" are both in path.
          // Title: "Avengers" -> "Avengers.mkv"
          // We require ALL keywords to be present to be a "Targeted Scan" for this item.
          bool match = true;
          for (final k in request.keywords!) {
            if (!pLower.contains(k)) {
              match = false;
              break;
            }
          }
          if (!match) continue;
      }

      if (f is PlatformFile && _isVideo(f.path)) {
        items.add(_parseFile(f));
        count++;
        if (count % 10 == 0) {
          request.sendPort.send('Found $count videos...');
        }
      }
    }
  } catch (e) {
    // Ignore access errors
  }

  request.sendPort.send(items);
}

// ... _isVideo, _parseFile

bool _isVideo(String path) {
  const exts = ['.mp4', '.mkv', '.avi', '.mov', '.webm'];
  final ext = p.extension(path).toLowerCase();
  return exts.contains(ext);
}

MediaItem _parseFile(PlatformFileSystemEntity f) {
  final stat = f.statSync();
  final filePath = f.path;
  final fileName = p.basename(filePath);
  final folder = p.dirname(filePath);
  final id = filePath.hashCode.toString();
  final lowerPath = filePath.toLowerCase();
  final animeHint = lowerPath.contains('anime');

  final parsed = FilenameParser.parse(fileName);
  final type = (parsed.season != null || parsed.episode != null || animeHint)
      ? MediaType.tv
      : MediaType.movie;

  // Use folder as the stable show key so all episodes in the same folder group together.
  final showKey = folder.toLowerCase();

  return MediaItem(
    id: id,
    filePath: filePath,
    fileName: fileName,
    folderPath: folder,
    sizeBytes: stat.size,
    lastModified: stat.modified,
    title: parsed.seriesTitle,
    year: parsed.year,
    type: type,
    season: parsed.season,
    episode: parsed.episode,
    isAnime: animeHint,
    showKey: showKey,
  );
}

MediaType _inferTypeFromPath(MediaItem item) {
  final fileName = p.basenameWithoutExtension(item.fileName).toLowerCase();
  final folderName = p.basename(item.folderPath).toLowerCase();
  final hasSeasonInFolder = RegExp(r'season[ _-]?\d{1,2}').hasMatch(folderName);
  final hasTvPattern = RegExp(r'[Ss]\d{1,2}[Ee]\d{1,3}').hasMatch(fileName) ||
      RegExp(r'(?:^|[\s._-])(?:ep(?:isode)?\s*)?\d{1,3}(?!\d)')
          .hasMatch(fileName) ||
      hasSeasonInFolder ||
      item.season != null ||
      item.episode != null;

  if (hasTvPattern) return MediaType.tv;
  return MediaType.movie;
}



String _seriesKey(MediaItem item) {
  if (item.showKey != null && item.showKey!.isNotEmpty) return item.showKey!;
  // Group by folder so all episodes in the same directory share a key.
  return item.folderPath.toLowerCase();
}

List<MediaItem> _groupShows(Iterable<MediaItem> source) {
  final map = <String, MediaItem>{};
  for (final item in source) {
    final key = _seriesKey(item);
    final episodeEntry = EpisodeItem(
      season: item.season ?? 1,
      episode: item.episode,
      filePath: item.filePath,
    );

    if (!map.containsKey(key)) {
      map[key] = item.copyWith(
        showKey: item.showKey ?? key,
        episodes: [episodeEntry],
      );
      continue;
    }

    final existing = map[key]!;
    final updatedEpisodes = [...existing.episodes, episodeEntry];
    map[key] = existing.copyWith(
      title: existing.title?.isNotEmpty == true ? existing.title : item.title,
      posterUrl: existing.posterUrl ?? item.posterUrl,
      backdropUrl: existing.backdropUrl ?? item.backdropUrl,
      overview: existing.overview ?? item.overview,
      rating: existing.rating ?? item.rating,
      runtimeMinutes: existing.runtimeMinutes ?? item.runtimeMinutes,
      genres: existing.genres.isNotEmpty ? existing.genres : item.genres,
      isAnime: existing.isAnime || item.isAnime,
      tmdbId: existing.tmdbId ?? item.tmdbId,
      showKey: existing.showKey ?? key,
      episodes: updatedEpisodes,
    );
  }
  return map.values.toList();
}

List<TvShowGroup> _groupShowsToGroups(Iterable<MediaItem> source) {
  final map = <String, List<MediaItem>>{};
  for (final item in source) {
    // One group per showKey; fallback to folder path.
    final key = (item.showKey != null && item.showKey!.isNotEmpty)
        ? item.showKey!
        : item.folderPath.toLowerCase();
    map.putIfAbsent(key, () => []);
    map[key]!.add(item);
  }

  return map.entries.map((entry) {
    final episodes = entry.value;
    episodes.sort((a, b) {
      final sa = a.season ?? 0;
      final sb = b.season ?? 0;
      final ea = a.episode ?? 0;
      final eb = b.episode ?? 0;
      return sa != sb ? sa.compareTo(sb) : ea.compareTo(eb);
    });
    final first = episodes.first;
    final parsedFirst = FilenameParser.parse(first.fileName);
    final title = parsedFirst.seriesTitle.isNotEmpty
        ? parsedFirst.seriesTitle
        : (first.title?.isNotEmpty == true ? first.title! : first.fileName);
    final poster = episodes
        .firstWhere((e) => e.posterUrl != null, orElse: () => first)
        .posterUrl;
    final backdrop = episodes
        .firstWhere((e) => e.backdropUrl != null, orElse: () => first)
        .backdropUrl;
    final year =
        episodes.firstWhere((e) => e.year != null, orElse: () => first).year ??
            parsedFirst.year;
    final isAnime = episodes.any((e) => e.isAnime);
    return TvShowGroup(
      title: title,
      isAnime: isAnime,
      showKey: entry.key,
      episodes: episodes,
      posterUrl: poster,
      backdropUrl: backdrop,
      year: year,
    );
  }).toList();
}
