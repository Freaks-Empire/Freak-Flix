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
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart' show FileNotFoundError;
import 'package:media_kit/media_kit.dart';
import 'package:provider/provider.dart';
import 'app.dart';
import 'providers/library_provider.dart';
import 'providers/playback_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/profile_provider.dart';

import 'services/metadata_service.dart';
import 'services/tmdb_service.dart';
import 'services/graph_auth_service.dart';
import 'services/tmdb_discover_service.dart';

import 'models/discover_filter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: '.env'); 
  } catch (e) {
    debugPrint('Warning: dotenv.load failed: $e');
  }

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
  
  // ... Cloud Sync ...

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
      ],
      child: const FreakFlixApp(),
    ),
  );
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
