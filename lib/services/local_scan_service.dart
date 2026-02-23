// Extracted from LibraryProvider — local filesystem scanning.
// Contains isolate-based directory scanning and file parsing.
import 'dart:io';
import 'dart:isolate';
import 'package:path/path.dart' as p;

import '../models/cast_member.dart';
import '../models/media_item.dart';
import '../services/sidecar_service.dart';
import '../utils/platform/platform.dart';
import '../utils/filename_parser.dart';
import '../utils/logger.dart';

/// Scans local directories for media files using an isolate.
class LocalScanService {
  const LocalScanService._();

  /// Check if a file path points to a video file.
  static bool isVideo(String path) {
    final ext = p.extension(path).toLowerCase();
    return const ['.mp4', '.mkv', '.avi', '.mov', '.webm', '.m4v']
        .contains(ext);
  }

  /// Parse a PlatformFile into a MediaItem.
  static MediaItem parseFile(PlatformFile f) {
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
          .map<CastMember>((performer) => CastMember(
              name: performer,
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
        // Ignore malformed NFOs
      }
    }

    return item;
  }

  /// Scan a local directory using an isolate. Returns all found MediaItems.
  /// Reports progress via [onProgress] callback.
  static Future<List<MediaItem>> scanFolder(
    String path, {
    List<String>? keywords,
    void Function(String currentItem)? onProgress,
  }) async {
    final port = ReceivePort();
    await Isolate.spawn(
      _scanDirectoryInIsolate,
      ScanRequest(port.sendPort, path, keywords: keywords),
    );

    final scannedItems = <MediaItem>[];
    await for (final message in port) {
      if (message is String) {
        onProgress?.call(message);
      } else if (message is List<MediaItem>) {
        scannedItems.addAll(message);
      } else if (message == true) {
        port.close();
        break;
      }
    }

    return scannedItems;
  }
}

// ── Isolate helpers (must be top-level for Isolate.spawn) ────────────

class ScanRequest {
  final SendPort sendPort;
  final String path;
  final List<String>? keywords;

  ScanRequest(this.sendPort, this.path, {this.keywords});
}

Future<void> _scanDirectoryInIsolate(ScanRequest request) async {
  final root = request.path;
  final keywords = request.keywords;
  final sendPort = request.sendPort;

  AppLogger.d('Isolate calling manual scan on: $root',
      tag: 'LocalScanService');

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
    AppLogger.critical('Isolate Fatal Error: $e',
        error: e, tag: 'LocalScanService');
    sendPort.send(true);
  }
}

Future<void> _scanRecursive(
  PlatformDirectory dir,
  List<String>? keywords,
  List<MediaItem> buffer,
  SendPort sendPort,
  int bufferSize,
) async {
  try {
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

    await for (final fsEntity
        in dir.list(recursive: false, followLinks: false).handleError((e) {
      AppLogger.w('Skip dir error: $e', error: e, tag: 'LocalScanService');
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
              type:
                  parsed.studio != null ? MediaType.scene : MediaType.movie,
              season: parsed.season,
              episode: parsed.episode,
              isAnime: pathStr.toLowerCase().contains('anime'),
              showKey: p.dirname(pathStr).toLowerCase(),
              isAdult: parsed.studio != null,
            );

            buffer.add(item);

            if (buffer.length >= bufferSize) {
              sendPort.send(List<MediaItem>.from(buffer));
              buffer.clear();
            }
          }
        } else if (fsEntity is PlatformDirectory) {
          await _scanRecursive(
              fsEntity, keywords, buffer, sendPort, bufferSize);
        }
      } catch (_) {
        // Skip entity errors silently
      }
    }
  } catch (_) {
    // Directory access error — skip
  }
}
