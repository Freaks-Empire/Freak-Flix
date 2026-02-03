/// lib/services/webdav_client_wrapper.dart
/// WebDAV client implementation using webdav_client

import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:webdav_client/webdav_client.dart' as webdav;
import 'remote_storage_service.dart';
import '../utils/input_validation.dart';
import '../utils/secure_logger.dart';

/// WebDAV client for browsing and streaming files
class WebDavClientWrapper {
  final RemoteStorageAccount account;
  webdav.Client? _client;
  String? _password;

  WebDavClientWrapper(this.account);

  /// Connect to the WebDAV server
  Future<bool> connect(String password) async {
    try {
      _password = password;
      
      // Validate connection parameters
      final urlValidation = InputValidation.validateWebDavUrl(account.host);
      if (urlValidation != null) {
        debugPrint('WebDAV: Invalid URL - $urlValidation');
        return false;
      }
      
      final portValidation = InputValidation.validatePort(account.port.toString());
      if (portValidation != null) {
        debugPrint('WebDAV: Invalid port - $portValidation');
        return false;
      }
      
      // SECURITY: Always use HTTPS for secure connections
      final scheme = 'https';
      final baseUrl = '$scheme://${account.host}:${account.port}';
      
      SecureLogger.debug('Connecting to sanitized URL', 'WebDAV');
      
      _client = webdav.newClient(
        baseUrl,
        user: account.username,
        password: password,
        debug: kDebugMode,
      );
      
      // Test connection by reading root
      await _client!.readDir('/');
      SecureLogger.debug('Connected to host', 'WebDAV');
      return true;
    } catch (e) {
      SecureLogger.error('Connection error', e, 'WebDAV');
      return false;
    }
  }

  /// List files in a directory
  Future<List<RemoteFile>> listDirectory(String path) async {
    if (_client == null) {
      throw Exception('Not connected');
    }

    final normalizedPath = path.isEmpty ? '/' : path;
    final items = await _client!.readDir(normalizedPath);
    
    return items
        .where((item) => item.name != null && item.name!.isNotEmpty)
        .map((item) => RemoteFile(
              name: item.name ?? '',
              path: item.path ?? normalizedPath,
              isDirectory: item.isDir ?? false,
              size: item.size,
              modifiedTime: item.mTime,
            ))
        .toList();
  }

  /// Get a direct URL for streaming (WebDAV supports HTTP URLs)
  String? getStreamUrl(String remotePath) {
    if (_client == null || _password == null) return null;
    
    // SECURITY: Always use HTTPS for secure connections
    final scheme = 'https';
    // Include auth in URL for direct access
    return '$scheme://${account.username}:$_password@${account.host}:${account.port}$remotePath';
  }

  /// Download file content as bytes
  Future<Uint8List> downloadFile(String remotePath) async {
    if (_client == null) {
      throw Exception('Not connected');
    }

    final bytes = await _client!.read(remotePath);
    return Uint8List.fromList(bytes);
  }

  /// Check if path is a directory
  Future<bool> isDirectory(String path) async {
    if (_client == null) return false;
    
    try {
      await _client!.readDir(path);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Disconnect (WebDAV is stateless, just clear refs)
  void disconnect() {
    _client = null;
    _password = null;
    debugPrint('WebDAV: Disconnected');
  }

  /// Test connection with credentials
  static Future<bool> testConnection({
    required String host,
    required int port,
    required String username,
    required String password,
  }) async {
    try {
      // SECURITY: Always use HTTPS for secure connections
      final scheme = 'https';
      final baseUrl = '$scheme://$host:$port';
      
      final client = webdav.newClient(
        baseUrl,
        user: username,
        password: password,
      );
      
      await client.readDir('/');
      return true;
    } catch (e) {
      SecureLogger.error('Test connection failed', e, 'WebDAV');
      return false;
    }
  }
}
