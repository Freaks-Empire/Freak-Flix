import 'dart:async';
import 'package:flutter/foundation.dart';
import '../providers/settings_provider.dart';
import '../services/data_backup_service.dart';
import '../providers/library_provider.dart';
import '../providers/profile_provider.dart';

class AutoBackupManager {
  final SettingsProvider settings;
  final LibraryProvider library;
  final ProfileProvider profiles;
  
  Timer? _timer;
  
  // Backup every 30 minutes
  static const Duration _interval = Duration(minutes: 30);

  AutoBackupManager({
    required this.settings,
    required this.library,
    required this.profiles,
  });

  void init() {
    _schedule();
    
    // Listen for setting changes
    settings.addListener(_onSettingsChanged);
  }

  void dispose() {
    _timer?.cancel();
    settings.removeListener(_onSettingsChanged);
  }

  void _onSettingsChanged() {
    // If settings changed (e.g. toggle enabled/disabled), reschedule
    _schedule();
  }

  void _schedule() {
    _timer?.cancel();
    
    if (!settings.autoBackupEnabled || settings.primaryBackupAccountId == null) {
      debugPrint('AutoBackupManager: Disabled or no account selected.');
      return;
    }

    debugPrint('AutoBackupManager: Scheduled backup every ${_interval.inMinutes} minutes.');
    _timer = Timer.periodic(_interval, (_) => _performBackup());
  }

  Future<void> _performBackup() async {
    if (!settings.autoBackupEnabled || settings.primaryBackupAccountId == null) return;
    
    try {
      debugPrint('AutoBackupManager: Starting auto-backup...');
      final backupService = DataBackupService(
        settings: settings,
        library: library,
        profiles: profiles,
      );
      
      await backupService.backupToOneDrive(settings.primaryBackupAccountId!);
      debugPrint('AutoBackupManager: Success.');
    } catch (e) {
      debugPrint('AutoBackupManager: Failed: $e');
    }
  }
}
