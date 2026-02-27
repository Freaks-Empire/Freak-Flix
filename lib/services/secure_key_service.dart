// lib/services/secure_key_service.dart
// Platform-secure storage service for API keys and sensitive credentials

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../utils/secure_logger.dart';

class SecureKeyService {
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  static const String _tmdbKey = 'secret.tmdb';
  static const String _stashKeyPrefix = 'secret.stash.';

  static String _stashKey(String endpointId) => '$_stashKeyPrefix$endpointId';

  /// Store TMDB API key securely.
  static Future<void> setTmdbApiKey(String apiKey) async {
    final value = apiKey.trim();
    if (value.isEmpty) {
      await deleteTmdbApiKey();
      return;
    }
    await _secureStorage.write(key: _tmdbKey, value: value);
    SecureLogger.debug('TMDB API key stored securely', 'SecureKeyService');
  }

  /// Retrieve TMDB API key.
  static Future<String> getTmdbApiKey() async {
    try {
      return (await _secureStorage.read(key: _tmdbKey)) ?? '';
    } catch (e) {
      SecureLogger.error('Error retrieving TMDB key', e, 'SecureKeyService');
      return '';
    }
  }

  /// Delete TMDB API key.
  static Future<void> deleteTmdbApiKey() async {
    await _secureStorage.delete(key: _tmdbKey);
    SecureLogger.debug('TMDB API key deleted', 'SecureKeyService');
  }

  /// Store Stash endpoint API key securely.
  static Future<void> setStashApiKey({
    required String endpointId,
    required String apiKey,
  }) async {
    final value = apiKey.trim();
    if (value.isEmpty) {
      await deleteStashApiKey(endpointId: endpointId);
      return;
    }
    await _secureStorage.write(key: _stashKey(endpointId), value: value);
    SecureLogger.debug('Stash API key stored securely', 'SecureKeyService');
  }

  /// Retrieve Stash endpoint API key.
  static Future<String> getStashApiKey({required String endpointId}) async {
    try {
      return (await _secureStorage.read(key: _stashKey(endpointId))) ?? '';
    } catch (e) {
      SecureLogger.error('Error retrieving Stash API key', e, 'SecureKeyService');
      return '';
    }
  }

  /// Delete Stash endpoint API key.
  static Future<void> deleteStashApiKey({required String endpointId}) async {
    await _secureStorage.delete(key: _stashKey(endpointId));
    SecureLogger.debug('Stash API key deleted', 'SecureKeyService');
  }

  /// Migrate a legacy plaintext TMDB key into secure storage.
  static Future<bool> migrateLegacyTmdbApiKey(String? legacyApiKey) async {
    final value = legacyApiKey?.trim() ?? '';
    if (value.isEmpty) return false;

    final existing = await getTmdbApiKey();
    if (existing.isNotEmpty) return false;

    await setTmdbApiKey(value);
    SecureLogger.debug('Migrated legacy TMDB key to secure storage', 'SecureKeyService');
    return true;
  }

  /// Migrate a legacy plaintext Stash endpoint key into secure storage.
  static Future<bool> migrateLegacyStashApiKey({
    required String endpointId,
    required String? legacyApiKey,
  }) async {
    final value = legacyApiKey?.trim() ?? '';
    if (value.isEmpty) return false;

    final existing = await getStashApiKey(endpointId: endpointId);
    if (existing.isNotEmpty) return false;

    await setStashApiKey(endpointId: endpointId, apiKey: value);
    SecureLogger.debug('Migrated legacy Stash key to secure storage', 'SecureKeyService');
    return true;
  }

  /// Delete all known secure keys managed by this service.
  static Future<void> deleteAllKeys() async {
    try {
      final all = await _secureStorage.readAll();
      for (final key in all.keys) {
        if (key == _tmdbKey || key.startsWith(_stashKeyPrefix)) {
          await _secureStorage.delete(key: key);
        }
      }
      SecureLogger.debug('All managed API keys deleted', 'SecureKeyService');
    } catch (e) {
      SecureLogger.error('Error deleting all keys', e, 'SecureKeyService');
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

  /// Mask API key for display/logging
  static String maskApiKey(String apiKey) {
    if (apiKey.isEmpty) return '[empty]';
    if (apiKey.length <= 8) return '****';
    return '${apiKey.substring(0, 4)}****${apiKey.substring(apiKey.length - 4)}';
  }

  /// Check if any API keys are stored
  static Future<bool> hasStoredKeys() async {
    final tmdbKey = await getTmdbApiKey();
    final all = await _secureStorage.readAll();
    final hasStashKeys = all.keys.any((key) => key.startsWith(_stashKeyPrefix));
    
    return tmdbKey.isNotEmpty || hasStashKeys;
  }

  /// Get security audit info for stored keys
  static Future<Map<String, dynamic>> getSecurityAudit() async {
    final tmdbKey = await getTmdbApiKey();
    final all = await _secureStorage.readAll();
    final stashKeys = all.entries
        .where((entry) => entry.key.startsWith(_stashKeyPrefix) && (entry.value).trim().isNotEmpty)
        .map((entry) => entry.value)
        .toList();
    final firstStashKey = stashKeys.isNotEmpty ? stashKeys.first : '';
    
    return {
      'tmdb_key_stored': tmdbKey.isNotEmpty,
      'tmdb_key_length': tmdbKey.length,
      'tmdb_key_is_test': tmdbKey.isNotEmpty ? isTestKey(tmdbKey) : false,
      'stash_key_stored': stashKeys.isNotEmpty,
      'stash_key_count': stashKeys.length,
      'stash_key_length': firstStashKey.length,
      'stash_key_is_test': firstStashKey.isNotEmpty ? isTestKey(firstStashKey) : false,
      'storage_method': 'flutter_secure_storage',
      'platform_managed_encryption': true,
    };
  }
}
