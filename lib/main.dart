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
import 'providers/auth_provider.dart';
import 'services/metadata_service.dart';
import 'services/tmdb_service.dart';
import 'services/graph_auth_service.dart';
import 'services/tmdb_discover_service.dart';
import 'services/auth0_service.dart';
import 'services/sync_service.dart';
import 'models/discover_filter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  bool envLoaded = false;
  try {
    await dotenv.load(fileName: '.env');
    envLoaded = true;
  } on FileNotFoundError {
    debugPrint('No .env file found, continuing without it.');
  } catch (e) {
    debugPrint('Error loading .env: $e');
  }

  try {
    GraphAuthService.instance.configureFromEnv();
  } catch (e) {
    debugPrint('Graph configuration issue: $e');
  }
  MediaKit.ensureInitialized();
  final settingsProvider = SettingsProvider();
  await settingsProvider.load();
  final tmdbService = TmdbService(settingsProvider);
  final tmdbDiscoverService = TmdbDiscoverService(settingsProvider);
  final libraryProvider = LibraryProvider(settingsProvider);
  await libraryProvider.loadLibrary();
  final metadataService = MetadataService(settingsProvider, tmdbService);
  final playbackProvider = PlaybackProvider(libraryProvider);
  const auth0Domain = String.fromEnvironment('AUTH0_DOMAIN');
  const auth0ClientId = String.fromEnvironment('AUTH0_CLIENT_ID');
  const auth0Audience = String.fromEnvironment('AUTH0_AUDIENCE');
  const auth0Callback = String.fromEnvironment('AUTH0_CALLBACK_URL');
  const auth0Logout = String.fromEnvironment('AUTH0_LOGOUT_URL');
  final envDomain = envLoaded ? dotenv.env['AUTH0_DOMAIN']?.trim() : null;
  final envClientId = envLoaded ? dotenv.env['AUTH0_CLIENT_ID']?.trim() : null;
  final envAudience = envLoaded ? dotenv.env['AUTH0_AUDIENCE']?.trim() : null;
  final envCallback = envLoaded ? dotenv.env['AUTH0_CALLBACK_URL']?.trim() : null;
  final envLogout = envLoaded ? dotenv.env['AUTH0_LOGOUT_URL']?.trim() : null;
  final audienceRaw = auth0Audience.isNotEmpty ? auth0Audience : envAudience;
  final audience = (audienceRaw?.isEmpty ?? true) ? null : audienceRaw;
  final resolvedDomain = auth0Domain.isNotEmpty ? auth0Domain : (envDomain ?? '');
  final resolvedClientId =
      auth0ClientId.isNotEmpty ? auth0ClientId : (envClientId ?? '');
  final resolvedCallback =
      auth0Callback.isNotEmpty ? auth0Callback : (envCallback ?? '');

  if (resolvedDomain.isEmpty || resolvedClientId.isEmpty) {
    _runErrorApp(
      'Missing Auth0 configuration. Set AUTH0_DOMAIN and AUTH0_CLIENT_ID.',
    );
    return;
  }

  if (resolvedCallback.isEmpty) {
    _runErrorApp(
      'Missing Auth0 callback URL. Set AUTH0_CALLBACK_URL in env/dart-define.',
    );
    return;
  }

  if (!GraphAuthService.instance.isConfigured) {
    debugPrint('Graph not configured: set GRAPH_CLIENT_ID (and optional TENANT).');
  }

  final auth0Service = Auth0Service(
    domain: resolvedDomain,
    clientId: resolvedClientId,
    audience: audience,
    callbackUrl: resolvedCallback,
    logoutUrl: auth0Logout.isNotEmpty ? auth0Logout : envLogout,
  );
  final authProvider = AuthProvider(auth0Service);
  await authProvider.restoreSession();

  // --- Cloud Sync Integration ---
  final syncService = SyncService(
    getAccessToken: () => auth0Service.getIdToken(), // Use ID Token for JWT compatibility
  );

  Future<void> pushSync() async {
    if (!authProvider.isAuthenticated) return;
    // Debounce could go here
    final data = {
      'settings': settingsProvider.exportSettings(),
      'graph': GraphAuthService.instance.exportState(),
    };
    await syncService.pushData(data);
  }

  Future<void> pullSync() async {
    if (!authProvider.isAuthenticated) return;
    final data = await syncService.pullData();
    if (data != null) {
      if (data['settings'] != null) {
        // Temporarily remove listener to avoid echo push?
        // For MVP, letting it echo once is fine.
        await settingsProvider.importSettings(data['settings']);
      }
      if (data['graph'] != null) {
        await GraphAuthService.instance.importState(data['graph']);
      }
    }
  }

  // 1. Pull on login
  authProvider.addListener(() {
    // We can't easily detect "just logged in" vs "other change" without state diff
    // But pulling is safe.
    if (authProvider.isAuthenticated) {
      pullSync();
    }
  });

  // 2. Push on settings change
  settingsProvider.addListener(pushSync);

  // 3. Push on graph change
  GraphAuthService.instance.onStateChanged = pushSync;

  // 4. Initial pull
  if (authProvider.isAuthenticated) {
     await pullSync();
  }
  // -----------------------------

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => settingsProvider),
        ChangeNotifierProvider(create: (_) => libraryProvider),
        ChangeNotifierProvider(create: (_) => playbackProvider),
        ChangeNotifierProvider(create: (_) => DiscoverFilterNotifier()),
        ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
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
