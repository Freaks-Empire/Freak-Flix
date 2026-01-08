/// lib/providers/library_provider.dart
import 'dart:convert';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import '../utils/platform/platform.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'dart:async';
import 'dart:isolate';
import 'dart:io';
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
import '../services/metadata_service.dart';
import '../services/sidecar_service.dart';
import '../services/task_queue_service.dart';

import 'settings_provider.dart';
import '../utils/filename_parser.dart';
import 'package:collection/collection.dart';
// Removed unused 'archive' and 'tmdb_discover_service' imports

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
  
  List<MediaItem> get continueWatchingItems {
    return _filteredItems.where((item) {
      final pos = item.lastPositionSeconds;
      
      // Basic check: has position, not fully watched
      if (pos <= 0) return false;
      if (item.isWatched) return false;
      
      return true;
    }).toList()
      ..sort((a, b) => b.lastModified.compareTo(a.lastModified)); 
  }

  List<MediaItem> get historyItems {
    return _filteredItems.where((item) {
      // History includes anything with progress OR marked as watched
      return item.lastPositionSeconds > 0 || item.isWatched;
    }).toList()
      ..sort((a, b) => b.lastModified.compareTo(a.lastModified));
  }

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
      
      final allowedPaths = libraryFolders
          .where((f) => allowed.contains(f.id))
          .map((f) => f.path.toLowerCase())
          .toList();

      if (allowedPaths.isEmpty && allowed.isNotEmpty) {
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
    scanningStatus = 'Cancellingâ€¦';
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
      statusMsg = 'Scanning $where  ($scannedCount / $totalToScan)â€¦ ${item.isEmpty ? '' : item}';
    } else {
      statusMsg = 'Scanning $whereâ€¦ ${item.isEmpty ? '' : item}';
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
        
        LibraryFolder? parentFolder;
        
        // Check Cloud Folders
        if (item.id.startsWith('onedrive_')) {
             parentFolder = libraryFolders.firstWhereOrNull((f) {
                 if (f.accountId.isEmpty) return false;
                 final fPath = f.path.startsWith('/') ? f.path : '/${f.path}';
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
            
            if (parentFolder.type == LibraryType.movies) {
               newType = MediaType.movie;
            } else if (parentFolder.type == LibraryType.tv || parentFolder.type == LibraryType.anime) {
               newType = MediaType.tv;
            } else if (parentFolder.type == LibraryType.adult) {
               newType = MediaType.scene;
            } else {
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

    final bool isCloud = folder.accountId.isNotEmpty;
    if (isCloud) {
       final prefix = 'onedrive:${folder.accountId}${folder.path.isEmpty ? '/' : folder.path}';
       _allItems.removeWhere((i) {
         if (!i.id.startsWith('onedrive_${folder.accountId}_')) return false;
         return i.folderPath.startsWith(prefix);
       });
    } else {
       _allItems.removeWhere((i) => i.filePath.startsWith(folder.path));
    }

    _configChangedController.add(null);
    notifyListeners();
    await saveLibrary();
  }

  Future<void> removeLibraryFoldersForAccount(String accountId) async {
    libraryFolders.removeWhere((f) => f.accountId == accountId);
    await _saveLibraryFolders();
    
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
      _pruneOrphans();

      for (final folder in libraryFolders) {
        if (folder.accountId.isNotEmpty) {
          await rescanOneDriveFolder(
            auth: auth,
            folder: folder,
            metadata: metadata,
          );
        } else {
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
      if (item.id.startsWith('onedrive_')) {
         return !libraryFolders.any((f) {
             if (f.accountId.isEmpty) return false;
             final prefix = 'onedrive:${f.accountId}${f.path.isEmpty ? '/' : f.path}';
             return item.folderPath.startsWith(prefix);
         });
      }
      
      return !libraryFolders.any((f) {
          if (f.accountId.isNotEmpty) return false;
          return item.filePath.toLowerCase().startsWith(f.path.toLowerCase());
      });
    });
    
    if (_allItems.length != before) {
        debugPrint('LibraryProvider: Pruned ${before - _allItems.length} orphan items.');
        notifyListeners();
    }
  }

  Future<void> refetchAllMetadata(MetadataService metadata, {bool onlyMissing = false}) async {
    isLoading = true;
    scanningStatus = 'Refreshing metadata...';
    notifyListeners();

    try {
      final itemsToProcess = onlyMissing 
          ? _allItems.where((i) => i.tmdbId == null && i.anilistId == null && !i.isAdult).toList()
          : _allItems;

      if (itemsToProcess.isEmpty) {
        scanningStatus = 'No missing metadata found.';
        notifyListeners();
        return;
      }

      const batchSize = 5;
      for (int i = 0; i < itemsToProcess.length; i += batchSize) {
        final batch = itemsToProcess.skip(i).take(batchSize).toList();
        scanningStatus =
            'Refreshing metadata (${i + 1}/${itemsToProcess.length}) ${batch.first.title ?? batch.first.fileName}';
        notifyListeners();
        
        final enrichedBatch = await Future.wait(batch.map((item) => metadata.enrich(item)));
        
        for (int j = 0; j < batch.length; j++) {
          final enriched = enrichedBatch[j];
          final index = _allItems.indexWhere((e) => e.id == enriched.id);
          if (index != -1) {
            _allItems[index] = enriched;
          }
        }
        notifyListeners();

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
        
        final exists = libraryFolders.any((f) => f.path == path);
        if (!exists) {
            await addLibraryFolder(LibraryFolder(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                path: path,
                accountId: '',
                type: LibraryType.other
            ));
        }

        await _scanLocalFolder(path, metadata: metadata);
      }
    } catch (e) {
      error = e.toString();
    } finally {
      finishScan();
      await saveLibrary(); 
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
    final existingPaths = {for (var i in _allItems) i.filePath: i.filePath};
    final itemsToEnrich = <MediaItem>[];
    
    for (final item in newItems) {
      if (!existingPaths.containsKey(item.filePath)) {
        itemsToEnrich.add(item);
      }
    }

    final map = {for (var i in _allItems) i.filePath: i};
    for (final newItem in newItems) {
      if (!map.containsKey(newItem.filePath)) {
         map[newItem.filePath] = newItem;
      } else {
         final existing = map[newItem.filePath]!;
         if (existing.isAdult != newItem.isAdult || 
             existing.isAnime != newItem.isAnime ||
             (existing.type != newItem.type && newItem.type != MediaType.unknown)) {
             
             map[newItem.filePath] = existing.copyWith(
               isAdult: newItem.isAdult,
               isAnime: newItem.isAnime,
               type: newItem.type != MediaType.unknown ? newItem.type : existing.type,
             );
         }
      }
    }
    _allItems = map.values.toList()
      ..sort((a, b) => b.lastModified.compareTo(a.lastModified));
    
    _rebuildFilteredItems(); 
    notifyListeners();

    if (settings.autoFetchAfterScan && metadata != null && itemsToEnrich.isNotEmpty) {
      const batchSize = 5;
      for (int i = 0; i < itemsToEnrich.length; i += batchSize) {
        final batch = itemsToEnrich.skip(i).take(batchSize).toList();
        _setScanStatus('Fetching metadata: ${batch.first.title ?? batch.first.fileName} ...');
        final enrichedBatch = await Future.wait(batch.map((item) => metadata.enrich(item)));
        
        for (int j = 0; j < batch.length; j++) {
          final enriched = enrichedBatch[j];
          final index = _allItems.indexWhere((e) => e.id == enriched.id);
          if (index != -1) _allItems[index] = enriched;
          
           _queuePersistentMetadata(enriched);
        }

        notifyListeners();

        if ((i + batch.length) % 25 == 0) {
           await saveLibrary();
        }
      }
    }
  }


  void enforceSidecarsAndNaming() {
    _setScanStatus('Enforcing metadata & naming rules...');
    notifyListeners();
    
    int processed = 0;
    for (final item in _allItems) {
       _queuePersistentMetadata(item);
       processed++;
       if (processed % 50 == 0) notifyListeners();
    }
    
    Future.delayed(const Duration(seconds: 1), () {
        _setScanStatus('');
        notifyListeners();
    });
  }

  void _queuePersistentMetadata(MediaItem enriched) {
    if (!enriched.id.startsWith('onedrive_')) return;
    
    final hasMeta = enriched.tmdbId != null || enriched.anilistId != null || enriched.type == MediaType.scene;
    if (!hasMeta) return;

    final parts = enriched.id.split('_');
    if (parts.length < 3) return;
    
    final accountId = parts[1];
    final itemId = parts[2];

    final prefix = 'onedrive:$accountId';
    if (enriched.folderPath.startsWith(prefix)) {
        var relPath = enriched.folderPath.substring(prefix.length);
        while (relPath.startsWith('/')) {
           relPath = relPath.substring(1);
        }
        final parentRef = relPath.isEmpty ? 'root' : 'root:/$relPath';
        
        final nfoName = '${p.basenameWithoutExtension(enriched.fileName)}.nfo';
        
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

    if (enriched.type == MediaType.scene && enriched.title != null) {
        final yearPart = enriched.year != null ? ' (${enriched.year})' : '';
        final ext = p.extension(enriched.fileName);
        final expectedName = '${enriched.title}$yearPart$ext';
        
        final safeName = expectedName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '');
        
        if (enriched.fileName != safeName) {
            TaskQueueService.instance.run('Renaming: ${enriched.fileName} -> $safeName', () async {
                final ok = await graph_auth.GraphAuthService.instance.renameItem(
                    accountId: accountId,
                    itemId: itemId,
                    newName: safeName
                );
                if (ok) {
                  final idx = _allItems.indexWhere((e) => e.id == enriched.id);
                  if (idx != -1) {
                      _allItems[idx] = enriched.copyWith(fileName: safeName);
                      notifyListeners();
                  }
                }
            });
        }
    }
  }

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
      if (path == normalized || path == '$normalized/') return true;
      return path.startsWith('$normalized/');
    }).toList();

    await _refetchMetadataForItems(targetItems, metadata, label);
  }

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

        if ((i + batch.length) % 25 == 0) {
           await saveLibrary();
        }
      }

      await saveLibrary();

      scanningStatus = 'Finished refreshing $label metadata.';
      notifyListeners();
    } finally {
      isLoading = false;
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
      
      final foundItems = <MediaItem>[];
      await _walkOneDriveFolder(
        token: token, 
        url: requestUrl, 
      baseFolderPath: 'onedrive:${account.id}${path.isEmpty ? '' : '/$path'}',
      accountId: account.id,
      collectedItems: foundItems,
    );
      
      
      await _ingestItems(foundItems, metadata);



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
    required List<MediaItem> collectedItems,
  }) async {
    if (_cancelScanRequested) return;
    
    String? nextLink = url;
    
    while (nextLink != null && !_cancelScanRequested) {
      try {
        final uri = Uri.parse(nextLink);
        
        Uri finalUri = uri;
        if (kIsWeb && uri.host == 'graph.microsoft.com') {
             final path = uri.path; 
             final newPath = path.replaceFirst('/v1.0', graph_auth.GraphAuthService.instance.graphBaseUrl);
             finalUri = Uri(path: newPath, query: uri.query);
        }

        final response = await http.get(finalUri, headers: {'Authorization': 'Bearer $token'});
        if (response.statusCode != 200) {
           debugPrint('Graph Walk Error: ${response.statusCode} - ${response.body}');
           return;
        }

        final map = jsonDecode(response.body);
        final List<dynamic> value = map['value'] ?? [];
        
        final nfoMap = <String, Map<String, dynamic>>{};
        for (final item in value) {
          final name = item['name'] as String;
          if (name.toLowerCase().endsWith('.nfo')) {
            nfoMap[name.toLowerCase()] = item;
          }
        }

        for (final item in value) {
            if (_cancelScanRequested) break;
            
            final name = item['name'] as String;
            final isFolder = item['folder'] != null;
            final isFile = item['file'] != null;
            final id = item['id'] as String;
            
            if (isFolder) {
               String childUrl = 'https://graph.microsoft.com/v1.0/me/drive/items/$id/children';
               
               await _walkOneDriveFolder(
                 token: token,
                 url: childUrl,
                 baseFolderPath: '$baseFolderPath/$name',
                 accountId: accountId,
                 collectedItems: collectedItems,
               );
            } else if (isFile) {
               if (_isVideo(name)) {
                  _setScanStatus('Found: $name');
                  var newItem = _createMediaItemFromGraph(item, accountId, baseFolderPath);
                  
                  final nfoName = '${p.basenameWithoutExtension(name)}.nfo'.toLowerCase();
                  if (nfoMap.containsKey(nfoName)) {
                     final nfoItem = nfoMap[nfoName]!;
                     final downloadUrl = nfoItem['@microsoft.graph.downloadUrl'] as String?;
                     if (downloadUrl != null) {
                        try {
                           final nfoRes = await http.get(Uri.parse(downloadUrl));
                           if (nfoRes.statusCode == 200) {
                               final parsedNfo = SidecarService.parseNfo(nfoRes.body);
                               if (parsedNfo != null) {
                                  newItem = newItem.copyWith(
                                     stashId: parsedNfo['stashId'],
                                     tmdbId: parsedNfo['tmdbId'],
                                     anilistId: parsedNfo['anilistId'],
                                     title: parsedNfo['title'] ?? newItem.title,
                                     year: parsedNfo['year'] ?? newItem.year,
                                  );
                               }
                           }
                        } catch (e) {
                           debugPrint('NFO fetch failed for $name: $e');
                        }
                     }
                  }

                  final parentFolder = libraryFolders.firstWhereOrNull((f) {
                      if (f.accountId != accountId) return false;
                      final fPath = f.path.startsWith('/') ? f.path : '/${f.path}';
                      final prefix = 'onedrive:${f.accountId}${fPath == '/' ? '/' : fPath}';
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
                       if (parentFolder.type == LibraryType.anime) initialIsAnime = true;
                  }

                  final adjustedItem = newItem.copyWith(
                      isAdult: initialIsAdult,
                      isAnime: initialIsAnime,
                      type: initialType
                  );

                  await _ingestItems([adjustedItem], null);
                  collectedItems.add(adjustedItem);
                  
                  scannedCount++;
                  if (scannedCount % 50 == 0) await saveLibrary();
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
    
    final parsed = FilenameParser.parse(name);
    
    String? overview;
    if (parsed.studio != null) {
      overview = 'Studio: ${parsed.studio}\n';
    }

    List<CastMember> cast = [];
    if (parsed.performers.isNotEmpty) {
      cast = parsed.performers.map<CastMember>((p) => CastMember(name: p, id: '', character: 'Performer', source: CastSource.stashDb)).toList();
    }
    final itemId = 'onedrive_${accountId}_$id';
    
    return MediaItem(
      id: itemId,
      filePath: name, 
      fileName: name,
      folderPath: folderPath, 
      sizeBytes: size,
      lastModified: lastMod,
      title: parsed.seriesTitle,
      year: parsed.year, 
      overview: overview,
      cast: cast,
      isAdult: parsed.studio != null, 
      type: parsed.studio != null ? MediaType.scene : MediaType.unknown,
    );
  }

  bool _isVideo(String path) {
    final ext = p.extension(path).toLowerCase();
    return const ['.mp4', '.mkv', '.avi', '.mov', '.webm', '.m4v'].contains(ext);
  }

  MediaItem _parseFile(PlatformFile f) {
    final filePath = f.path;
    final fileName = p.basename(filePath);
    final folder = filePath.isNotEmpty ? p.dirname(filePath) : '';
    final id = filePath.isNotEmpty ? filePath.hashCode.toString() : fileName.hashCode.toString();
    
    final size = f.statSync().size;
    
    final parsed = FilenameParser.parse(fileName);
    final animeHint = folder.toLowerCase().contains('anime');

    String? overview;
    if (parsed.studio != null) {
      overview = 'Studio: ${parsed.studio}\n';
    }

    List<CastMember> cast = [];
    if (parsed.performers.isNotEmpty) {
      cast = parsed.performers.map<CastMember>((p) => CastMember(name: p, id: '', character: 'Performer', source: CastSource.stashDb)).toList();
    }
    
    final type = parsed.studio != null ? MediaType.scene : MediaType.movie; 
    
    return MediaItem(
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

  List<MediaItem> getRecommendedLocal(DiscoverType type) {
    if (items.isEmpty) return [];

    var pool = items.where((i) => !i.isWatched && !i.isAdult);

    switch (type) {
      case DiscoverType.movie:
        pool = pool.where((i) => i.type == MediaType.movie);
        break;
      case DiscoverType.tv:
        pool = pool.where((i) => i.type == MediaType.tv && !i.isAnime);
        break;
      case DiscoverType.anime:
        pool = pool.where((i) => i.isAnime);
        break;
      case DiscoverType.all:
      default:
        break;
    }
    
    final uniqueList = <MediaItem>[];
    final seenShows = <String>{};

    for (final item in pool) {
      if (item.type == MediaType.movie) {
        uniqueList.add(item);
      } else {
        final key = item.showKey ?? item.tmdbId?.toString() ?? item.title ?? item.folderPath;
        if (!seenShows.contains(key)) {
          seenShows.add(key);
          uniqueList.add(item);
        }
      }
    }

    uniqueList.shuffle();
    
    return uniqueList.take(20).toList();
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

  Future<void> rescanSingleItem(MediaItem item, MetadataService metadata) async {
      await _refetchMetadataForItems([item], metadata, 'Single Item');
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
       }
    }
    return map;
  }

  ({int count, int sizeBytes}) getFolderStats(LibraryFolder folder) {
    final relevant = _allItems.where((i) {
      if (folder.accountId.isNotEmpty) {
        final rootPath = 'onedrive:${folder.accountId}${folder.path.isEmpty ? '/' : folder.path}';
        return i.folderPath.startsWith(rootPath);
      } else {
        return i.filePath.startsWith(folder.path);
      }
    });

    final count = relevant.length;
    final size = relevant.fold<int>(0, (sum, item) => sum + item.sizeBytes);
    return (count: count, sizeBytes: size);
  }

  Future<void> importState(Map<String, dynamic> data) async {
    debugPrint('LibraryProvider: Importing library state...');
    
    final rawFolders = data['folders'] as List<dynamic>?;
    if (rawFolders != null) {
      debugPrint('LibraryProvider: Processing ${rawFolders.length} folders from backup');
      final incomingFolders = rawFolders
          .map((e) => LibraryFolder.fromJson(e as Map<String, dynamic>))
          .toList();

      final mergedFolders = <LibraryFolder>[...libraryFolders];

      for (final inc in incomingFolders) {
        final existsById = mergedFolders.any((curr) => 
            curr.id == inc.id && curr.accountId == inc.accountId);
            
        if (!existsById) {
           if (inc.accountId.isEmpty) {
              final existsByPath = mergedFolders.any((curr) => 
                  curr.accountId.isEmpty && 
                  curr.path.toLowerCase() == inc.path.toLowerCase()); 
              
              if (!existsByPath) {
                 mergedFolders.add(inc);
              }
           } else {
              mergedFolders.add(inc);
           }
        }
      }
      
      libraryFolders = mergedFolders;
      debugPrint('LibraryProvider: Final folder count: ${libraryFolders.length}');
      
      await _saveLibraryFolders();
      notifyListeners();
    }


    final rawItems = data['items'];
    if (rawItems != null) {
      List<MediaItem> cloudItems = [];
      
      if (rawItems is List) {
         cloudItems = rawItems
             .map((e) => MediaItem.fromJson(e as Map<String, dynamic>))
             .toList();
      } else if (rawItems is String) {
         cloudItems = MediaItem.listFromJson(rawItems);
      }
      
      debugPrint('LibraryProvider: Processing ${cloudItems.length} items from backup');
      
      final map = {for (var i in _allItems) i.id: i};
      for (final i in cloudItems) {
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

class _ScanRequest {
  final SendPort sendPort;
  final String path;
  final List<String>? keywords;

  _ScanRequest(this.sendPort, this.path, {this.keywords});
}

void _scanDirectoryInIsolate(_ScanRequest request) {
  final root = request.path;
  final keywords = request.keywords;
  final sendPort = request.sendPort;

  try {
    final dir = PlatformDirectory(root); 
    if (!dir.existsSync()) {
      sendPort.send(<MediaItem>[]);
      return;
    }

    final entities = dir.listSync(recursive: true);
    final items = <MediaItem>[];
    
    bool isVideo(String path) {
       final ext = p.extension(path).toLowerCase();
       return const ['.mp4', '.mkv', '.avi', '.mov', '.webm', '.m4v'].contains(ext);
    }
    
    final nfoMap = <String, File>{};
    for (final e in entities) {
        if (e is File && p.extension(e.path).toLowerCase() == '.nfo') {
            final key = p.withoutExtension(e.path).toLowerCase();
            nfoMap[key] = e;
        }
    }

    for (final e in entities) {
        final pathStr = e.path;
        if (e is File && isVideo(pathStr)) {
            if (keywords != null && keywords.isNotEmpty) {
                 final name = p.basename(pathStr).toLowerCase();
                 if (!keywords.any((k) => name.contains(k))) continue;
            }
         
             final filePath = pathStr;
             final fileName = p.basename(filePath);
             final stat = e.statSync();
             
             final parsed = FilenameParser.parse(fileName);
             
             final nfoKey = p.withoutExtension(filePath).toLowerCase();
             String? stashId;
             int? tmdbId;
             int? anilistId;
             String? nfoTitle;
             int? nfoYear;
             
             if (nfoMap.containsKey(nfoKey)) {
                try {
                   final content = nfoMap[nfoKey]!.readAsStringSync();
                   final parsedNfo = SidecarService.parseNfo(content);
                   if (parsedNfo != null) {
                      stashId = parsedNfo['stashId'];
                      tmdbId = parsedNfo['tmdbId'];
                      anilistId = parsedNfo['anilistId'];
                      nfoTitle = parsedNfo['title'];
                      nfoYear = parsedNfo['year'];
                   }
                } catch (_) {}
             }

             items.add(MediaItem(
                id: filePath.hashCode.toString(),
                filePath: filePath,
                fileName: fileName,
                folderPath: p.dirname(filePath),
                sizeBytes: stat.size,
                lastModified: stat.modified,
                title: nfoTitle ?? parsed.seriesTitle,
                year: nfoYear ?? parsed.year,
                type: parsed.studio != null ? MediaType.scene : MediaType.movie, 
                season: parsed.season,
                episode: parsed.episode,
                isAnime: filePath.toLowerCase().contains('anime'),
                showKey: p.dirname(filePath).toLowerCase(),
                isAdult: parsed.studio != null,
                stashId: stashId,
                tmdbId: tmdbId,
                anilistId: anilistId,
             ));
        }
    }
    sendPort.send(items);
  } catch (e) {
    debugPrint('Isolate Scan Error: $e');
    sendPort.send(<MediaItem>[]); 
  }
}
