import 'dart:convert';
import 'dart:io';
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

class LibraryProvider extends ChangeNotifier {
  static const _prefsKey = 'library_v1';
  static const _libraryFoldersKey = 'library_folders_v1';

  final SettingsProvider settings;
  List<MediaItem> items = [];
  List<LibraryFolder> libraryFolders = [];
  bool isLoading = false;
  String? error;
  String scanningStatus = '';

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
      items = MediaItem.listFromJson(raw);

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
    await prefs.setString(_prefsKey, MediaItem.listToJson(items));
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
    notifyListeners();
  }

  Future<void> removeLibraryFolder(LibraryFolder folder) async {
    libraryFolders.removeWhere(
      (f) => f.id == folder.id && f.accountId == folder.accountId,
    );
    await _saveLibraryFolders();
    notifyListeners();
  }

  Future<void> removeLibraryFoldersForAccount(String accountId) async {
    libraryFolders.removeWhere((f) => f.accountId == accountId);
    await _saveLibraryFolders();
    notifyListeners();
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
        if (result == null) {
          return;
        }

        final files = result.paths.whereType<String>().map(File.new).toList();
        reportScanProgress(
          scanned: 0,
          total: files.length,
          sourceLabel: 'Local files',
          currentItem: 'Preparing files',
        );
        await _ingestFiles(files, metadata);
      } else {
        final path = await FilePicker.platform.getDirectoryPath();
        if (path == null) {
          return;
        }
        final sourceLabel = 'Local · ${p.basename(path)}';
        settings.setLastFolder(path);

        // Spawn isolate for streaming background scanning
        final port = ReceivePort();
        await Isolate.spawn(
          _scanDirectoryInIsolate,
          _ScanRequest(port.sendPort, path),
        );

        final scannedItems = <MediaItem>[];
        await for (final message in port) {
          if (message is String) {
            reportScanProgress(sourceLabel: sourceLabel, currentItem: message);
          } else if (message is List<MediaItem>) {
            scannedItems.addAll(message);
            port.close();
            break; // Done
          }
        }

        reportScanProgress(
            sourceLabel: sourceLabel, currentItem: 'Finalizing...');
        await _ingestItems(scannedItems, metadata);
      }
    } catch (e) {
      error = e.toString();
    } finally {
      finishScan();
      await saveLibrary();
    }
  }

  Future<void> _ingestFiles(List<File> files, MetadataService? metadata) async {
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
      for (int i = 0; i < items.length; i++) {
        _setScanStatus('Fetching metadata: ${items[i].title}');
        final enriched = await metadata.enrich(items[i]);
        items[i] = enriched;
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
      for (var i = 0; i < targetItems.length; i++) {
        final item = targetItems[i];
        scanningStatus =
            '[$label] (${i + 1}/${targetItems.length}) ${item.title ?? item.fileName}';
        notifyListeners();

        final enriched = await metadata.enrich(item);
        final index = items.indexWhere((e) => e.id == item.id);
        if (index != -1) {
          items[index] = enriched;
        }
      }

      await saveLibrary();

      scanningStatus = 'Finished refreshing $label metadata.';
      notifyListeners();
    } finally {
      isLoading = false;
      // Let the finished message linger briefly; UI may clear it after delay.
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
      items.where((i) => i.type == MediaType.movie).toList();

  // Group TV/anime by showKey and aggregate episodes under one show card.
  // TV tab excludes anime; Anime tab shows only anime.
  List<MediaItem> get tv =>
      _groupShows(items.where((i) => i.type == MediaType.tv && !i.isAnime));

  List<MediaItem> get anime =>
      _groupShows(items.where((i) => i.type == MediaType.tv && i.isAnime));

  List<TvShowGroup> get groupedTvShows => _groupShowsToGroups(
      items.where((i) => i.type == MediaType.tv && !i.isAnime));

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
      final token = account.accessToken;
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
    case LibraryType.other:
    default:
      return hasTvHints ? MediaType.tv : MediaType.movie;
  }
}

class _ScanRequest {
  final SendPort sendPort;
  final String path;
  _ScanRequest(this.sendPort, this.path);
}

// Top-level function for background isolate
void _scanDirectoryInIsolate(_ScanRequest request) {
  final dir = Directory(request.path);
  if (!dir.existsSync()) {
    request.sendPort.send(<MediaItem>[]);
    return;
  }

  final items = <MediaItem>[];
  int count = 0;

  try {
    request.sendPort.send('Scanning: ${request.path}...');

    // Recursive listing can be blocking for huge dirs, but we are in an isolate.
    // However, to provide updates, we might want to manually recurse or just update periodically if possible.
    // listSync is simplest but doesn't allow mid-stream updates easily unless we iterate the iterable.
    // Let's iterate the iterable from listSync (which computes all at once usually) or use list() stream?
    // listSync returns a List so it blocks until done.
    // Better to use Directory.list (Stream) or manual recursion for feedback.
    // For simplicity + feedback, let's use listSync but on subdirectories if we wanted granularity.
    // Actually, iterate listSync results? No, listSync blocks until the array is ready.
    // We should use Directory.listSync(recursive: true) which blocks. To show progress *during* search
    // we need manual recursion or non-recursive listSync.

    // Let's use recursive: true for performance, but we can only report "Found X items" *after* listSync returns?
    // No, that defeats the purpose if listSync takes 30s.
    // Let's use generic manual recursion for better feedback.

    final entities = dir.listSync(recursive: true, followLinks: false);
    request.sendPort.send('Found ${entities.length} files. Parsing...');

    for (final f in entities) {
      if (f is File && _isVideo(f.path)) {
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

bool _isVideo(String path) {
  const exts = ['.mp4', '.mkv', '.avi', '.mov', '.webm'];
  final ext = p.extension(path).toLowerCase();
  return exts.contains(ext);
}

MediaItem _parseFile(FileSystemEntity f) {
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
