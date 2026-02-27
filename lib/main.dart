// lib/main.dart

import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:media_kit/media_kit.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'models/discover_filter.dart';
import 'providers/library_provider.dart';
import 'providers/playback_provider.dart';
import 'providers/profile_provider.dart';
import 'providers/settings_provider.dart';
import 'services/auto_backup_manager.dart';
import 'services/analytics_service.dart';
import 'services/graph_auth_service.dart';
import 'services/metadata_service.dart';
import 'services/monitoring/monitoring.dart';
import 'services/stash_db_service.dart';
import 'services/tmdb_service.dart';
import 'services/tmdb_discover_service.dart';
import 'utils/logger.dart';
import 'utils/platform/platform.dart' as app_platform;

bool shouldInitializeAutoBackupManager({required bool isWindowsDesktop}) {
  return isWindowsDesktop;
}

void main() async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Initialize file logging first so we can capture all startup logs
    await AppLogger.initializeFileLogging();
    AppLogger.i('Freak-Flix starting up...', tag: 'Main');

    usePathUrlStrategy();

    try {
      await dotenv.load(fileName: '.env');
    } catch (e) {
      AppLogger.w('dotenv.load failed: $e', error: e, tag: 'Main');
    }

    // Monitoring
    // Config moved to service
    // New Relic Config - Logic moved to MonitoringService

    // Set up error handlers
    FlutterError.onError = (errorDetails) {
      AppLogger.e('Caught Flutter Error: ${errorDetails.exception}',
          error: errorDetails.exception,
          stackTrace: errorDetails.stack,
          tag: 'Main');
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      AppLogger.e('Caught Platform Error: $error',
          error: error, stackTrace: stack, tag: 'Main');
      return true;
    };

    await MonitoringService.initialize();

    MediaKit.ensureInitialized();

    GraphAuthService.instance.configureFromEnv();
    await GraphAuthService.instance.loadFromPrefs();

    final settingsProvider = SettingsProvider();
    await settingsProvider.load();

    final profileProvider = ProfileProvider();
    await profileProvider.load();

    final tmdbService = TmdbService(settingsProvider);
    final tmdbDiscoverService = TmdbDiscoverService(settingsProvider);
    final libraryProvider = LibraryProvider(settingsProvider);
    await libraryProvider.loadLibrary();

    // One-time Migration: Import legacy history to Default profile
    if (!settingsProvider.hasMigratedProfiles) {
      AppLogger.d('Performing one-time profile migration...', tag: 'Main');
      if (profileProvider.activeProfile == null &&
          profileProvider.profiles.isNotEmpty) {
        // Try 'default', fallback to first
        await profileProvider.selectProfile('default');
      }

      if (profileProvider.activeProfile != null) {
        final history = libraryProvider.extractLegacyHistory();
        if (history.isNotEmpty) {
          AppLogger.d('Importing ${history.length} items to Default profile',
              tag: 'Main');
          await profileProvider.importUserData(history);
        }
        await settingsProvider.setHasMigratedProfiles(true);
        profileProvider.deselectProfile();
      }
    }

    // Connect Profile -> Library (Filter & User Data)
    void syncProfileToLibrary() {
      libraryProvider.updateProfile(
          profileProvider.activeProfile, profileProvider.userData);
    }

    profileProvider.addListener(syncProfileToLibrary);
    // Initial sync
    syncProfileToLibrary();

    final metadataService = MetadataService(settingsProvider, tmdbService);
    final playbackProvider = PlaybackProvider(libraryProvider, profileProvider);

    // Auto Backup Manager (Windows)
    if (shouldInitializeAutoBackupManager(
      isWindowsDesktop: app_platform.Platform.isWindows,
    )) {
      final autoBackupManager = AutoBackupManager(
        settings: settingsProvider,
        library: libraryProvider,
        profiles: profileProvider,
      );
      autoBackupManager.init();
    }

    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => settingsProvider),
          ChangeNotifierProvider(create: (_) => profileProvider),
          ChangeNotifierProvider(create: (_) => libraryProvider),
          ChangeNotifierProvider(create: (_) => playbackProvider),
          ChangeNotifierProvider(create: (_) => DiscoverFilterNotifier()),
          Provider<TmdbService>.value(value: tmdbService),
          Provider<TmdbDiscoverService>.value(value: tmdbDiscoverService),
          Provider<StashDbService>(create: (_) => StashDbService()),
          Provider<MetadataService>.value(value: metadataService),
          Provider<AnalyticsService>.value(value: AnalyticsService()),
        ],
        child: const FreakFlixApp(),
      ),
    );
  }, (Object error, StackTrace stackTrace) {
    MonitoringService.recordError(error, stackTrace);
  });
}
