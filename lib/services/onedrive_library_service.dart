import 'package:microsoft_graph_api/microsoft_graph_api.dart';
import 'package:path/path.dart' as p;

import '../models/media_item.dart';
import '../utils/filename_parser.dart';

/// Maps OneDrive items to MediaItems using Microsoft Graph.
class OneDriveLibraryService {
  final MSGraphAPI graph;

  OneDriveLibraryService(String accessToken) : graph = MSGraphAPI(accessToken);

  /// Load video files directly under a OneDrive path (non-recursive for now).
  Future<List<MediaItem>> loadFolder(String oneDrivePath) async {
    // Resolve folder by path.
    final folderItem = await graph.drive.getItemByPath(oneDrivePath);
    final folderId = folderItem.id;

    // List items within the folder.
    final items = await graph.drive.listItems(folderId: folderId);

    final videos = <MediaItem>[];

    for (final item in items) {
      // Skip folders.
      if (item.folder != null) continue;

      final name = item.name ?? '';
      if (!_isVideo(name)) continue;

      final sizeBytes = item.size ?? 0;
      final modified = item.lastModifiedDateTime ?? item.createdDateTime ?? DateTime.now();

      final parsed = FilenameParser.parse(name);
      final type = (parsed.season != null || parsed.episode != null) ? MediaType.tv : MediaType.movie;
      final animeHint = oneDrivePath.toLowerCase().contains('anime');

      final filePath = '$oneDrivePath/${item.name}';
      final id = 'onedrive:${item.id ?? filePath}';

      videos.add(
        MediaItem(
          id: id,
          filePath: filePath,
          fileName: name,
          folderPath: oneDrivePath,
          sizeBytes: sizeBytes,
          lastModified: modified,
          title: parsed.seriesTitle,
          year: parsed.year,
          type: type,
          season: parsed.season,
          episode: parsed.episode,
          isAnime: animeHint,
          showKey: oneDrivePath.toLowerCase(),
        ),
      );
    }

    return videos;
  }

  bool _isVideo(String filename) {
    final ext = p.extension(filename).toLowerCase();
    const exts = ['.mp4', '.mkv', '.avi', '.mov', '.webm'];
    return exts.contains(ext);
  }
}
