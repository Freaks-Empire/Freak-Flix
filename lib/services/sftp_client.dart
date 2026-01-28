/// lib/services/sftp_client.dart
/// SFTP client implementation using dartssh2

import 'dart:async';
import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/foundation.dart';
import 'remote_storage_service.dart';
import '../utils/input_validation.dart';

/// SFTP client for browsing and streaming files
class SftpClient {
  final RemoteStorageAccount account;
  SSHClient? _sshClient;
  SftpClient? _sftpClient;

  SftpClient(this.account);

  /// Connect to the SFTP server
  Future<bool> connect(String password, {String? privateKey}) async {
    // Validate connection parameters
    final hostValidation = InputValidation.validateHostname(account.host);
    if (hostValidation != null) {
      debugPrint('SFTP: Invalid host - $hostValidation');
      return false;
    }
    
    final portValidation = InputValidation.validatePort(account.port.toString());
    if (portValidation != null) {
      debugPrint('SFTP: Invalid port - $portValidation');
      return false;
    }
    
    try {
      debugPrint('SFTP: Connecting to ${InputValidation.sanitizeForLogging(account.host)}:${InputValidation.sanitizeForLogging(account.port.toString())}');
      final socket = await SSHSocket.connect(account.host, account.port);
      
      _sshClient = SSHClient(
        socket,
        username: account.username,
        onPasswordRequest: () => password,
        onUserauthBanner: (banner) {
          debugPrint('SFTP Banner: $banner');
        },
      );

      // Wait for authentication
      await _sshClient!.authenticated;
      debugPrint('SFTP: Connected to ${InputValidation.sanitizeForLogging(account.host)}');
      return true;
    } catch (e) {
      debugPrint('SFTP Connection Error: $e');
      return false;
    }
  }

  /// List files in a directory
  Future<List<RemoteFile>> listDirectory(String path) async {
    if (_sshClient == null) {
      throw Exception('Not connected');
    }

    final sftp = await _sshClient!.sftp();
    final items = await sftp.listdir(path);
    
    return items
        .where((item) => item.filename != '.' && item.filename != '..')
        .map((item) => RemoteFile(
              name: item.filename,
              path: path.endsWith('/') 
                  ? '$path${item.filename}' 
                  : '$path/${item.filename}',
              isDirectory: item.attr.isDirectory,
              size: item.attr.size,
              modifiedTime: item.attr.modifyTime != null 
                  ? DateTime.fromMillisecondsSinceEpoch(item.attr.modifyTime! * 1000)
                  : null,
            ))
        .toList();
  }

  /// Get a direct URL for streaming (SFTP doesn't support direct URLs)
  /// Returns null - caller should use downloadFile instead
  String? getStreamUrl(String remotePath) {
    // SFTP doesn't support HTTP URLs
    // Video playback will need to download or use a local proxy
    return null;
  }

  /// Download file content as bytes
  Future<Uint8List> downloadFile(String remotePath) async {
    if (_sshClient == null) {
      throw Exception('Not connected');
    }

    final sftp = await _sshClient!.sftp();
    final file = await sftp.open(remotePath);
    final content = await file.readBytes();
    await file.close();
    return content;
  }

  /// Check if a path exists and is a directory
  Future<bool> isDirectory(String path) async {
    if (_sshClient == null) return false;
    
    try {
      final sftp = await _sshClient!.sftp();
      final stat = await sftp.stat(path);
      return stat.isDirectory;
    } catch (_) {
      return false;
    }
  }

  /// Disconnect from the server
  void disconnect() {
    _sshClient?.close();
    _sshClient = null;
    debugPrint('SFTP: Disconnected');
  }

  /// Test connection with credentials
  static Future<bool> testConnection({
    required String host,
    required int port,
    required String username,
    required String password,
  }) async {
    try {
      final socket = await SSHSocket.connect(host, port);
      final client = SSHClient(
        socket,
        username: username,
        onPasswordRequest: () => password,
      );
      await client.authenticated;
      client.close();
      return true;
    } catch (e) {
      debugPrint('SFTP Test Connection Failed: $e');
      return false;
    }
  }
}
