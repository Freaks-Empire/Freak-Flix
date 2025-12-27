/// lib/services/data_backup_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';
import '../providers/library_provider.dart';
import '../providers/profile_provider.dart';
import 'graph_auth_service.dart';

class DataBackupService {
  final SettingsProvider settings;
  final LibraryProvider library;
  final ProfileProvider profiles;

  DataBackupService({
    required this.settings,
    required this.library,
    required this.profiles,
  });

  Future<String> createBackup() async {
    final backup = <String, dynamic>{
      'version': 1,
      'timestamp': DateTime.now().toIso8601String(),
      'settings': settings.exportState(),
      'auth': GraphAuthService.instance.exportState(),
      'profiles': await profiles.exportState(),
      'library': {
        'folders': library.libraryFolders.map((f) => f.toJson()).toList(),
        // We export items too, to restore the library state without re-scanning.
        // However, this might be large.
        'items': library.items.map((i) => i.toJson()).toList(), 
      },
    };

    return jsonEncode(backup);
  }

  Future<void> restoreBackup(String jsonString) async {
    try {
      final Map<String, dynamic> backup = jsonDecode(jsonString);
      
      final int version = backup['version'] ?? 0;
      if (version < 1) {
        throw Exception('Unknown backup version');
      }

      // 1. Settings
      if (backup['settings'] != null) {
        await settings.importState(backup['settings']);
      }

      // 2. Auth
      if (backup['auth'] != null) {
        await GraphAuthService.instance.importState(backup['auth']);
      }

      // 3. Profiles
      if (backup['profiles'] != null) {
        await profiles.importAllState(backup['profiles']);
      }

      // 4. Library
      if (backup['library'] != null) {
        await library.importState(backup['library']);
      }
      
    } catch (e) {
      debugPrint('Restore failed: $e');
      rethrow;
    }
  }

}
