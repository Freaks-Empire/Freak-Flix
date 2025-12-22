import 'dart:convert';
import '../utils/platform/platform.dart';
import 'dart:async';
import 'dart:isolate';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/library_folder.dart';
import '../models/media_item.dart';
import '../services/graph_auth_service.dart' as graph_auth;
import '../services/metadata_service.dart';
import 'settings_provider.dart';
import '../utils/filename_parser.dart';
import 'package:collection/collection.dart';
import 'package:archive/archive.dart';

class LibraryProvider extends ChangeNotifier {
  static const _prefsKey = 'library_v1';
  static const _libraryFoldersKey = 'library_folders_v1';

  final SettingsProvider settings;
  List<MediaItem> items = [];
  List<LibraryFolder> libraryFolders = [];
  bool isLoading = false;
  String? error;
  String scanningStatus = '';

  final _configChangedController = StreamController<void>.broadcast();
  Stream<void> get onConfigChanged => _configChangedController.stream;

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

    notifyListeners();
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

    if (totalToScan > 0) {
      scanningStatus =
          'Scanning $where  ($scannedCount / $totalToScan)… ${item.isEmpty ? '' : item}';
    } else {
      scanningStatus = 'Scanning $where… ${item.isEmpty ? '' : item}';
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

  LibraryProvider(this.settings);

  Future<void> loadLibrary() async {
    final prefs = await SharedPreferences.getInstance();
    final rawFolders = prefs.getString(_libraryFoldersKey);
    if (rawFolders != null) {
      try {
        libraryFolders = (jsonDecode(rawFolders) as List<dynamic>)
            .map((e) => LibraryFolder.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {
        libraryFolders = [];
      }
    }

    final raw = prefs.getString(_prefsKey);
    if (raw != null) {
      try {
        if (raw.trim().startsWith('[')) {
          // FAST PATH: Legacy uncompressed JSON
           items = MediaItem.listFromJson(raw);
        } else {
          // COMPRESSED PATH: Base64 -> GZip -> UTF8 -> JSON
          final bytes = base64Decode(raw);
          final decompressed = GZipDecoder().decodeBytes(bytes);
          final jsonStr = utf8.decode(decompressed);
          items = MediaItem.listFromJson(jsonStr);
        }
      } catch (e) {
        debugPrint('LibraryProvider load error: $e');
        // If load fails, keep empty items or maybe backup?
        // items = []; 
      }

      // Reclassify with updated rules (anime flag + tv/movie only).
      bool updated = false;
      for (var i = 0; i < items.length; i++) {
        final parsed = FilenameParser.parse(items[i].fileName);
        final inferredType = _inferTypeFromPath(items[i]);
        final inferredAnime = _inferAnimeFromPath(items[i]);
        final updatedItem = items[i].copyWith(
          title: parsed.seriesTitle.isNotEmpty
              ? parsed.seriesTitle
              : items[i].title,
          season: items[i].season ??
              parsed.season ??
              (parsed.episode != null ? 1 : null),
          episode: items[i].episode ?? parsed.episode,
          type: inferredType,
          isAnime: inferredAnime,
          year: items[i].year ?? parsed.year,
        );
        if (updatedItem != items[i]) {
          items[i] = updatedItem;
          updated = true;
        }
      }
      if (updated) await saveLibrary();
    }
    notifyListeners();
  }

  Future<void> saveLibrary() async {
    final prefs = await SharedPreferences.getInstance();
    // Compress to save space (QuotaExceededError on Web)
    final jsonStr = MediaItem.listToJson(items);
    final bytes = utf8.encode(jsonStr);
    final compressed = GZipEncoder().encode(bytes);
    if (compressed != null) {
       final base64Str = base64Encode(compressed);
       await prefs.setString(_prefsKey, base64Str);
    }
  }

  Future<void> _saveLibraryFolders() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _libraryFoldersKey,
      jsonEncode(libraryFolders.map((f) => f.toJson()).toList()),
    );
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
    _configChangedController.add(null);
    notifyListeners();
  }

  Future<void> removeLibraryFoldersForAccount(String accountId) async {
    libraryFolders.removeWhere((f) => f.accountId == accountId);
    await _saveLibraryFolders();
    _configChangedController.add(null);
    notifyListeners();
  }

  Future<void> rescanAll({
    required graph_auth.GraphAuthService auth,
    MetadataService? metadata,
  }) async {
    error = null;
    isLoading = true;
    notifyListeners();

    try {
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

  Future<void> refetchAllMetadata(MetadataService metadata) async {
    isLoading = true;
    scanningStatus = 'Refreshing metadata for all items...';
    notifyListeners();

    try {
      // Parallelize metadata enrichment with a concurrency limit
      const batchSize = 5;
      for (int i = 0; i < items.length; i += batchSize) {
        final batch = items.skip(i).take(batchSize).toList();
        scanningStatus =
            'Refreshing metadata (${i + 1}/${items.length}) ${batch.first.title ?? batch.first.fileName}';
        notifyListeners();
        
        final enrichedBatch = await Future.wait(batch.map((item) => metadata.enrich(item)));
        
        for (int j = 0; j < batch.length; j++) {
          final index = items.indexWhere((e) => e.id == batch[j].id);
          if (index != -1) {
            items[index] = enrichedBatch[j];
          }
        }
        notifyListeners();
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
    final map = {for (var i in items) i.filePath: i};
    for (final item in newItems) {
      map[item.filePath] = item;
    }
    items = map.values.toList()
      ..sort((a, b) => b.lastModified.compareTo(a.lastModified));
    notifyListeners();

    if (settings.autoFetchAfterScan && metadata != null) {
      // Parallelize metadata enrichment with a concurrency limit
      const batchSize = 5;
      for (int i = 0; i < items.length; i += batchSize) {
        final batch = items.skip(i).take(batchSize).toList();
        _setScanStatus('Fetching metadata: ${batch.first.title} ...');
        final enrichedBatch = await Future.wait(batch.map((item) => metadata.enrich(item)));
        for (int j = 0; j < batch.length; j++) {
          final idx = items.indexWhere((e) => e.id == batch[j].id);
          if (idx != -1) items[idx] = enrichedBatch[j];
        }
        notifyListeners();
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
    final normalized = folderPath.trim();

    final targetItems = items.where((item) {
      final path = item.folderPath.trim();
      if (path == normalized) return true;
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
          final index = items.indexWhere((e) => e.id == batch[j].id);
          if (index != -1) {
            items[index] = enrichedBatch[j];
          }
        }
        notifyListeners();
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

  /// Rescan a single OneDrive library folder and merge results into the library.
  Future<void> rescanOneDriveFolder({
    required graph_auth.GraphAuthService auth,
    required LibraryFolder folder,
    MetadataService? metadata,
  }) async {
    error = null;
    isLoading = true;
    final folderLabel = folder.path.isEmpty ? '/' : folder.path;
    _setScanStatus('Rescanning $folderLabel...');

    try {
      final account = auth.accounts.firstWhere(
        (a) => a.id == folder.accountId,
        orElse: () =>
        throw Exception('No account found for id ${folder.accountId}'),
      );
      final token = await auth.getFreshAccessToken(account.id);
      final normalizedPath = folder.path.isEmpty ? '/' : folder.path;
      final collected = <MediaItem>[];
      final prefix = 'onedrive:${folder.accountId}';

      await _walkOneDriveFolder(
        token: token,
        folderId: folder.id,
        currentPath: normalizedPath,
        out: collected,
        accountPrefix: prefix,
        libraryFolder: folder,
        onProgress: (path, count) {
          _setScanStatus('OneDrive · $path ($count files)');
        },
      );

        _setScanStatus(
          'Merging ${collected.length} items from $folderLabel...');
      await _ingestItems(collected, metadata);
    } catch (e) {
      error = 'Rescan failed for $folderLabel: $e';
    } finally {
      isLoading = false;
      _setScanStatus('');
      await saveLibrary();
	  _configChangedController.add(null);
    }
  }

  Future<void> clear() async {
    items = [];
    await saveLibrary();
    notifyListeners();
  }

  Future<void> updateItem(MediaItem updated) async {
    final index = items.indexWhere((i) => i.id == updated.id);
    if (index == -1) return;
    items[index] = updated;
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
      items.where((i) => i.lastPositionSeconds > 0 && !i.isWatched).toList();

  List<MediaItem> get recentlyAdded {
    final sorted = [...items]
      ..sort((a, b) => b.lastModified.compareTo(a.lastModified));
    return sorted.take(20).toList();
  }

  List<MediaItem> get topRated {
    final sorted = [...items]
      ..sort((a, b) => (b.rating ?? 0).compareTo(a.rating ?? 0));
    return sorted.take(20).toList();
  }

  Future<void> scanLibraryFolder({
    required graph_auth.GraphAuthService auth,
    required LibraryFolder folder,
    MetadataService? metadata,
  }) async {
    error = null;
    isLoading = true;
    _setScanStatus('Scanning ${folder.path.isEmpty ? '/' : folder.path}...');
    notifyListeners();

    try {
      final account = auth.accounts.firstWhere(
        (a) => a.id == folder.accountId,
        orElse: () =>
        throw Exception('No account found for id ${folder.accountId}'),
      );
      final token = await auth.getFreshAccessToken(account.id);
      final normalizedPath = folder.path.isEmpty ? '/' : folder.path;
      final collected = <MediaItem>[];
      final prefix = 'onedrive:${folder.accountId}';
      await _walkOneDriveFolder(
        token: token,
        folderId: folder.id,
        currentPath: normalizedPath,
        out: collected,
        accountPrefix: prefix,
        libraryFolder: folder,
        onProgress: (path, count) {
          _setScanStatus('OneDrive · $path ($count files)');
        },
      );

      _setScanStatus('Found ${collected.length} videos. Ingesting...');
      await _ingestItems(collected, metadata);
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      _setScanStatus('');
      await saveLibrary();
	  _configChangedController.add(null);
    }
  }

  Future<void> scanOneDriveFolder({
    required graph_auth.GraphAuthService auth,
    required String folderId,
    required String folderPath,
    MetadataService? metadata,
  }) async {
    final accountId = auth.activeAccountId;
    if (accountId == null) {
      error = 'No active OneDrive account';
      notifyListeners();
      return;
    }

    final folder = LibraryFolder(
      id: folderId,
      path: folderPath,
      accountId: accountId,
      type: LibraryType.other,
    );
    await scanLibraryFolder(auth: auth, folder: folder, metadata: metadata);
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
          await _scanLocalFolder(folder.path, metadata: metadata, keywords: keywords);
        }
      }
    }
  }

  Future<void> _scanLocalFolder(String path, {MetadataService? metadata, List<String>? keywords}) async {
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
      'items': MediaItem.listToJson(items),
    };
  }

  ({int count, int sizeBytes}) getFolderStats(LibraryFolder folder) {
    // Defines which items belong to this folder
    final relevant = items.where((i) {
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
    final rawFolders = data['folders'] as List<dynamic>?;
    if (rawFolders != null) {
      final newFolders = rawFolders
          .map((e) => LibraryFolder.fromJson(e as Map<String, dynamic>))
          .toList();
      
      // Merge logic: For now, simple replace or merge? 
      // User expects sync. Let's try to merge missing ones or replace all?
      // Replacing entirely might lose local-only folders (like "Local file picker"?).
      // But libraryFolders stores specific configurations.
      // Let's replace OneDrive folders but keep others? Or just simple replace.
      // Based on app structure, having identical setup across devices is desired.
      // Let's replace for now, but safer to merge unique IDs?
      
      // Let's do a merge based on ID:
      for (final f in newFolders) {
         final exists = libraryFolders.any((old) => old.id == f.id && old.accountId == f.accountId);
         if (!exists) {
           libraryFolders.add(f);
         }
      }
      // What about deletions? If user deleted on Web, should we delete on Windows?
      // Sync usually implies "current state". If we only add, deletions never sync.
      // Let's Replace. But wait, local folders (not OneDrive) might vary by device path (C:\ vs /home/).
      // OneDrive folders use ID so they are cross-platform safe.
      // Filter: Keep local folders, replace/sync OneDrive folders.
      
      final localOnly = libraryFolders.where((f) => f.accountId.isEmpty).toList();
      final cloudFolders = newFolders.where((f) => f.accountId.isNotEmpty).toList();
      
      libraryFolders = [...localOnly, ...cloudFolders];
      
      await _saveLibraryFolders();
      notifyListeners();
      
      // Optional: Auto-scan new folders? 
      // Maybe not immediately to avoid blasting network on startup. User can click "Rescan".
      // But user expects to see items. 
      // We'll leave auto-scan for now, user can click "Rescan".
    }


    // Import Items
    final rawItems = data['items'];
    if (rawItems != null) {
      final cloudItems = MediaItem.listFromJson(rawItems);
      
      final map = {for (var i in items) i.id: i};
      for (final i in cloudItems) {
        // Overwrite local with cloud version to ensure metadata sync
        map[i.id] = i; 
      }
      items = map.values.toList()
        ..sort((a, b) => b.lastModified.compareTo(a.lastModified));
      
      await saveLibrary();
      notifyListeners();
    }
  }
}

typedef _ProgressCallback = void Function(String path, int filesFound);

Future<void> _walkOneDriveFolder({
  required String token,
  required String folderId,
  required String currentPath,
  required List<MediaItem> out,
  required String accountPrefix,
  required LibraryFolder libraryFolder,
  _ProgressCallback? onProgress,
}) async {
  final url = Uri.parse(
      'https://graph.microsoft.com/v1.0/me/drive/items/$folderId/children');
  await _walkOneDrivePage(
    token: token,
    url: url,
    currentPath: currentPath,
    out: out,
    accountPrefix: accountPrefix,
    libraryFolder: libraryFolder,
    onProgress: onProgress,
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
}) async {
  final res = await http.get(url, headers: {'Authorization': 'Bearer $token'});
  if (res.statusCode != 200) {
    throw Exception('Graph error: ${res.statusCode} ${res.body}');
  }

  final body = jsonDecode(res.body) as Map<String, dynamic>;
  final values = body['value'] as List<dynamic>? ?? <dynamic>[];

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
    final animeHint = nextPath.toLowerCase().contains('anime');
    final hasTvHints =
        parsed.season != null || parsed.episode != null || animeHint;
    final mediaType = _typeForFolder(libraryFolder, hasTvHints);
    final isAnime = libraryFolder.type == LibraryType.anime || animeHint;
    final accountScopedFolderPath = '$accountPrefix$currentPath';
    final accountScopedFilePath = '$accountPrefix$nextPath';
    final showKey = mediaType == MediaType.tv
        ? '$accountPrefix:${currentPath.toLowerCase()}'
        : null;

    out.add(MediaItem(
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
      showKey: showKey,
    ));

    onProgress?.call(nextPath, out.length);
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
      return MediaType.movie;
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

bool _inferAnimeFromPath(MediaItem item) {
  return item.isAnime || item.filePath.toLowerCase().contains('anime');
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
