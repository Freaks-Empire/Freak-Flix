/// lib/services/sftp_streaming_service.dart
/// Service for streaming SFTP files by downloading to temp

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dartssh2/dartssh2.dart';
import 'remote_storage_service.dart';

/// Callback for download progress (0.0 to 1.0)
typedef ProgressCallback = void Function(double progress);

/// Service for downloading SFTP files for playback
class SftpStreamingService {
  static final SftpStreamingService _instance = SftpStreamingService._internal();
  static SftpStreamingService get instance => _instance;
  factory SftpStreamingService() => _instance;
  SftpStreamingService._internal();

  /// Cache of downloaded files to avoid re-downloading
  final Map<String, String> _downloadedFiles = {};

  /// Get a playable local path for an SFTP file
  /// Returns null if download fails or on web platform
  Future<String?> getPlayablePath({
    required String accountId,
    required String remotePath,
    ProgressCallback? onProgress,
  }) async {
    // SFTP is not supported on web (no dart:io, no SSH sockets)
    if (kIsWeb) {
      debugPrint('SftpStreaming: Not supported on web platform');
      return null;
    }
    
    // Check cache first
    final cacheKey = '$accountId:$remotePath';
    if (_downloadedFiles.containsKey(cacheKey)) {
      final cachedPath = _downloadedFiles[cacheKey]!;
      if (await File(cachedPath).exists()) {
        debugPrint('SftpStreaming: Using cached file: $cachedPath');
        return cachedPath;
      }
    }

    // Get account and password
    final account = RemoteStorageService.instance.getAccount(accountId);
    if (account == null) {
      debugPrint('SftpStreaming: Account not found: $accountId');
      return null;
    }

    final password = await RemoteStorageService.instance.getPassword(accountId);
    if (password == null) {
      debugPrint('SftpStreaming: Password not found for: $accountId');
      return null;
    }

    try {
      debugPrint('SftpStreaming: Connecting to ${account.host}:${account.port}...');
      
      // Connect via SSH
      final socket = await SSHSocket.connect(account.host, account.port);
      final client = SSHClient(
        socket,
        username: account.username,
        onPasswordRequest: () => password,
      );
      
      await client.authenticated;
      debugPrint('SftpStreaming: Authenticated');
      
      // Open SFTP session
      final sftp = await client.sftp();
      
      // Get file info for size
      final stat = await sftp.stat(remotePath);
      final fileSize = stat.size ?? 0;
      debugPrint('SftpStreaming: File size: $fileSize bytes');
      
      // Create temp file
      final tempDir = await getTemporaryDirectory();
      final fileName = remotePath.split('/').last;
      final localPath = '${tempDir.path}/sftp_cache/$accountId/${DateTime.now().millisecondsSinceEpoch}_$fileName';
      
      // Ensure directory exists
      await Directory('${tempDir.path}/sftp_cache/$accountId').create(recursive: true);
      
      // Open remote file
      final remoteFile = await sftp.open(remotePath);
      final localFile = File(localPath);
      final sink = localFile.openWrite();
      
      // Download with progress
      int bytesRead = 0;
      const chunkSize = 1024 * 1024; // 1MB chunks
      
      debugPrint('SftpStreaming: Downloading to $localPath');
      
      await for (final chunk in remoteFile.read()) {
        sink.add(chunk);
        bytesRead += chunk.length;
        
        if (fileSize > 0 && onProgress != null) {
          onProgress(bytesRead / fileSize);
        }
      }
      
      await sink.close();
      await remoteFile.close();
      client.close();
      
      debugPrint('SftpStreaming: Download complete - $bytesRead bytes');
      
      // Cache the path
      _downloadedFiles[cacheKey] = localPath;
      
      return localPath;
    } catch (e, stack) {
      debugPrint('SftpStreaming Error: $e');
      debugPrint('Stack: $stack');
      return null;
    }
  }

  /// Parse an SFTP file path into accountId and remotePath
  /// Format: sftp:accountId:/path/to/file
  static (String accountId, String remotePath)? parseSftpPath(String path) {
    if (!path.startsWith('sftp:')) return null;
    
    // Remove 'sftp:' prefix
    final withoutPrefix = path.substring(5);
    
    // Find the first colon after accountId (accountId is a UUID, so look for :/)
    final colonSlashIndex = withoutPrefix.indexOf(':/');
    if (colonSlashIndex == -1) return null;
    
    final accountId = withoutPrefix.substring(0, colonSlashIndex);
    final remotePath = withoutPrefix.substring(colonSlashIndex + 1); // Include the leading /
    
    return (accountId, remotePath);
  }

  /// Clear cached files to free disk space
  Future<void> clearCache() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final cacheDir = Directory('${tempDir.path}/sftp_cache');
      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
        debugPrint('SftpStreaming: Cache cleared');
      }
      _downloadedFiles.clear();
    } catch (e) {
      debugPrint('SftpStreaming: Error clearing cache: $e');
    }
  }
}
