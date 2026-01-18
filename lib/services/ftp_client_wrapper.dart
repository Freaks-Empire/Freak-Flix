/// lib/services/ftp_client_wrapper.dart
/// FTP client implementation using ftpconnect

import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:ftpconnect/ftpconnect.dart';
import 'remote_storage_service.dart';

/// FTP client for browsing and streaming files
class FtpClientWrapper {
  final RemoteStorageAccount account;
  FTPConnect? _ftpClient;

  FtpClientWrapper(this.account);

  /// Connect to the FTP server
  Future<bool> connect(String password) async {
    try {
      _ftpClient = FTPConnect(
        account.host,
        port: account.port,
        user: account.username,
        pass: password,
        timeout: 30,
      );
      
      final connected = await _ftpClient!.connect();
      if (connected) {
        debugPrint('FTP: Connected to ${account.host}');
      }
      return connected;
    } catch (e) {
      debugPrint('FTP Connection Error: $e');
      return false;
    }
  }

  /// List files in a directory
  Future<List<RemoteFile>> listDirectory(String path) async {
    if (_ftpClient == null) {
      throw Exception('Not connected');
    }

    // Change to the directory first
    if (path.isNotEmpty && path != '/') {
      await _ftpClient!.changeDirectory(path);
    }

    final items = await _ftpClient!.listDirectoryContent();
    
    return items.map((item) {
      final isDir = item.type == FTPEntryType.dir;
      return RemoteFile(
        name: item.name,
        path: path.endsWith('/') ? '$path${item.name}' : '$path/${item.name}',
        isDirectory: isDir,
        size: item.size,
        modifiedTime: item.modifyTime,
      );
    }).toList();
  }

  /// Get a direct URL for streaming (FTP supports ftp:// URLs)
  String getStreamUrl(String remotePath) {
    // FTP URL format: ftp://user:pass@host:port/path
    // Note: This exposes credentials - only for local use
    return 'ftp://${account.username}@${account.host}:${account.port}$remotePath';
  }

  /// Download file content as bytes
  Future<Uint8List> downloadFile(String remotePath) async {
    if (_ftpClient == null) {
      throw Exception('Not connected');
    }

    // Navigate to directory containing the file
    final dirPath = remotePath.substring(0, remotePath.lastIndexOf('/'));
    final fileName = remotePath.substring(remotePath.lastIndexOf('/') + 1);
    
    if (dirPath.isNotEmpty) {
      await _ftpClient!.changeDirectory(dirPath);
    }

    // Download to temp and read bytes
    // FTPConnect doesn't have direct byte download, would need temp file
    throw UnimplementedError('FTP byte download requires temp file handling');
  }

  /// Check if path is a directory
  Future<bool> isDirectory(String path) async {
    if (_ftpClient == null) return false;
    
    try {
      await _ftpClient!.changeDirectory(path);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Disconnect from the server
  Future<void> disconnect() async {
    await _ftpClient?.disconnect();
    _ftpClient = null;
    debugPrint('FTP: Disconnected');
  }

  /// Test connection with credentials
  static Future<bool> testConnection({
    required String host,
    required int port,
    required String username,
    required String password,
  }) async {
    try {
      final client = FTPConnect(
        host,
        port: port,
        user: username,
        pass: password,
        timeout: 10,
      );
      final connected = await client.connect();
      if (connected) {
        await client.disconnect();
      }
      return connected;
    } catch (e) {
      debugPrint('FTP Test Connection Failed: $e');
      return false;
    }
  }
}
