// Extracted from LibraryProvider — Remote storage scanning (SFTP, FTP, WebDAV).
// Remote storage scanning (SFTP, FTP, WebDAV).

import '../models/library_folder.dart';
import '../models/media_item.dart';
import '../services/sftp_client.dart';
import '../services/ftp_client_wrapper.dart';
import '../services/webdav_client_wrapper.dart';
import '../services/remote_storage_service.dart';
import '../utils/filename_parser.dart';
import '../utils/logger.dart';

/// Scans remote storage folders (SFTP, FTP, WebDAV) for media files.
class RemoteScanService {
  const RemoteScanService._();

  // ── Media file detection ───────────────────────────────────────────

  static bool isMediaFile(String filename) {
    final ext = filename.toLowerCase().split('.').lastOrNull ?? '';
    const videoExtensions = [
      'mp4', 'mkv', 'avi', 'mov', 'wmv', 'flv', 'webm', 'm4v',
      'mpg', 'mpeg', 'ts', 'm2ts', 'vob', 'divx', 'xvid', '3gp'
    ];
    return videoExtensions.contains(ext);
  }

  // ── Item creation ──────────────────────────────────────────────────

  static MediaItem createRemoteMediaItem(RemoteFile file, LibraryFolder folder) {
    final parsed = FilenameParser.parse(file.name);

    MediaType type;
    switch (folder.type) {
      case LibraryType.movies:
        type = MediaType.movie;
        break;
      case LibraryType.tv:
        type = MediaType.tv;
        break;
      case LibraryType.anime:
        type = MediaType.tv;
        break;
      case LibraryType.adult:
        type = MediaType.scene;
        break;
      case LibraryType.other:
        type = MediaType.movie;
        break;
    }

    final itemId =
        '${folder.path.split(':').first}:${folder.accountId}:${file.path}';

    final folderPathFromFile = file.path.contains('/')
        ? file.path.substring(0, file.path.lastIndexOf('/'))
        : '/';

    final filePath =
        '${folder.path.split(':').first}:${folder.accountId}:${file.path}';

    return MediaItem(
      id: itemId,
      title: parsed.movieTitle ?? file.name.replaceAll(RegExp(r'\.[^.]+$'), ''),
      year: parsed.year,
      type: type,
      filePath: filePath,
      fileName: file.name,
      folderPath: folderPathFromFile,
      sizeBytes: file.size ?? 0,
      lastModified: file.modifiedTime ?? DateTime.now(),
      season: parsed.season,
      episode: parsed.episode,
      isAdult: folder.type == LibraryType.adult,
      isAnime: folder.type == LibraryType.anime,
    );
  }

  // ── Main scan orchestrator ─────────────────────────────────────────

  /// Scans a remote folder and returns the found MediaItems.
  /// Protocol dispatch, connection and teardown are handled internally.
  static Future<List<MediaItem>> scanFolder(
    LibraryFolder folder, {
    bool Function()? cancelRequested,
    void Function(String status)? onProgress,
  }) async {
    final pathParts = folder.path.split(':');
    if (pathParts.length < 2) {
      throw Exception('Invalid remote path format: ${folder.path}');
    }

    final protocol = pathParts[0];
    final remainder = pathParts.sublist(1).join(':');
    final accountId = folder.accountId;

    String remotePath = '/';
    if (remainder.startsWith(accountId)) {
      remotePath = remainder.substring(accountId.length);
      if (remotePath.isEmpty) remotePath = '/';
    } else {
      remotePath = remainder.startsWith('/') ? remainder : '/$remainder';
    }

    final account = RemoteStorageService.instance.getAccount(accountId);
    if (account == null) {
      throw Exception('Remote account not found: $accountId');
    }

    final password =
        await RemoteStorageService.instance.getPassword(accountId);
    if (password == null) {
      throw Exception('No credentials found for account');
    }

    onProgress?.call('Connecting to ${account.host}...');

    RemoteStorageType type;
    switch (protocol) {
      case 'sftp':
        type = RemoteStorageType.sftp;
        break;
      case 'ftp':
        type = RemoteStorageType.ftp;
        break;
      case 'webdav':
        type = RemoteStorageType.webdav;
        break;
      default:
        throw Exception('Unknown protocol: $protocol');
    }

    final scannedItems = <MediaItem>[];
    final cancel = cancelRequested ?? () => false;

    switch (type) {
      case RemoteStorageType.sftp:
        final client = SftpClient(account);
        if (await client.connect(password)) {
          await _scanSftpDirectory(
              client, remotePath, folder, scannedItems, cancel, onProgress);
          client.disconnect();
        } else {
          throw Exception('Failed to connect to SFTP server');
        }
        break;

      case RemoteStorageType.ftp:
        final client = FtpClientWrapper(account);
        if (await client.connect(password)) {
          await _scanFtpDirectory(
              client, remotePath, folder, scannedItems, cancel, onProgress);
          await client.disconnect();
        } else {
          throw Exception('Failed to connect to FTP server');
        }
        break;

      case RemoteStorageType.webdav:
        final client = WebDavClientWrapper(account);
        if (await client.connect(password)) {
          await _scanWebDavDirectory(
              client, remotePath, folder, scannedItems, cancel, onProgress);
          client.disconnect();
        } else {
          throw Exception('Failed to connect to WebDAV server');
        }
        break;
    }

    return scannedItems;
  }

  // ── Protocol-specific recursive scanners ───────────────────────────

  static Future<void> _scanSftpDirectory(
    SftpClient client,
    String path,
    LibraryFolder folder,
    List<MediaItem> items,
    bool Function() cancelRequested,
    void Function(String)? onProgress,
  ) async {
    try {
      final files = await client.listDirectory(path);
      for (final file in files) {
        if (cancelRequested()) break;
        if (file.isDirectory) {
          await _scanSftpDirectory(
              client, file.path, folder, items, cancelRequested, onProgress);
        } else if (isMediaFile(file.name)) {
          onProgress?.call(file.name);
          items.add(createRemoteMediaItem(file, folder));
        }
      }
    } catch (e) {
      AppLogger.e('Error scanning SFTP directory $path: $e',
          error: e, tag: 'RemoteScanService');
    }
  }

  static Future<void> _scanFtpDirectory(
    FtpClientWrapper client,
    String path,
    LibraryFolder folder,
    List<MediaItem> items,
    bool Function() cancelRequested,
    void Function(String)? onProgress,
  ) async {
    try {
      final files = await client.listDirectory(path);
      for (final file in files) {
        if (cancelRequested()) break;
        if (file.isDirectory) {
          await _scanFtpDirectory(
              client, file.path, folder, items, cancelRequested, onProgress);
        } else if (isMediaFile(file.name)) {
          onProgress?.call(file.name);
          items.add(createRemoteMediaItem(file, folder));
        }
      }
    } catch (e) {
      AppLogger.e('Error scanning FTP directory $path: $e',
          error: e, tag: 'RemoteScanService');
    }
  }

  static Future<void> _scanWebDavDirectory(
    WebDavClientWrapper client,
    String path,
    LibraryFolder folder,
    List<MediaItem> items,
    bool Function() cancelRequested,
    void Function(String)? onProgress,
  ) async {
    try {
      final files = await client.listDirectory(path);
      for (final file in files) {
        if (cancelRequested()) break;
        if (file.isDirectory) {
          await _scanWebDavDirectory(
              client, file.path, folder, items, cancelRequested, onProgress);
        } else if (isMediaFile(file.name)) {
          onProgress?.call(file.name);
          items.add(createRemoteMediaItem(file, folder));
        }
      }
    } catch (e) {
      AppLogger.e('Error scanning WebDAV directory $path: $e',
          error: e, tag: 'RemoteScanService');
    }
  }
}
