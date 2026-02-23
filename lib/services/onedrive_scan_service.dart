// Extracted from LibraryProvider — OneDrive Graph API scanning.
// Contains the recursive folder walker and item creation from Graph API.
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../models/cast_member.dart';
import '../models/media_item.dart';
import '../services/sidecar_service.dart';
import '../utils/filename_parser.dart';
import '../utils/logger.dart';

/// Callback for per-item progress and ingestion during OneDrive scanning.
typedef OneDriveItemCallback = Future<void> Function(MediaItem item);

/// Scans OneDrive folders via Microsoft Graph API.
class OneDriveScanService {
  const OneDriveScanService._();

  /// Create a MediaItem from a Graph API JSON response.
  static MediaItem createMediaItemFromGraph(
      Map<String, dynamic> json, String accountId, String folderPath) {
    final id = json['id'] as String;
    final name = json['name'] as String;
    final size = json['size'] as int? ?? 0;
    final lastModStr = json['lastModifiedDateTime'] as String?;
    final lastMod =
        lastModStr != null ? DateTime.parse(lastModStr) : DateTime.now();

    final parsed = FilenameParser.parse(name);

    String? overview;
    if (parsed.studio != null) {
      overview = 'Studio: ${parsed.studio}\n';
    }

    List<CastMember> cast = [];
    if (parsed.performers.isNotEmpty) {
      cast = parsed.performers
          .map<CastMember>((perf) => CastMember(
              name: perf,
              id: '',
              character: 'Performer',
              source: CastSource.stashDb))
          .toList();
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

  /// Check whether a filename is a video.
  static bool isVideo(String path) {
    final ext = p.extension(path).toLowerCase();
    return const ['.mp4', '.mkv', '.avi', '.mov', '.webm', '.m4v']
        .contains(ext);
  }

  /// Recursively walk a OneDrive folder via Graph API, collecting media items.
  ///
  /// [token] — bearer access token. 
  /// [url] — initial Graph API children endpoint.
  /// [baseFolderPath] — prefix like `onedrive:accountId/path`.
  /// [accountId] — MS graph account ID.
  /// [siblingValues] — optional sibling items list for NFO lookup.
  /// [cancelRequested] — call to check for user cancellation.
  /// [onProgress] — called with status messages.
  /// [onItemFound] — called for each media item found (allows per-item ingestion).
  static Future<List<MediaItem>> walkFolder({
    required String token,
    required String url,
    required String baseFolderPath,
    required String accountId,
    required bool Function() cancelRequested,
    void Function(String status)? onProgress,
    OneDriveItemCallback? onItemFound,
  }) async {
    final collectedItems = <MediaItem>[];

    await _walkRecursive(
      token: token,
      url: url,
      baseFolderPath: baseFolderPath,
      accountId: accountId,
      collectedItems: collectedItems,
      cancelRequested: cancelRequested,
      onProgress: onProgress,
      onItemFound: onItemFound,
    );

    return collectedItems;
  }

  static Future<void> _walkRecursive({
    required String token,
    required String url,
    required String baseFolderPath,
    required String accountId,
    required List<MediaItem> collectedItems,
    required bool Function() cancelRequested,
    void Function(String status)? onProgress,
    OneDriveItemCallback? onItemFound,
  }) async {
    if (cancelRequested()) return;

    String? nextLink = url;

    while (nextLink != null && !cancelRequested()) {
      try {
        final uri = Uri.parse(nextLink);
        final response =
            await http.get(uri, headers: {'Authorization': 'Bearer $token'});

        if (response.statusCode != 200) {
          AppLogger.e(
              'Graph Walk Error: ${response.statusCode} - ${response.body}',
              tag: 'OneDriveScanService');
          return;
        }

        final map = jsonDecode(response.body);
        final List<dynamic> value = map['value'] ?? [];

        for (final item in value) {
          if (cancelRequested()) break;

          final name = item['name'] as String;
          final isFolder = item['folder'] != null;
          final isFile = item['file'] != null;
          final id = item['id'] as String;

          if (isFolder) {
            final childUrl =
                'https://graph.microsoft.com/v1.0/me/drive/items/$id/children';
            await _walkRecursive(
              token: token,
              url: childUrl,
              baseFolderPath: '$baseFolderPath/$name',
              accountId: accountId,
              collectedItems: collectedItems,
              cancelRequested: cancelRequested,
              onProgress: onProgress,
              onItemFound: onItemFound,
            );
          } else if (isFile && isVideo(name)) {
            onProgress?.call('Found: $name');

            var newItem =
                createMediaItemFromGraph(item, accountId, baseFolderPath);

            // Try to read sibling NFO
            newItem = await _tryApplyNfo(newItem, name, value, token);

            collectedItems.add(newItem);
            if (onItemFound != null) await onItemFound(newItem);
          }
        }

        nextLink = map['@odata.nextLink'];
      } catch (e) {
        AppLogger.e('Graph Walk Exception: $e',
            error: e, tag: 'OneDriveScanService');
        nextLink = null;
      }
    }
  }

  /// Try to find and apply NFO sidecar data from sibling files.
  static Future<MediaItem> _tryApplyNfo(
    MediaItem item,
    String fileName,
    List<dynamic> siblingValues,
    String token,
  ) async {
    final nfoName = '${p.basenameWithoutExtension(fileName)}.nfo';
    final nfoEntry = siblingValues.cast<Map<String, dynamic>?>().firstWhere(
          (e) => e != null && (e['name'] as String? ?? '') == nfoName,
          orElse: () => null,
        );

    final nfoDownloadUrl = nfoEntry != null
        ? nfoEntry['@microsoft.graph.downloadUrl'] as String?
        : null;

    if (nfoDownloadUrl == null) return item;

    try {
      final nfoRes = await http.get(Uri.parse(nfoDownloadUrl));
      if (nfoRes.statusCode == 200) {
        final nfoData = SidecarService.parseNfo(nfoRes.body);
        if (nfoData != null) {
          item = item.copyWith(
            stashId: nfoData['stashId'] as String?,
            tmdbId: nfoData['tmdbId'] as int? ?? item.tmdbId,
            anilistId: nfoData['anilistId'] as int? ?? item.anilistId,
            title: nfoData['title'] as String? ?? item.title,
            year: nfoData['year'] as int? ?? item.year,
          );
          if (nfoData['stashId'] != null) {
            AppLogger.d(
                'Found stashid ${nfoData['stashId']} in NFO for $fileName',
                tag: 'OneDriveScanService');
          }
        }
      }
    } catch (_) {
      // Ignore NFO fetch errors
    }
    return item;
  }
}
