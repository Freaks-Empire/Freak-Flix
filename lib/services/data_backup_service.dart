/// lib/services/data_backup_service.dart
import 'dart:convert';
import 'dart:io';
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

  Future<Map<String, dynamic>> _generateBackupMap() async {
    return {
      'version': 1,
      'timestamp': DateTime.now().toIso8601String(),
      'settings': settings.exportState(),
      'auth': GraphAuthService.instance.exportState(),
      'profiles': await profiles.exportState(),
      'library': {
        'folders': library.libraryFolders.map((f) => f.toJson()).toList(),
        // Export ALL items, not just filtered view
        'items': library.allItems.map((i) => i.toJson()).toList(), 
      },
    };
  }

  /// Exports backup to a file at [path].
  Future<void> exportBackupToFile(String path) async {
    try {
       final backupMap = await _generateBackupMap();
       final jsonStr = jsonEncode(backupMap);
       final file = File(path);
       await file.writeAsString(jsonStr, flush: true);
       debugPrint('DataBackupService: Backup saved to $path');
    } catch (e) {
      debugPrint('DataBackupService: Export failed: $e');
      rethrow;
    }
  }

  /// Imports backup from a file at [path].
  Future<void> importBackupFromFile(String path) async {
     try {
       final file = File(path);
       if (!await file.exists()) throw Exception('File not found');
       final jsonStr = await file.readAsString();
       await restoreBackup(jsonStr);
     } catch (e) {
       debugPrint('DataBackupService: Import failed: $e');
       rethrow;
     }
  }

  // Legacy/Web clipboard support (kept for compatibility or small backups)
  Future<String> createBackupJson() async {
    final map = await _generateBackupMap();
    return jsonEncode(map);
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

  Future<void> backupToOneDrive(String accountId) async {
    try {
      final jsonStr = await createBackupJson();
      final bytes = utf8.encode(jsonStr);
      final fileName = 'freakflix_backup_${DateTime.now().millisecondsSinceEpoch}.json';

      await GraphAuthService.instance.uploadFileBytes(
        accountId,
        'freakflix_backups/$fileName',
        bytes,
      );
      debugPrint('DataBackupService: Backup uploaded to OneDrive: $fileName');
    } catch (e) {
      debugPrint('DataBackupService: Backup upload failed: $e');
      rethrow;
    }
  }
}
