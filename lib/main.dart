/// lib/main.dart
// Freak-Flix quick start:
// 1) flutter pub get
// 2) Desktop: flutter run -d windows|macos|linux (enable desktop support in SDK)
//    Android: flutter run -d android (emulator or device)
// 3) Configure Trakt Client ID in lib/services/trakt_service.dart (const _traktClientId)
// 4) AniList uses the public endpoint; adjust query in lib/services/anilist_service.dart
// 5) Add new providers in lib/services/metadata_service.dart if you integrate more sources.
//
// Notes:
// - This sample uses shared_preferences for persistence and simple in-memory caches.
// - Playback now uses flutter_mpv (MPV); for advanced engines replace MpvController via FFI later.

import 'package:flutter/material.dart';
import 'services/monitoring/monitoring.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart' show FileNotFoundError;
import 'package:media_kit/media_kit.dart';
import 'package:provider/provider.dart';
import 'app.dart';
import 'providers/library_provider.dart';
import 'providers/playback_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/profile_provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'firebase_options.dart';
import 'services/analytics_service.dart';
import 'services/sync_service.dart';

import 'package:flutter/foundation.dart'; // For PlatformDispatcher

import 'package:flutter_web_plugins/url_strategy.dart';

import 'services/metadata_service.dart';
import 'services/tmdb_service.dart';
import 'services/graph_auth_service.dart';
import 'services/tmdb_discover_service.dart';

import 'models/discover_filter.dart';

import 'dart:async'; // Add async import
import 'dart:io';

void main() async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    usePathUrlStrategy();

    try {
      await dotenv.load(fileName: '.env'); 
    } catch (e) {
      debugPrint('Warning: dotenv.load failed: $e');
    }

    // Monitoring
    // Config moved to service
    // New Relic Config - Logic moved to MonitoringService
         

    // 1. Initialize Firebase
    // Only init Firebase on supported platforms if needed, or just guard Crashlytics
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      
      // 2. Set up Crashlytics (Mobile only usually)
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
         FlutterError.onError = (errorDetails) {
           debugPrint('Caught Flutter Error: ${errorDetails.exception}');
           try {
             FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
           } catch (e) {
             debugPrint('Failed to report to Crashlytics: $e');
           }
         };
         
         PlatformDispatcher.instance.onError = (error, stack) {
           debugPrint('Caught Platform Error: $error');
           try {
             FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
           } catch (e) {
              debugPrint('Failed to report to Crashlytics: $e');
           }
           return true;
         };
      } else {
         debugPrint('Firebase Crashlytics disabled on this platform.');
      }
    } catch (e) {
      debugPrint('Firebase Init Failed (Likely due to missing configuration): $e');
    }

    await MonitoringService.initialize();
    
    MediaKit.ensureInitialized();
  
    GraphAuthService.instance.configureFromEnv();
    await GraphAuthService.instance.loadFromPrefs();

    final settingsProvider = SettingsProvider();
    await settingsProvider.load();

    // Wire Sync logic after Settings & Auth are ready
    void updateSyncState() {
       final userId = GraphAuthService.instance.activeAccountId;
       if (userId != null) {
          debugPrint('Main: Activating Sync for user $userId');
          SyncService().init(userId, (data) {
             settingsProvider.importSettings(data);
          });
       } else {
          SyncService().dispose();
       }
    }
    
    // Set listener
    GraphAuthService.instance.onStateChanged = updateSyncState;
    // Initial check
    updateSyncState();

    final profileProvider = ProfileProvider();
    await profileProvider.load();
    
    final tmdbService = TmdbService(settingsProvider);
    final tmdbDiscoverService = TmdbDiscoverService(settingsProvider);
    final libraryProvider = LibraryProvider(settingsProvider);
    await libraryProvider.loadLibrary();
    
    // One-time Migration: Import legacy history to Default profile
    if (!settingsProvider.hasMigratedProfiles) {
        debugPrint('Main: Performing one-time profile migration...');
        if (profileProvider.activeProfile == null && profileProvider.profiles.isNotEmpty) {
            // Try 'default', fallback to first
            await profileProvider.selectProfile('default');
        }
        
        if (profileProvider.activeProfile != null) {
            final history = libraryProvider.extractLegacyHistory();
            if (history.isNotEmpty) {
                debugPrint('Main: Importing ${history.length} items to Default profile.');
                await profileProvider.importUserData(history);
            }
            await settingsProvider.setHasMigratedProfiles(true);
            profileProvider.deselectProfile();
        }
    }
    
    // Connect Profile -> Library (Filter & User Data)
    void syncProfileToLibrary() {
      libraryProvider.updateProfile(profileProvider.activeProfile, profileProvider.userData);
    }
    profileProvider.addListener(syncProfileToLibrary);
    // Initial sync
    syncProfileToLibrary();

    final metadataService = MetadataService(settingsProvider, tmdbService);
    final playbackProvider = PlaybackProvider(libraryProvider, profileProvider);
    
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

void _runErrorApp(String message) {
  runApp(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18),
            ),
          ),
        ),
      ),
    ),
  );
}
