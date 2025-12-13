import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  bool _isTestingTmdbKey = false;

  bool get isTestingTmdbKey => _isTestingTmdbKey;
  bool get hasTmdbKey => tmdbApiKey.trim().isNotEmpty;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return;
    final data = jsonDecode(raw) as Map<String, dynamic>;
    isDarkMode = data['isDarkMode'] as bool? ?? true;
    preferAniListForAnime = data['preferAniListForAnime'] as bool? ?? true;
    autoFetchAfterScan = data['autoFetchAfterScan'] as bool? ?? true;
    lastScannedFolder = data['lastScannedFolder'] as String?;
    tmdbApiKey = data['tmdbApiKey'] as String? ?? '';
    final statusIndex = data[_tmdbStatusKey] as int?;
    if (statusIndex != null && statusIndex >= 0 && statusIndex < TmdbKeyStatus.values.length) {
      tmdbStatus = TmdbKeyStatus.values[statusIndex];
    } else {
      tmdbStatus = TmdbKeyStatus.unknown;
    }
    notifyListeners();
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode({
        'isDarkMode': isDarkMode,
        'preferAniListForAnime': preferAniListForAnime,
        'autoFetchAfterScan': autoFetchAfterScan,
        'lastScannedFolder': lastScannedFolder,
        'tmdbApiKey': tmdbApiKey,
        _tmdbStatusKey: tmdbStatus.index,
      }),
    );
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

  Future<void> toggleAutoFetch(bool value) async {
    autoFetchAfterScan = value;
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
    await save();
    notifyListeners();
  }
}