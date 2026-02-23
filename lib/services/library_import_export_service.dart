// Extracted from LibraryProvider — import/export, migration,
// and clean-up logic. All methods are static and stateless.
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/library_folder.dart';
import '../models/media_item.dart';
import '../models/user_profile.dart';
import '../utils/logger.dart';

class LibraryImportExportService {
  const LibraryImportExportService._();

  // ── Export ──────────────────────────────────────────────────────────

  static Map<String, dynamic> export(
      List<LibraryFolder> folders, List<MediaItem> items) {
    return {
      'folders': folders.map((f) => f.toJson()).toList(),
      'items': MediaItem.listToJson(items),
    };
  }

  // ── Legacy history extraction ──────────────────────────────────────

  static Map<String, UserMediaData> extractLegacyHistory(
      List<MediaItem> items) {
    final map = <String, UserMediaData>{};
    for (final item in items) {
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

  // ── Folder stats ───────────────────────────────────────────────────

  static ({int count, int sizeBytes}) computeFolderStats(
      List<MediaItem> items, LibraryFolder folder) {
    final relevant = items.where((i) {
      if (folder.accountId.isNotEmpty) {
        final rootPath =
            'onedrive:${folder.accountId}${folder.path.isEmpty ? '/' : folder.path}';
        return i.folderPath.startsWith(rootPath);
      } else {
        return i.filePath.startsWith(folder.path);
      }
    });

    final count = relevant.length;
    final size = relevant.fold<int>(0, (sum, item) => sum + item.sizeBytes);
    return (count: count, sizeBytes: size);
  }

  // ── Import (merge strategy) ────────────────────────────────────────

  /// Returns merged folders and merged items without mutating inputs.
  static ({
    List<LibraryFolder> mergedFolders,
    List<MediaItem> mergedItems,
  }) importState({
    required Map<String, dynamic> data,
    required List<LibraryFolder> currentFolders,
    required List<MediaItem> currentItems,
  }) {
    var mergedFolders = <LibraryFolder>[...currentFolders];
    var mergedItems = <MediaItem>[...currentItems];

    // 1. Import Folders
    final rawFolders = data['folders'] as List<dynamic>?;
    if (rawFolders != null) {
      AppLogger.d('Processing ${rawFolders.length} folders from backup',
          tag: 'ImportExport');
      final incomingFolders = rawFolders
          .map((e) => LibraryFolder.fromJson(e as Map<String, dynamic>))
          .toList();

      for (final inc in incomingFolders) {
        final existsById = mergedFolders.any(
            (curr) => curr.id == inc.id && curr.accountId == inc.accountId);

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
      AppLogger.d('Final folder count: ${mergedFolders.length}',
          tag: 'ImportExport');
    }

    // 2. Import Items
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

      AppLogger.d('Processing ${cloudItems.length} items from backup',
          tag: 'ImportExport');

      final map = {for (var i in mergedItems) i.id: i};
      for (final i in cloudItems) {
        map[i.id] = i;
      }
      mergedItems = map.values.toList()
        ..sort((a, b) => b.lastModified.compareTo(a.lastModified));
      AppLogger.d('Final item count: ${mergedItems.length}',
          tag: 'ImportExport');
    }

    return (mergedFolders: mergedFolders, mergedItems: mergedItems);
  }

  // ── Clean orphan items ─────────────────────────────────────────────

  /// Returns list of items to remove (items whose local files don't exist).
  static Future<List<MediaItem>> findOrphanItems(
      List<MediaItem> items) async {
    final List<MediaItem> toRemove = [];
    final List<MediaItem> candidates = List.from(items);

    for (int idx = 0; idx < candidates.length; idx++) {
      final item = candidates[idx];

      // Skip cloud items
      if (item.filePath.startsWith('http') ||
          item.folderPath.startsWith('onedrive:') ||
          item.folderPath.startsWith('sftp:') ||
          item.folderPath.startsWith('ftp:') ||
          item.folderPath.startsWith('webdav:')) {
        continue;
      }

      final file = File(item.filePath);
      if (!file.existsSync()) {
        if (p.isAbsolute(item.filePath)) {
          toRemove.add(item);
        }
      }

      // Yield to event loop every 100 items
      if (idx % 100 == 0) {
        await Future.delayed(Duration.zero);
      }
    }

    return toRemove;
  }

  // ── Migration from SharedPreferences ───────────────────────────────

  static Future<List<LibraryFolder>?> migrateFoldersFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final rawFolders = prefs.getString('library_folders_v1');
    if (rawFolders == null) return null;

    try {
      final List<dynamic> decoded =
          (await Future.value(rawFolders)).isEmpty
              ? []
              : List<dynamic>.from(
                  (rawFolders as dynamic) is String
                      ? _decodeJson(rawFolders)
                      : rawFolders as List,
                );
      return decoded
          .map((e) => LibraryFolder.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return null;
    }
  }

  static dynamic _decodeJson(String json) {
    // Helper to safely decode JSON from prefs
    try {
      return json.isNotEmpty
          ? (json.startsWith('[') || json.startsWith('{'))
              ? json // Let caller decode
              : null
          : null;
    } catch (_) {
      return null;
    }
  }
}
