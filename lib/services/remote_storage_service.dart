/// lib/services/remote_storage_service.dart
/// Unified service for managing SFTP, FTP, and WebDAV connections

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Types of remote storage protocols supported
enum RemoteStorageType { sftp, ftp, webdav }

/// Represents a connected remote storage account
class RemoteStorageAccount {
  final String id;
  final RemoteStorageType type;
  final String host;
  final int port;
  final String username;
  final String displayName;
  final String? basePath; // Optional base path for browsing
  
  RemoteStorageAccount({
    required this.id,
    required this.type,
    required this.host,
    required this.port,
    required this.username,
    required this.displayName,
    this.basePath,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'host': host,
    'port': port,
    'username': username,
    'displayName': displayName,
    'basePath': basePath,
  };

  factory RemoteStorageAccount.fromJson(Map<String, dynamic> json) {
    return RemoteStorageAccount(
      id: json['id'] as String,
      type: RemoteStorageType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => RemoteStorageType.sftp,
      ),
      host: json['host'] as String,
      port: json['port'] as int,
      username: json['username'] as String,
      displayName: json['displayName'] as String,
      basePath: json['basePath'] as String?,
    );
  }

  /// Default ports for each protocol
  static int defaultPort(RemoteStorageType type) {
    switch (type) {
      case RemoteStorageType.sftp:
        return 22;
      case RemoteStorageType.ftp:
        return 21;
      case RemoteStorageType.webdav:
        return 443;
    }
  }

  /// Protocol prefix for folder paths
  String get protocolPrefix => '${type.name}:$id';
}

/// Represents a file/folder in remote storage
class RemoteFile {
  final String name;
  final String path;
  final bool isDirectory;
  final int? size;
  final DateTime? modifiedTime;

  RemoteFile({
    required this.name,
    required this.path,
    required this.isDirectory,
    this.size,
    this.modifiedTime,
  });
}

/// Singleton service for managing all remote storage accounts
class RemoteStorageService extends ChangeNotifier {
  static final RemoteStorageService _instance = RemoteStorageService._internal();
  static RemoteStorageService get instance => _instance;
  factory RemoteStorageService() => _instance;
  RemoteStorageService._internal();

  static const String _accountsKey = 'remote_storage_accounts';
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  
  final List<RemoteStorageAccount> _accounts = [];
  List<RemoteStorageAccount> get accounts => List.unmodifiable(_accounts);

  /// Get accounts filtered by type
  List<RemoteStorageAccount> accountsByType(RemoteStorageType type) {
    return _accounts.where((a) => a.type == type).toList();
  }

  /// Load accounts from storage
  Future<void> loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_accountsKey);
      if (jsonStr != null) {
        final List<dynamic> jsonList = jsonDecode(jsonStr);
        _accounts.clear();
        for (final json in jsonList) {
          _accounts.add(RemoteStorageAccount.fromJson(json as Map<String, dynamic>));
        }
        debugPrint('RemoteStorageService: Loaded ${_accounts.length} accounts');
      }
    } catch (e) {
      debugPrint('RemoteStorageService: Error loading accounts: $e');
    }
    notifyListeners();
  }

  /// Save accounts to storage
  Future<void> _saveToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = jsonEncode(_accounts.map((a) => a.toJson()).toList());
      await prefs.setString(_accountsKey, jsonStr);
    } catch (e) {
      debugPrint('RemoteStorageService: Error saving accounts: $e');
    }
  }

  /// Add a new account with secure password storage
  Future<void> addAccount(RemoteStorageAccount account, String password) async {
    // Store password securely
    await _secureStorage.write(
      key: 'remote_pass_${account.id}',
      value: password,
    );
    
    _accounts.add(account);
    await _saveToPrefs();
    notifyListeners();
    debugPrint('RemoteStorageService: Added ${account.type.name} account: ${account.displayName}');
  }

  /// Remove an account and its stored credentials
  Future<void> removeAccount(String accountId) async {
    await _secureStorage.delete(key: 'remote_pass_$accountId');
    // Also delete any private key if stored
    await _secureStorage.delete(key: 'remote_key_$accountId');
    
    _accounts.removeWhere((a) => a.id == accountId);
    await _saveToPrefs();
    notifyListeners();
    debugPrint('RemoteStorageService: Removed account $accountId');
  }

  /// Get stored password for an account
  Future<String?> getPassword(String accountId) async {
    return await _secureStorage.read(key: 'remote_pass_$accountId');
  }

  /// Store SSH private key for SFTP
  Future<void> storePrivateKey(String accountId, String privateKey) async {
    await _secureStorage.write(key: 'remote_key_$accountId', value: privateKey);
  }

  /// Get stored private key for SFTP
  Future<String?> getPrivateKey(String accountId) async {
    return await _secureStorage.read(key: 'remote_key_$accountId');
  }

  /// Find account by ID
  RemoteStorageAccount? getAccount(String accountId) {
    try {
      return _accounts.firstWhere((a) => a.id == accountId);
    } catch (_) {
      return null;
    }
  }

  /// Check if a protocol is supported on current platform
  static bool isProtocolSupported(RemoteStorageType type) {
    if (kIsWeb) {
      // Web only supports WebDAV (HTTP-based)
      return type == RemoteStorageType.webdav;
    }
    return true;
  }
}
