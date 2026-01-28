/// lib/services/secure_key_service.dart
/// Secure storage service for API keys and sensitive credentials

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class SecureKeyService {
  static const _secureStorage = FlutterSecureStorage();
  
  // Key prefixes for different API types
  static const String _tmdbKeyPrefix = 'api_key_tmdb_';
  static const String _firebaseKeyPrefix = 'api_key_firebase_';
  static const String _stashKeyPrefix = 'api_key_stash_';

  /// Initialize API keys from environment if not already set
  static Future<void> initializeFromEnvironment() async {
    debugPrint('SecureKeyService: Initializing from environment...');
    
    // TMDB API Key
    final tmdbEnvKey = dotenv.env['TMDB_API_KEY'] ?? 
                      const String.fromEnvironment('TMDB_API_KEY');
    if (tmdbEnvKey.isNotEmpty) {
      final currentTmdbKey = await getTmdbApiKey();
      if (currentTmdbKey.isEmpty) {
        await setTmdbApiKey(tmdbEnvKey);
        debugPrint('SecureKeyService: Loaded TMDB API key from environment');
      }
    }

    // Firebase API Keys
    final firebaseApiKey = dotenv.env['FIREBASE_API_KEY'] ?? 
                         const String.fromEnvironment('FIREBASE_API_KEY');
    if (firebaseApiKey.isNotEmpty && 
        firebaseApiKey != 'your_firebase_api_key_here') {
      final currentFirebaseKey = await getFirebaseApiKey();
      if (currentFirebaseKey.isEmpty) {
        await setFirebaseApiKey(firebaseApiKey);
        debugPrint('SecureKeyService: Loaded Firebase API key from environment');
      }
    }

    // Other Firebase config
    final firebaseAppId = dotenv.env['FIREBASE_APP_ID'] ?? 
                         const String.fromEnvironment('FIREBASE_APP_ID');
    if (firebaseAppId.isNotEmpty && 
        firebaseAppId != 'your_firebase_app_id_here') {
      await setFirebaseAppId(firebaseAppId);
    }

    final firebaseProjectId = dotenv.env['FIREBASE_PROJECT_ID'] ?? 
                           const String.fromEnvironment('FIREBASE_PROJECT_ID');
    if (firebaseProjectId.isNotEmpty) {
      await setFirebaseProjectId(firebaseProjectId);
    }
  }

  /// Store TMDB API key securely
  static Future<void> setTmdbApiKey(String apiKey) async {
    await _secureStorage.write(
      key: '$_tmdbKeyPrefix${_getKeySuffix()}',
      value: _encryptKey(apiKey),
    );
    debugPrint('SecureKeyService: TMDB API key stored securely');
  }

  /// Retrieve TMDB API key
  static Future<String> getTmdbApiKey() async {
    try {
      final encrypted = await _secureStorage.read(
        key: '$_tmdbKeyPrefix${_getKeySuffix()}',
      );
      return encrypted != null ? _decryptKey(encrypted) : '';
    } catch (e) {
      debugPrint('SecureKeyService: Error retrieving TMDB key: $e');
      return '';
    }
  }

  /// Delete TMDB API key
  static Future<void> deleteTmdbApiKey() async {
    await _secureStorage.delete(key: '$_tmdbKeyPrefix${_getKeySuffix()}');
    debugPrint('SecureKeyService: TMDB API key deleted');
  }

  /// Store Firebase API key securely
  static Future<void> setFirebaseApiKey(String apiKey) async {
    await _secureStorage.write(
      key: '$_firebaseKeyPrefix${_getKeySuffix()}',
      value: _encryptKey(apiKey),
    );
    debugPrint('SecureKeyService: Firebase API key stored securely');
  }

  /// Retrieve Firebase API key
  static Future<String> getFirebaseApiKey() async {
    try {
      final encrypted = await _secureStorage.read(
        key: '$_firebaseKeyPrefix${_getKeySuffix()}',
      );
      return encrypted != null ? _decryptKey(encrypted) : '';
    } catch (e) {
      debugPrint('SecureKeyService: Error retrieving Firebase API key: $e');
      return '';
    }
  }

  /// Store Firebase App ID securely
  static Future<void> setFirebaseAppId(String appId) async {
    await _secureStorage.write(
      key: '${_firebaseKeyPrefix}app_id_${_getKeySuffix()}',
      value: _encryptKey(appId),
    );
    debugPrint('SecureKeyService: Firebase App ID stored securely');
  }

  /// Retrieve Firebase App ID
  static Future<String> getFirebaseAppId() async {
    try {
      final encrypted = await _secureStorage.read(
        key: '${_firebaseKeyPrefix}app_id_${_getKeySuffix()}',
      );
      return encrypted != null ? _decryptKey(encrypted) : '';
    } catch (e) {
      debugPrint('SecureKeyService: Error retrieving Firebase App ID: $e');
      return '';
    }
  }

  /// Store Firebase Project ID securely
  static Future<void> setFirebaseProjectId(String projectId) async {
    await _secureStorage.write(
      key: '${_firebaseKeyPrefix}project_id_${_getKeySuffix()}',
      value: _encryptKey(projectId),
    );
    debugPrint('SecureKeyService: Firebase Project ID stored securely');
  }

  /// Retrieve Firebase Project ID
  static Future<String> getFirebaseProjectId() async {
    try {
      final encrypted = await _secureStorage.read(
        key: '${_firebaseKeyPrefix}project_id_${_getKeySuffix()}',
      );
      return encrypted != null ? _decryptKey(encrypted) : '';
    } catch (e) {
      debugPrint('SecureKeyService: Error retrieving Firebase Project ID: $e');
      return '';
    }
  }

  /// Delete all API keys (for logout/reset)
  static Future<void> deleteAllKeys() async {
    try {
      await _secureStorage.deleteAll();
      debugPrint('SecureKeyService: All API keys deleted');
    } catch (e) {
      debugPrint('SecureKeyService: Error deleting all keys: $e');
    }
  }

  /// Validate and sanitize API key format
  static String? validateApiKey(String? apiKey, {String? serviceName}) {
    if (apiKey == null || apiKey.trim().isEmpty) {
      return '${serviceName ?? 'API'} key is required';
    }

    final trimmed = apiKey.trim();

    // Basic length validation
    if (trimmed.length < 8) {
      return 'API key too short (minimum 8 characters)';
    }
    if (trimmed.length > 500) {
      return 'API key too long (maximum 500 characters)';
    }

    // Check for common placeholder values
    final placeholders = [
      'your_api_key_here',
      'your_firebase_api_key_here',
      'your_firebase_app_id_here',
      'api_key_here',
      'key_here',
      'your_key_here',
      'your_api_key',
      'api_key',
      'key',
    ];
    
    if (placeholders.contains(trimmed.toLowerCase())) {
      return 'Please replace placeholder API key with actual key';
    }

    // Check for invalid characters
    final pattern1 = RegExp(r'[<>{}]', caseSensitive: false);
    if (pattern1.hasMatch(trimmed)) {
      return 'API key contains invalid characters';
    }

    // Check for quotes and backticks
    final pattern2 = RegExp('["\'`]', caseSensitive: false);
    if (pattern2.hasMatch(trimmed)) {
      return 'API key contains invalid characters';
    }

    // Check for control characters
    final controlPattern = RegExp(r'[\x00-\x1F\x7F]');
    if (controlPattern.hasMatch(trimmed)) {
      return 'API key contains invalid characters';
    }

    // Check for URL patterns
    final urlPattern = RegExp(r'https?://', caseSensitive: false);
    if (urlPattern.hasMatch(trimmed)) {
      return 'API key should not include URLs';
    }

    return null;
  }

  /// Check if API key looks like a test/dev key
  static bool isTestKey(String apiKey) {
    final testPatterns = [
      RegExp('test', caseSensitive: false),
      RegExp('dev', caseSensitive: false),
      RegExp('demo', caseSensitive: false),
      RegExp('example', caseSensitive: false),
      RegExp('sample', caseSensitive: false),
    ];

    return testPatterns.any((pattern) => pattern.hasMatch(apiKey));
  }

  /// Generate a unique suffix for key storage (app instance)
  static String _getKeySuffix() {
    // Use app installation ID or device ID for uniqueness
    // For now, using a fixed suffix, but could be device-specific
    return 'default';
  }

  /// Basic encryption for API keys (XOR with a simple key)
  static String _encryptKey(String key) {
    try {
      final bytes = utf8.encode(key);
      const xorKey = 'FreakFlixSecure2024'; // Simple XOR key
      final keyBytes = utf8.encode(xorKey);
      
      final encrypted = List<int>.generate(bytes.length, (i) => 
          bytes[i] ^ keyBytes[i % keyBytes.length]);
      
      return base64Encode(encrypted);
    } catch (e) {
      debugPrint('SecureKeyService: Encryption error: $e');
      return key; // Fallback to unencrypted
    }
  }

  /// Basic decryption for API keys
  static String _decryptKey(String encryptedKey) {
    try {
      final encrypted = base64Decode(encryptedKey);
      const xorKey = 'FreakFlixSecure2024'; // Must match encryption key
      final keyBytes = utf8.encode(xorKey);
      
      final decrypted = List<int>.generate(encrypted.length, (i) => 
          encrypted[i] ^ keyBytes[i % keyBytes.length]);
      
      return utf8.decode(decrypted);
    } catch (e) {
      debugPrint('SecureKeyService: Decryption error: $e');
      return encryptedKey; // Fallback to original
    }
  }

  /// Mask API key for display/logging
  static String maskApiKey(String apiKey) {
    if (apiKey.isEmpty) return '[empty]';
    if (apiKey.length <= 8) return '****';
    return '${apiKey.substring(0, 4)}****${apiKey.substring(apiKey.length - 4)}';
  }

  /// Check if any API keys are stored
  static Future<bool> hasStoredKeys() async {
    final tmdbKey = await getTmdbApiKey();
    final firebaseKey = await getFirebaseApiKey();
    
    return tmdbKey.isNotEmpty || firebaseKey.isNotEmpty;
  }

  /// Get security audit info for stored keys
  static Future<Map<String, dynamic>> getSecurityAudit() async {
    final tmdbKey = await getTmdbApiKey();
    final firebaseKey = await getFirebaseApiKey();
    
    return {
      'tmdb_key_stored': tmdbKey.isNotEmpty,
      'tmdb_key_length': tmdbKey.length,
      'tmdb_key_is_test': tmdbKey.isNotEmpty ? isTestKey(tmdbKey) : false,
      'firebase_key_stored': firebaseKey.isNotEmpty,
      'firebase_key_length': firebaseKey.length,
      'firebase_key_is_test': firebaseKey.isNotEmpty ? isTestKey(firebaseKey) : false,
      'storage_method': 'flutter_secure_storage',
      'encryption_enabled': true,
    };
  }
}