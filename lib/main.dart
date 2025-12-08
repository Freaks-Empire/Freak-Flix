// LocalFlix quick start:
// 1) flutter pub get
// 2) Desktop: flutter run -d windows|macos|linux (enable desktop support in SDK)
//    Android: flutter run -d android (emulator or device)
// 3) Configure OMDb API key in lib/services/omdb_service.dart (const _omdbApiKey)
// 4) AniList uses the public endpoint; adjust query in lib/services/anilist_service.dart
// 5) Add new providers in lib/services/metadata_service.dart if you integrate more sources.
//
// Notes:
// - This sample uses shared_preferences for persistence and simple in-memory caches.
// - Playback now uses flutter_mpv (MPV); for advanced engines replace MpvController via FFI later.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app.dart';
import 'providers/library_provider.dart';
import 'providers/playback_provider.dart';
import 'providers/settings_provider.dart';
import 'services/metadata_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settingsProvider = SettingsProvider();
  await settingsProvider.load();
  final libraryProvider = LibraryProvider(settingsProvider);
  await libraryProvider.loadLibrary();
  final metadataService = MetadataService(settingsProvider);
  final playbackProvider = PlaybackProvider(libraryProvider);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => settingsProvider),
        ChangeNotifierProvider(create: (_) => libraryProvider),
        ChangeNotifierProvider(create: (_) => playbackProvider),
        Provider<MetadataService>.value(value: metadataService),
      ],
      child: const LocalFlixApp(),
    ),
  );
}