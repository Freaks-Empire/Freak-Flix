import 'dart:io';
import 'dart:isolate';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/media_item.dart';
import '../services/metadata_service.dart';
import 'settings_provider.dart';
import '../utils/filename_parser.dart';

class LibraryProvider extends ChangeNotifier {
  static const _prefsKey = 'library_v1';

  final SettingsProvider settings;
  List<MediaItem> items = [];
  bool isLoading = false;
  String? error;
  String scanningStatus = '';

  LibraryProvider(this.settings);

  Future<void> loadLibrary() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null) return;
    items = MediaItem.listFromJson(raw);

    // Reclassify with updated rules (anime flag + tv/movie only).
    bool updated = false;
    for (var i = 0; i < items.length; i++) {
      final parsed = FilenameParser.parse(items[i].fileName);
      final inferredType = _inferTypeFromPath(items[i]);
      final inferredAnime = _inferAnimeFromPath(items[i]);
      final updatedItem = items[i].copyWith(
        title: parsed.seriesTitle.isNotEmpty ? parsed.seriesTitle : items[i].title,
        season: items[i].season ?? parsed.season ?? (parsed.episode != null ? 1 : null),
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
    notifyListeners();
  }

  Future<void> saveLibrary() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, MediaItem.listToJson(items));
  }

  Future<void> pickAndScan({MetadataService? metadata}) async {
    error = null;
    isLoading = true;
    scanningStatus = 'Initializing...';
    notifyListeners();
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        final result = await FilePicker.platform.pickFiles(
          allowMultiple: true,
          type: FileType.custom,
          allowedExtensions: ['mp4', 'mkv', 'avi', 'mov', 'webm'],
        );
        if (result == null) {
          isLoading = false;
          scanningStatus = '';
          notifyListeners();
          return;
        }
        final files = result.paths.whereType<String>().map(File.new).toList();
        await _ingestFiles(files, metadata);
      } else {
        final path = await FilePicker.platform.getDirectoryPath();
        if (path == null) {
          isLoading = false;
          scanningStatus = '';
          notifyListeners();
          return;
        }
        settings.setLastFolder(path);
        
        // Spawn isolate for streaming background scanning
        final port = ReceivePort();
        await Isolate.spawn(_scanDirectoryInIsolate, _ScanRequest(port.sendPort, path));
        
        final scannedItems = <MediaItem>[];
        await for (final message in port) {
          if (message is String) {
            scanningStatus = message;
            notifyListeners();
          } else if (message is List<MediaItem>) {
            scannedItems.addAll(message);
            port.close();
            break; // Done
          }
        }
        
        scanningStatus = 'Finalizing...';
        notifyListeners();
        await _ingestItems(scannedItems, metadata);
      }
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      scanningStatus = '';
      notifyListeners();
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

  Future<void> _ingestItems(List<MediaItem> newItems, MetadataService? metadata) async {
    final map = {for (var i in items) i.filePath: i};
    for (final item in newItems) {
      map[item.filePath] = item;
    }
    items = map.values.toList()..sort((a, b) => b.lastModified.compareTo(a.lastModified));
    notifyListeners();

    if (settings.autoFetchAfterScan && metadata != null) {
      for (int i = 0; i < items.length; i++) {
        scanningStatus = 'Fetching metadata: ${items[i].title}';
        notifyListeners();
        final enriched = await metadata.enrich(items[i]);
        items[i] = enriched;
        notifyListeners();
      }
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

  List<MediaItem> get movies => items.where((i) => i.type == MediaType.movie).toList();

  // Group TV/anime by showKey and aggregate episodes under one show card.
  List<MediaItem> get tv => _groupShows(items.where((i) => i.type == MediaType.tv));

  List<MediaItem> get anime => _groupShows(items.where((i) => i.type == MediaType.tv && i.isAnime));

  List<TvShowGroup> get groupedTvShows => _groupShowsToGroups(items.where((i) => i.type == MediaType.tv));

  List<TvShowGroup> get groupedAnimeShows =>
      _groupShowsToGroups(items.where((i) => i.type == MediaType.tv && i.isAnime));

  List<MediaItem> get continueWatching =>
      items.where((i) => i.lastPositionSeconds > 0 && !i.isWatched).toList();

  List<MediaItem> get recentlyAdded {
    final sorted = [...items]..sort((a, b) => b.lastModified.compareTo(a.lastModified));
    return sorted.take(20).toList();
  }

  List<MediaItem> get topRated {
    final sorted = [...items]..sort((a, b) => (b.rating ?? 0).compareTo(a.rating ?? 0));
    return sorted.take(20).toList();
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

  final showKey = _seriesKeyRaw(parsed.seriesTitle, parsed.year);

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
  final path = item.filePath.toLowerCase();

  final fileName = p.basenameWithoutExtension(item.fileName).toLowerCase();
  final folderName = p.basename(item.folderPath).toLowerCase();
  final hasSeasonInFolder = RegExp(r'season[ _-]?\d{1,2}').hasMatch(folderName);
  final hasTvPattern =
      RegExp(r'[Ss]\d{1,2}[Ee]\d{1,3}').hasMatch(fileName) ||
      RegExp(r'(?:^|[\s._-])(?:ep(?:isode)?\s*)?\d{1,3}(?!\d)').hasMatch(fileName) ||
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

  // Derive series key from parsed filename to keep all episodes of a show together.
  final parsed = FilenameParser.parse(item.fileName);
  final seriesTitle = parsed.seriesTitle.isNotEmpty ? parsed.seriesTitle : (item.title ?? '');
  final year = item.year ?? parsed.year;
  return _seriesKeyRaw(seriesTitle, year);
}

String _seriesKeyRaw(String title, int? year) {
  final base = title.toLowerCase().trim();
  final yr = year?.toString() ?? '';
  return '$base-$yr';
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
    // Prefer explicit showKey; otherwise fallback to normalized parsed title.
    final parsed = FilenameParser.parse(item.fileName);
    final seriesTitle = parsed.seriesTitle.isNotEmpty ? parsed.seriesTitle : (item.title ?? '');
    final key = (item.showKey ?? seriesTitle.toLowerCase()).trim();
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
    final title = parsedFirst.seriesTitle.isNotEmpty ? parsedFirst.seriesTitle : first.title ?? first.fileName;
    final poster = episodes.firstWhere((e) => e.posterUrl != null, orElse: () => first).posterUrl;
    final backdrop = episodes.firstWhere((e) => e.backdropUrl != null, orElse: () => first).backdropUrl;
    final year = episodes.firstWhere((e) => e.year != null, orElse: () => first).year ?? parsedFirst.year;
    final isAnime = episodes.any((e) => e.isAnime);
    return TvShowGroup(
      title: title ?? 'Unknown',
      isAnime: isAnime,
      showKey: entry.key,
      episodes: episodes,
      posterUrl: poster,
      backdropUrl: backdrop,
      year: year,
    );
  }).toList();
}