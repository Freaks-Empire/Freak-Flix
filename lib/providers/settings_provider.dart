import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  static const _key = 'settings_v1';

  bool isDarkMode = true;
  bool preferAniListForAnime = true;
  bool autoFetchAfterScan = true;
  String? lastScannedFolder;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return;
    final data = jsonDecode(raw) as Map<String, dynamic>;
    isDarkMode = data['isDarkMode'] as bool? ?? true;
    preferAniListForAnime = data['preferAniListForAnime'] as bool? ?? true;
    autoFetchAfterScan = data['autoFetchAfterScan'] as bool? ?? true;
    lastScannedFolder = data['lastScannedFolder'] as String?;
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
}