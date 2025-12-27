/// lib/providers/profile_provider.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/user_profile.dart';
import '../services/persistence_service.dart';

class ProfileProvider extends ChangeNotifier {
  static const _profilesFile = 'profiles.json';
  
  List<UserProfile> profiles = [];
  UserProfile? _activeProfile;
  Map<String, UserMediaData> _userData = {};
  
  bool isLoading = true;

  UserProfile? get activeProfile => _activeProfile;
  Map<String, UserMediaData> get userData => _userData;

  Future<void> load() async {
    isLoading = true;
    notifyListeners();

    try {
      final jsonStr = await PersistenceService.instance.loadString(_profilesFile);
      if (jsonStr != null) {
        final List<dynamic> list = jsonDecode(jsonStr);
        profiles = list.map((e) => UserProfile.fromJson(e)).toList();
      } else {
        // First run or empty: Do nothing. Setup wizard will handle creation.
        profiles = []; 
      }
    } catch (e) {
      debugPrint('ProfileProvider: Error loading profiles: $e');
      // Fallback
      profiles = [
        const UserProfile(
          id: 'default',
          name: 'Default',
          avatarId: 'default',
          colorValue: 0xFF2196F3,
        )
      ];
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> selectProfile(String profileId) async {
    _activeProfile = profiles.firstWhere(
      (p) => p.id == profileId,
      orElse: () => profiles.first,
    );
    await _loadUserData(_activeProfile!.id);
    notifyListeners();
  }

  void deselectProfile() {
    _activeProfile = null;
    _userData = {};
    notifyListeners();
  }

  Future<void> _loadUserData(String profileId) async {
    _userData = {};
    try {
      final fileName = 'profile_${profileId}_data.json';
      final jsonStr = await PersistenceService.instance.loadString(fileName);
      if (jsonStr != null) {
        final Map<String, dynamic> map = jsonDecode(jsonStr);
        _userData = map.map((key, value) => MapEntry(key, UserMediaData.fromJson(value)));
      }
    } catch (e) {
      debugPrint('ProfileProvider: Error loading user data for $profileId: $e');
    }
  }

  Future<void> _saveUserData() async {
    if (_activeProfile == null) return;
    try {
      final fileName = 'profile_${_activeProfile!.id}_data.json';
      final jsonStr = jsonEncode(_userData.map((k, v) => MapEntry(k, v.toJson())));
      await PersistenceService.instance.saveString(fileName, jsonStr);
    } catch (e) {
      debugPrint('ProfileProvider: Error saving user data: $e');
    }
  }

  Future<void> _saveProfiles() async {
    try {
      final jsonStr = jsonEncode(profiles.map((p) => p.toJson()).toList());
      await PersistenceService.instance.saveString(_profilesFile, jsonStr);
    } catch (e) {
      debugPrint('ProfileProvider: Error saving profiles: $e');
    }
  }

  Future<void> addProfile(String name, String avatarId, int colorValue, {List<String>? allowedFolderIds, String? pin}) async {
    final newProfile = UserProfile(
      id: const Uuid().v4(),
      name: name,
      avatarId: avatarId,
      colorValue: colorValue,
      allowedFolderIds: allowedFolderIds,
      pin: pin,
    );
    profiles.add(newProfile);
    await _saveProfiles();
    notifyListeners();
  }

  Future<void> updateProfile(UserProfile updated) async {
    final idx = profiles.indexWhere((p) => p.id == updated.id);
    if (idx >= 0) {
      profiles[idx] = updated;
      if (_activeProfile?.id == updated.id) {
        _activeProfile = updated;
      }
      await _saveProfiles();
      notifyListeners();
    }
  }

  Future<void> deleteProfile(String profileId) async {
    profiles.removeWhere((p) => p.id == profileId);
    if (_activeProfile?.id == profileId) {
      _activeProfile = null;
      _userData = {};
    }
    await _saveProfiles();
    notifyListeners();
  }

  // --- Watch History Methods ---

  void updateProgress(String mediaId, int positionSeconds, {bool isWatched = false}) {
    final now = DateTime.now();
    _userData[mediaId] = UserMediaData(
      mediaId: mediaId,
      positionSeconds: positionSeconds,
      isWatched: isWatched,
      lastUpdated: now,
    );
    _saveUserData(); // Fire and forget save
    notifyListeners();
  }

  Future<void> importUserData(Map<String, UserMediaData> data) async {
    if (_activeProfile == null) return;
    _userData.addAll(data);
    await _saveUserData();
    notifyListeners();
  }

  UserMediaData? getDataFor(String mediaId) {
    return _userData[mediaId];
  }

  // --- Export/Import ---

  Future<Map<String, dynamic>> exportState() async {
    // We need to export all profiles AND their individual data files.
    final profilesJson = profiles.map((p) => p.toJson()).toList();
    
    // For each profile, load its data and add to export
    final allUserData = <String, Map<String, dynamic>>{};
    
    for (final p in profiles) {
      final fileName = 'profile_${p.id}_data.json';
      final jsonStr = await PersistenceService.instance.loadString(fileName);
      if (jsonStr != null) {
        allUserData[p.id] = jsonDecode(jsonStr);
      } else {
        allUserData[p.id] = {};
      }
    }

    return {
      'profiles': profilesJson,
      'userData': allUserData,
    };
  }

  Future<void> importAllState(Map<String, dynamic> data) async {
    if (data['profiles'] != null) {
      final list = (data['profiles'] as List<dynamic>);
      profiles = list.map((e) => UserProfile.fromJson(e)).toList();
      await _saveProfiles();
    }

    if (data['userData'] != null) {
      final allUserData = data['userData'] as Map<String, dynamic>;
      for (final entry in allUserData.entries) {
        final profileId = entry.key;
        final userDataMap = entry.value as Map<String, dynamic>; // Raw map
        // Save directly to file
        final fileName = 'profile_${profileId}_data.json';
        await PersistenceService.instance.saveString(fileName, jsonEncode(userDataMap));
      }
    }
    
    // Refresh active profile if needed
    if (_activeProfile != null) {
      // Reload current data
      await _loadUserData(_activeProfile!.id);
    }
    notifyListeners();
  }
}
