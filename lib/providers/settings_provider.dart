/// lib/providers/settings_provider.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/persistence_service.dart';
import '../models/stash_endpoint.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../services/sync_service.dart';
import 'dart:async';

enum TmdbKeyStatus {
  unknown,
  valid,
  invalid,
}

class SettingsProvider extends ChangeNotifier {
  static const _key = 'settings_v1';
  static const _tmdbStatusKey = 'tmdbKeyStatus';

  bool isDarkMode = true;
  bool preferAniListForAnime = true;
  bool autoFetchAfterScan = true;
  String? lastScannedFolder;
  String tmdbApiKey = '';
  TmdbKeyStatus tmdbStatus = TmdbKeyStatus.unknown;
  
  bool enableAdultContent = false;
  bool requirePerformerMatch = false;
  String? primaryBackupAccountId; 
  Timer? _debounceSync;
  // Legacy single fields replaced by stashEndpoints
  // String stashApiKey = '';
  // String stashUrl = 'https://stashdb.org/graphql';
  List<StashEndpoint> stashEndpoints = [];

  bool _isTestingTmdbKey = false;

  bool get isTestingTmdbKey => _isTestingTmdbKey;
  bool get hasTmdbKey => tmdbApiKey.trim().isNotEmpty;
  
  bool _hasMigratedProfiles = false;
  bool get hasMigratedProfiles => _hasMigratedProfiles;

  Future<void> setHasMigratedProfiles(bool val) async {
    _hasMigratedProfiles = val;
    await save();
    notifyListeners();
  }

  static const _storageFile = 'settings.json';

  Future<void> load() async {
    debugPrint('SettingsProvider: Loading settings from file...');
    try {
      final jsonStr = await PersistenceService.instance.loadString(_storageFile);
      if (jsonStr == null) {
        debugPrint('SettingsProvider: No settings file. Checking legacy prefs...');
        await _migrateFromPrefs();
        // Even if migration happens, we fall through to defaults if needed or return
        // Ideally _migrateFromPrefs sets values.
        
        // If still defaults (i.e. first run ever), check env
        if (tmdbApiKey.isEmpty) {
             tmdbApiKey = dotenv.env['TMDB_API_KEY'] ?? 
                   const String.fromEnvironment('TMDB_API_KEY');
        }
        return;
      }

      final data = jsonDecode(jsonStr) as Map<String, dynamic>;
      _loadFromMap(data);
       debugPrint('SettingsProvider: Settings loaded from file.');
    } catch (e) {
      debugPrint('SettingsProvider: Error loading settings: $e');
      // basic fallback
      tmdbApiKey = dotenv.env['TMDB_API_KEY'] ?? 
                   const String.fromEnvironment('TMDB_API_KEY');
    }
  }

  void _loadFromMap(Map<String, dynamic> data) {
    isDarkMode = data['isDarkMode'] as bool? ?? true;
    preferAniListForAnime = data['preferAniListForAnime'] as bool? ?? true;
    autoFetchAfterScan = data['autoFetchAfterScan'] as bool? ?? true;
    lastScannedFolder = data['lastScannedFolder'] as String?;
    _hasMigratedProfiles = data['migrated_profiles'] as bool? ?? false;
    _isSetupCompleted = data['isSetupCompleted'] as bool? ?? false;
    
    String? savedKey = data['tmdbApiKey'] as String?;
    if (savedKey == null || savedKey.trim().isEmpty) {
      savedKey = dotenv.env['TMDB_API_KEY'] ?? 
                 const String.fromEnvironment('TMDB_API_KEY');
    }
    tmdbApiKey = savedKey;

    final statusIndex = data[_tmdbStatusKey] as int?;
    if (statusIndex != null && statusIndex >= 0 && statusIndex < TmdbKeyStatus.values.length) {
      tmdbStatus = TmdbKeyStatus.values[statusIndex];
    } else {
      tmdbStatus = TmdbKeyStatus.unknown;
    }
    
    primaryBackupAccountId = data['primaryBackupAccountId'] as String?;

    enableAdultContent = data['enableAdultContent'] as bool? ?? false;
    requirePerformerMatch = data['requirePerformerMatch'] as bool? ?? false;
    
    // Load endpoints
    if (data['stashEndpoints'] != null) {
      stashEndpoints = (data['stashEndpoints'] as List)
          .map((e) => StashEndpoint.fromJson(e))
          .toList();
    }
    
    // Migration: If no endpoints but legacy data exists
    if (stashEndpoints.isEmpty) {
      final legacyUrl = data['stashUrl'] as String?;
      final legacyKey = data['stashApiKey'] as String?;
      if (legacyUrl != null && legacyUrl.isNotEmpty) {
        stashEndpoints.add(StashEndpoint(
          name: 'Default Stash',
          url: legacyUrl,
          apiKey: legacyKey ?? '',
        ));
      } else {
        // Add default StashDB.org if completely empty/fresh
        stashEndpoints.add(StashEndpoint(
           name: 'StashDB.org',
           url: 'https://stashdb.org/graphql',
           apiKey: '',
        ));
      }
    }
  }

  Map<String, dynamic> exportState() {
    return {
      'isDarkMode': isDarkMode,
      'preferAniListForAnime': preferAniListForAnime,
      'autoFetchAfterScan': autoFetchAfterScan,
      'lastScannedFolder': lastScannedFolder,
      'migrated_profiles': _hasMigratedProfiles,
      'isSetupCompleted': _isSetupCompleted,
      'tmdbApiKey': tmdbApiKey,
      'enableAdultContent': enableAdultContent,
      'requirePerformerMatch': requirePerformerMatch,
      'stashEndpoints': stashEndpoints.map((e) => e.toJson()).toList(),
      'primaryBackupAccountId': primaryBackupAccountId,
    };
  }

  Future<void> importState(Map<String, dynamic> data) async {
    _loadFromMap(data);
    await save();
    notifyListeners();
  }

  Future<void> _migrateFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    
    if (raw == null) return;
    
    try {
       final data = jsonDecode(raw) as Map<String, dynamic>;
       _loadFromMap(data);
       await save();
       debugPrint('SettingsProvider: Migrated settings from SharedPreferences.');
    } catch (e) {
       debugPrint('SettingsProvider: Migration failed: $e');
    }
  }

  Future<void> save() async {
    final data = {
        'isDarkMode': isDarkMode,
        'preferAniListForAnime': preferAniListForAnime,
        'autoFetchAfterScan': autoFetchAfterScan,
        'lastScannedFolder': lastScannedFolder,
        'tmdbApiKey': tmdbApiKey,
        _tmdbStatusKey: tmdbStatus.index,
        'enableAdultContent': enableAdultContent,
        'requirePerformerMatch': requirePerformerMatch,
        'stashEndpoints': stashEndpoints.map((e) => e.toJson()).toList(),
        'migrated_profiles': _hasMigratedProfiles,
        'isSetupCompleted': _isSetupCompleted,
        'primaryBackupAccountId': primaryBackupAccountId,
    };
    await PersistenceService.instance.saveString(_storageFile, jsonEncode(data));
    
    // Cloud Sync (Debounced)
    _debounceSync?.cancel();
    _debounceSync = Timer(const Duration(seconds: 3), () {
       SyncService().pushUpdate(data);
    });
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

  bool _isSetupCompleted = false;
  bool get isSetupCompleted => _isSetupCompleted;

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
    await save();
    notifyListeners();
  }

  Future<void> toggleRequirePerformerMatch(bool value) async {
    requirePerformerMatch = value;
    await save();
    notifyListeners();
  }

  Future<void> addStashEndpoint(StashEndpoint endpoint) async {
    stashEndpoints.add(endpoint);
    await save();
    notifyListeners();
  }

  Future<void> removeStashEndpoint(String id) async {
    stashEndpoints.removeWhere((e) => e.id == id);
    await save();
    notifyListeners();
  }

  Future<void> updateStashEndpoint(StashEndpoint endpoint) async {
    final index = stashEndpoints.indexWhere((e) => e.id == endpoint.id);
    if (index != -1) {
      stashEndpoints[index] = endpoint;
      await save();
      notifyListeners();
      notifyListeners();
    }
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
    tmdbApiKey = (value?.trim().isEmpty ?? true) ? '' : value!.trim();
    tmdbStatus = TmdbKeyStatus.unknown;
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
      'tmdbApiKey': tmdbApiKey,
      'tmdbStatus': tmdbStatus.index,
      'enableAdultContent': enableAdultContent,
      'stashEndpoints': stashEndpoints.map((e) => e.toJson()).toList(),
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
    if (data.containsKey('tmdbApiKey')) tmdbApiKey = data['tmdbApiKey'] ?? '';
    if (data.containsKey('tmdbStatus')) {
      final idx = data['tmdbStatus'] as int;
      if (idx >= 0 && idx < TmdbKeyStatus.values.length) {
        tmdbStatus = TmdbKeyStatus.values[idx];
      }
    }
    if (data.containsKey('enableAdultContent')) {
      enableAdultContent = data['enableAdultContent'] ?? false;
    }
    if (data.containsKey('stashEndpoints')) {
       final list = data['stashEndpoints'] as List;
       stashEndpoints = list.map((e) => StashEndpoint.fromJson(e)).toList();
    }
    if (data.containsKey('primaryBackupAccountId')) {
      primaryBackupAccountId = data['primaryBackupAccountId'];
    }
    await save();
    notifyListeners();
  }
}