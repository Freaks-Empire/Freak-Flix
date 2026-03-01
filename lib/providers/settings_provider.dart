// lib/providers/settings_provider.dart
// Settings persistence with secure secret storage for API keys

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/stash_endpoint.dart';
import '../services/persistence_service.dart';
import '../services/secure_key_service.dart';
import '../utils/logger.dart';

enum TmdbKeyStatus {
  unknown,
  valid,
  invalid,
}

class SettingsProvider extends ChangeNotifier {
  static const _key = 'settings_v1';
  static const _tmdbStatusKey = 'tmdbKeyStatus';
  static const _storageFile = 'settings.json';

  bool isDarkMode = true;
  bool preferAniListForAnime = true;
  bool autoFetchAfterScan = true;
  String? lastScannedFolder;
  String tmdbApiKey = '';
  TmdbKeyStatus tmdbStatus = TmdbKeyStatus.unknown;

  bool enableAdultContent = false;
  bool requirePerformerMatch = false;
  String? primaryBackupAccountId;
  List<StashEndpoint> stashEndpoints = [];

  bool _isTestingTmdbKey = false;
  bool get isTestingTmdbKey => _isTestingTmdbKey;
  bool get hasTmdbKey => tmdbApiKey.trim().isNotEmpty;

  bool _hasMigratedProfiles = false;
  bool get hasMigratedProfiles => _hasMigratedProfiles;

  bool _isSetupCompleted = false;
  bool get isSetupCompleted => _isSetupCompleted;

  bool autoBackupEnabled = false;

  bool _coerceAdultOptIn(Object? rawValue) {
    return rawValue is bool ? rawValue : false;
  }

  Future<void> load() async {
    AppLogger.d('Loading settings from file...', tag: 'SettingsProvider');
    try {
      final jsonStr =
          await PersistenceService.instance.loadString(_storageFile);
      if (jsonStr == null) {
        AppLogger.d('No settings file. Checking legacy prefs...',
            tag: 'SettingsProvider');
        await _migrateFromPrefs();

        if (tmdbApiKey.isEmpty) {
          final envKey = _environmentTmdbKey();
          if (envKey.isNotEmpty) {
            await setTmdbApiKey(envKey);
          }
        }
        return;
      }

      final data = jsonDecode(jsonStr) as Map<String, dynamic>;
      final migrated = await _loadFromMap(data);
      if (migrated) {
        await save();
      }
      AppLogger.d('Settings loaded from file', tag: 'SettingsProvider');
    } catch (e) {
      AppLogger.e('Error loading settings: $e',
          error: e, tag: 'SettingsProvider');
      final envKey = _environmentTmdbKey();
      if (envKey.isNotEmpty) {
        await setTmdbApiKey(envKey);
      }
    }
  }

  Future<bool> _loadFromMap(Map<String, dynamic> data) async {
    var migratedLegacySecrets = false;

    isDarkMode = data['isDarkMode'] as bool? ?? true;
    preferAniListForAnime = data['preferAniListForAnime'] as bool? ?? true;
    autoFetchAfterScan = data['autoFetchAfterScan'] as bool? ?? true;
    lastScannedFolder = data['lastScannedFolder'] as String?;
    _hasMigratedProfiles = data['migrated_profiles'] as bool? ?? false;
    _isSetupCompleted = data['isSetupCompleted'] as bool? ?? false;

    final statusIndex = data[_tmdbStatusKey] as int?;
    if (statusIndex != null &&
        statusIndex >= 0 &&
        statusIndex < TmdbKeyStatus.values.length) {
      tmdbStatus = TmdbKeyStatus.values[statusIndex];
    } else {
      tmdbStatus = TmdbKeyStatus.unknown;
    }

    primaryBackupAccountId = data['primaryBackupAccountId'] as String?;
    autoBackupEnabled = data['autoBackupEnabled'] as bool? ?? false;

    enableAdultContent = _coerceAdultOptIn(data['enableAdultContent']);
    requirePerformerMatch = data['requirePerformerMatch'] as bool? ?? false;
    if (!enableAdultContent) {
      requirePerformerMatch = false;
    }

    final legacyTmdbKey = (data['tmdbApiKey'] as String?)?.trim() ?? '';
    if (legacyTmdbKey.isNotEmpty) {
      migratedLegacySecrets =
          await SecureKeyService.migrateLegacyTmdbApiKey(legacyTmdbKey) ||
              migratedLegacySecrets;
    }

    final secureTmdbKey = await SecureKeyService.getTmdbApiKey();
    if (secureTmdbKey.isNotEmpty) {
      tmdbApiKey = secureTmdbKey;
    } else {
      final envKey = _environmentTmdbKey();
      tmdbApiKey = envKey;
      if (envKey.isNotEmpty) {
        await SecureKeyService.setTmdbApiKey(envKey);
      }
    }

    stashEndpoints = _buildEndpointsFromData(data);

    for (final endpoint in stashEndpoints) {
      var secureKey =
          await SecureKeyService.getStashApiKey(endpointId: endpoint.id);
      if (secureKey.isEmpty && endpoint.apiKey.trim().isNotEmpty) {
        migratedLegacySecrets = await SecureKeyService.migrateLegacyStashApiKey(
              endpointId: endpoint.id,
              legacyApiKey: endpoint.apiKey,
            ) ||
            migratedLegacySecrets;
        secureKey =
            await SecureKeyService.getStashApiKey(endpointId: endpoint.id);
      }
      endpoint.apiKey = secureKey;
    }

    return migratedLegacySecrets;
  }

  List<StashEndpoint> _buildEndpointsFromData(Map<String, dynamic> data) {
    if (data['stashEndpoints'] != null) {
      return (data['stashEndpoints'] as List)
          .map((e) => StashEndpoint.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    final legacyUrl = data['stashUrl'] as String?;
    final legacyKey = data['stashApiKey'] as String?;
    if (legacyUrl != null && legacyUrl.isNotEmpty) {
      return [
        StashEndpoint(
          name: 'Default Stash',
          url: legacyUrl,
          apiKey: legacyKey ?? '',
        ),
      ];
    }

    return [
      StashEndpoint(
        name: 'StashDB.org',
        url: 'https://stashdb.org/graphql',
        apiKey: '',
      ),
    ];
  }

  String _environmentTmdbKey() {
    return (dotenv.env['TMDB_API_KEY'] ??
            const String.fromEnvironment('TMDB_API_KEY'))
        .trim();
  }

  Map<String, dynamic> exportState() {
    return {
      'isDarkMode': isDarkMode,
      'preferAniListForAnime': preferAniListForAnime,
      'autoFetchAfterScan': autoFetchAfterScan,
      'lastScannedFolder': lastScannedFolder,
      'migrated_profiles': _hasMigratedProfiles,
      'isSetupCompleted': _isSetupCompleted,
      _tmdbStatusKey: tmdbStatus.index,
      'enableAdultContent': enableAdultContent,
      'requirePerformerMatch': requirePerformerMatch,
      'stashEndpoints': stashEndpoints.map((e) => e.toJson()).toList(),
      'primaryBackupAccountId': primaryBackupAccountId,
      'autoBackupEnabled': autoBackupEnabled,
    };
  }

  Future<void> importState(Map<String, dynamic> data) async {
    await _loadFromMap(data);
    await save();
    notifyListeners();
  }

  Future<void> _migrateFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);

    if (raw == null) return;

    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final migrated = await _loadFromMap(data);
      await save();
      if (migrated) {
        AppLogger.d('Migrated legacy plaintext secrets to secure storage',
            tag: 'SettingsProvider');
      }
      AppLogger.d('Migrated settings from SharedPreferences',
          tag: 'SettingsProvider');
    } catch (e) {
      AppLogger.e('Migration failed: $e', error: e, tag: 'SettingsProvider');
    }
  }

  Future<void> save() async {
    await PersistenceService.instance
        .saveString(_storageFile, jsonEncode(exportState()));
  }

  Future<void> setHasMigratedProfiles(bool val) async {
    _hasMigratedProfiles = val;
    await save();
    notifyListeners();
  }

  Future<void> toggleDarkMode(bool value) async {
    isDarkMode = value;
    await save();
    notifyListeners();
  }

  Future<void> togglePreferAniList(bool value) async {
    preferAniListForAnime = value;
    await save();
    notifyListeners();
  }

  Future<void> completeSetup() async {
    _isSetupCompleted = true;
    await save();
    notifyListeners();
  }

  Future<void> toggleAutoFetch(bool value) async {
    autoFetchAfterScan = value;
    await save();
    notifyListeners();
  }

  Future<void> toggleAdultContent(bool value) async {
    enableAdultContent = value;
    if (!value) {
      requirePerformerMatch = false;
    }
    await save();
    notifyListeners();
  }

  Future<void> toggleRequirePerformerMatch(bool value) async {
    requirePerformerMatch = value;
    await save();
    notifyListeners();
  }

  Future<void> addStashEndpoint(StashEndpoint endpoint) async {
    await SecureKeyService.setStashApiKey(
        endpointId: endpoint.id, apiKey: endpoint.apiKey);
    endpoint.apiKey =
        await SecureKeyService.getStashApiKey(endpointId: endpoint.id);
    stashEndpoints.add(endpoint);
    await save();
    notifyListeners();
  }

  Future<void> removeStashEndpoint(String id) async {
    stashEndpoints.removeWhere((e) => e.id == id);
    await SecureKeyService.deleteStashApiKey(endpointId: id);
    await save();
    notifyListeners();
  }

  Future<void> updateStashEndpoint(StashEndpoint endpoint) async {
    final index = stashEndpoints.indexWhere((e) => e.id == endpoint.id);
    if (index == -1) return;

    final submittedKey = endpoint.apiKey.trim();
    if (submittedKey.isNotEmpty) {
      await SecureKeyService.setStashApiKey(
          endpointId: endpoint.id, apiKey: submittedKey);
    }
    endpoint.apiKey =
        await SecureKeyService.getStashApiKey(endpointId: endpoint.id);

    stashEndpoints[index] = endpoint;
    await save();
    notifyListeners();
  }

  Future<void> reorderStashEndpoints(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final item = stashEndpoints.removeAt(oldIndex);
    stashEndpoints.insert(newIndex, item);
    await save();
    notifyListeners();
  }

  Future<void> setLastFolder(String? path) async {
    lastScannedFolder = path;
    await save();
    notifyListeners();
  }

  Future<void> setTmdbApiKey(String? value) async {
    final normalized = (value?.trim().isEmpty ?? true) ? '' : value!.trim();
    tmdbApiKey = normalized;
    tmdbStatus = TmdbKeyStatus.unknown;

    if (normalized.isEmpty) {
      await SecureKeyService.deleteTmdbApiKey();
    } else {
      await SecureKeyService.setTmdbApiKey(normalized);
    }

    await save();
    notifyListeners();
  }

  Future<void> _setTmdbStatus(TmdbKeyStatus status) async {
    tmdbStatus = status;
    await save();
    notifyListeners();
  }

  Future<void> setPrimaryBackupAccountId(String? id) async {
    primaryBackupAccountId = id;
    await save();
    notifyListeners();
  }

  Future<void> testTmdbKey(Future<bool> Function(String key) validator) async {
    if (!hasTmdbKey) {
      await _setTmdbStatus(TmdbKeyStatus.invalid);
      return;
    }

    _isTestingTmdbKey = true;
    notifyListeners();

    try {
      final ok = await validator(tmdbApiKey);
      await _setTmdbStatus(ok ? TmdbKeyStatus.valid : TmdbKeyStatus.invalid);
    } catch (_) {
      await _setTmdbStatus(TmdbKeyStatus.invalid);
    } finally {
      _isTestingTmdbKey = false;
      notifyListeners();
    }
  }

  Map<String, dynamic> exportSettings() {
    return {
      'isDarkMode': isDarkMode,
      'preferAniListForAnime': preferAniListForAnime,
      'autoFetchAfterScan': autoFetchAfterScan,
      'lastScannedFolder': lastScannedFolder,
      'tmdbStatus': tmdbStatus.index,
      'enableAdultContent': enableAdultContent,
      'stashEndpoints': stashEndpoints.map((e) => e.toJson()).toList(),
      'primaryBackupAccountId': primaryBackupAccountId,
      'autoBackupEnabled': autoBackupEnabled,
    };
  }

  Future<void> importSettings(Map<String, dynamic> data) async {
    if (data.containsKey('isDarkMode')) isDarkMode = data['isDarkMode'];
    if (data.containsKey('preferAniListForAnime')) {
      preferAniListForAnime = data['preferAniListForAnime'];
    }
    if (data.containsKey('autoFetchAfterScan')) {
      autoFetchAfterScan = data['autoFetchAfterScan'];
    }
    if (data.containsKey('lastScannedFolder')) {
      lastScannedFolder = data['lastScannedFolder'];
    }

    if (data.containsKey('tmdbApiKey')) {
      await setTmdbApiKey((data['tmdbApiKey'] as String?) ?? '');
    } else {
      tmdbApiKey = await SecureKeyService.getTmdbApiKey();
    }

    if (data.containsKey('tmdbStatus')) {
      final idx = data['tmdbStatus'] as int;
      if (idx >= 0 && idx < TmdbKeyStatus.values.length) {
        tmdbStatus = TmdbKeyStatus.values[idx];
      }
    }
    enableAdultContent = data.containsKey('enableAdultContent')
        ? _coerceAdultOptIn(data['enableAdultContent'])
        : false;
    if (data.containsKey('requirePerformerMatch')) {
      requirePerformerMatch = data['requirePerformerMatch'] ?? false;
    }
    if (!enableAdultContent) {
      requirePerformerMatch = false;
    }
    if (data.containsKey('stashEndpoints')) {
      final list = data['stashEndpoints'] as List;
      stashEndpoints = list
          .map((e) => StashEndpoint.fromJson(e as Map<String, dynamic>))
          .toList();

      for (final endpoint in stashEndpoints) {
        if (endpoint.apiKey.trim().isNotEmpty) {
          await SecureKeyService.setStashApiKey(
              endpointId: endpoint.id, apiKey: endpoint.apiKey);
        }
        endpoint.apiKey =
            await SecureKeyService.getStashApiKey(endpointId: endpoint.id);
      }
    }
    if (data.containsKey('primaryBackupAccountId')) {
      primaryBackupAccountId = data['primaryBackupAccountId'];
    }
    if (data.containsKey('autoBackupEnabled')) {
      autoBackupEnabled = data['autoBackupEnabled'] ?? false;
    }
    await save();
    notifyListeners();
  }

  Future<void> toggleAutoBackup(bool value) async {
    autoBackupEnabled = value;
    await save();
    notifyListeners();
  }
}
