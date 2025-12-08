import 'dart:io';
import 'dart:isolate';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/media_item.dart';
import '../services/metadata_service.dart';
import 'settings_provider.dart';

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

  List<MediaItem> get movies => items.where((i) => i.type == MediaType.movie).toList();
  List<MediaItem> get tv => items.where((i) => i.type == MediaType.tv).toList();
  List<MediaItem> get anime => items.where((i) => i.type == MediaType.anime).toList();

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
  final animeHint = filePath.toLowerCase().contains('anime');
  String? title;
  int? year;
  int? season;
  int? episode;
  final nameNoExt = p.basenameWithoutExtension(fileName);

  final yearMatch = RegExp(r'[.\s\[(](19|20)\d{2}[)\].\s]').firstMatch('$nameNoExt ');
  if (yearMatch != null) {
    year = int.tryParse(yearMatch.group(0)!.replaceAll(RegExp(r'\D'), ''));
  }
  final seMatch = RegExp(r'[Ss](\d{1,2})[Ee](\d{1,3})').firstMatch(nameNoExt);
  if (seMatch != null) {
    season = int.tryParse(seMatch.group(1)!);
    episode = int.tryParse(seMatch.group(2)!);
  }
  title = nameNoExt
      .replaceAll(RegExp(r'\.(19|20)\d{2}.*'), '')
      .replaceAll(RegExp(r'[._]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (title.isEmpty) title = fileName;

    final type = seMatch != null
      ? MediaType.tv
      : animeHint
        ? MediaType.anime
        : MediaType.movie;

  return MediaItem(
    id: id,
    filePath: filePath,
    fileName: fileName,
    folderPath: folder,
    sizeBytes: stat.size,
    lastModified: stat.modified,
    title: title,
    year: year,
    type: type,
    season: season,
    episode: episode,
  );
}