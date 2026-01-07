import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'services/monitoring/monitoring.dart';
import 'package:provider/provider.dart';

import 'providers/profile_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/library_provider.dart';

// Screens
// Screens
import 'screens/setup_screen.dart';
import 'screens/profile_selection_screen.dart';
import 'screens/main_screen.dart';
import 'screens/details/actor_details_screen.dart';
import 'screens/details_screen.dart';
import 'screens/discover_screen.dart';
import 'screens/movies_screen.dart';
import 'screens/tv_screen.dart';
import 'screens/anime_screen.dart';
import 'screens/adult_screen.dart';
import 'screens/search_screen.dart';
import 'screens/settings_screen.dart';

// Models
import 'models/cast_member.dart';
import 'models/media_item.dart';
import 'models/discover_type.dart';

// Keys
final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

GoRouter createRouter(
  SettingsProvider settings,
  ProfileProvider profiles,
) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/discover',
    refreshListenable: Listenable.merge([settings, profiles]),
    debugLogDiagnostics: true,
    observers: [MonitoringService.navigationObserver],
    
    redirect: (context, state) {
      final isSetup = settings.isSetupCompleted;
      final isProfileSelected = profiles.activeProfile != null;
      
      // 1. Setup Redirects
      if (!isSetup) {
        if (state.uri.path != '/setup') return '/setup';
        return null; 
      }
      if (isSetup && state.uri.path == '/setup') return '/discover';

      // 2. Profile Redirects
      if (!isProfileSelected) {
        if (state.uri.path != '/profiles') return '/profiles';
        return null;
      }
      if (isProfileSelected && state.uri.path == '/profiles') return '/discover';
      
      // 3. Root Redirect
      if (state.uri.path == '/') return '/discover';

      // 4. Adult Content Protection
      if (!settings.enableAdultContent) {
         if (state.uri.path.startsWith('/adult')) return '/discover';
      }

      return null;
    },

    routes: [
      // Setup
      GoRoute(
        path: '/setup',
        builder: (context, state) => const SetupScreen(),
      ),

      // Profiles
      GoRoute(
        path: '/profiles',
        builder: (context, state) => const ProfileSelectionScreen(),
      ),

      // Shell Route for Tabs
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
           return MainScreen(navigationShell: navigationShell);
        },
        branches: [
           // 0: Discover / Home
           StatefulShellBranch(
             routes: [
               GoRoute(
                 path: '/discover',
                 builder: (context, state) => const DiscoverScreen(type: DiscoverType.all),
               ),
             ],
           ),
           
           // 1: Movies
           StatefulShellBranch(
             routes: [
               GoRoute(
                 path: '/movies',
                  builder: (context, state) => const MoviesScreen(),
                  routes: [
                    GoRoute(
                      path: 'details/:id',
                      builder: (context, state) {
                        final id = state.pathParameters['id']!;
                        final movie = state.extra as MediaItem?;
                        return DetailsScreen(item: movie, itemId: id);
                      },
                    ),
                  ],
                ),
             ],
           ),
           
           // 2: TV
           StatefulShellBranch(
             routes: [
               GoRoute(
                 path: '/tv',
                 builder: (context, state) => const TvScreen(),
               ),
             ],
           ),

           // 3: Anime
           StatefulShellBranch(
             routes: [
               GoRoute(
                 path: '/anime',
                 builder: (context, state) => const AnimeScreen(),
               ),
             ],
           ),
           
           // 4: Adult (Conditional logic handled in MainScreen nav, but route exists)
           StatefulShellBranch(
             routes: [
                GoRoute(
                  path: '/adult',
                  builder: (context, state) => const AdultScreen(),
                ),
             ],
           ),

           // 5: Search
           StatefulShellBranch(
             routes: [
               GoRoute(
                 path: '/search',
                 builder: (context, state) => const SearchScreen(),
               ),
             ],
           ),
           
           // 6: Settings
           StatefulShellBranch(
             routes: [
               GoRoute(
                 path: '/settings',
                 builder: (context, state) => const SettingsScreen(),
               ),
             ],
           ),
        ],
      ),

      // Global Detail Routes (Accessible from anywhere)
      GoRoute(
        path: '/media/:id',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
           final id = state.pathParameters['id']!;
           final extra = state.extra as MediaItem?;
           // TODO: If extra is null, we need to fetch generic media by ID (StashDB or TMDB)?
           // For now, this assumes we have the item or the screen handles partial data/fetching.
           return DetailsScreen(item: extra, itemId: id);
        },
      ),

      GoRoute(
        path: '/scene/:id',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
           final id = state.pathParameters['id']!;
           final extra = state.extra as MediaItem?;
           // Ensure ID is passed as stashdb:UUID if the screen expects it, or modify screen.
           // Screen likely expects 'stashdb:UUID' or just UUID if customized.
           // Let's pass normalized ID: 'stashdb:$id' if it doesn't start with it, 
           // BUT DetailsScreen logic handles 'stashdb:' prefix logic.
           // If the URL is /scene/UUID, we pass 'stashdb:UUID' to screen for consistency with provider logic.
           final itemId = id.startsWith('stashdb:') ? id : 'stashdb:$id';
           return DetailsScreen(item: extra, itemId: itemId);
        },
      ),

      GoRoute(
        path: '/anime/:id/:slug',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
           final idStr = state.pathParameters['id']!;
           final extra = state.extra as MediaItem?;
           // If we have extra, use it.
           // If not, we might need to fetch by AniList ID if logic permits, 
           // OR constructs a dummy item with anilistId to trigger enrichment.
           
           // Construct a usable ID for internal logic. 
           // If internal logic mostly uses TMDB or StashDB, passing generic ID might fail.
           // However, TvDetailsScreen can fetch via AniListService if we signal it.
           // For now, let's pass id directly. DetailsScreen needs to be smart enough.
           // If we don't have an internal ID, we might pass 'anilist:$idStr' ? 
           // Currently DetailsScreen parses prefixes. Let's assume we pass 'anilist:$idStr' and support it there.
           
           return DetailsScreen(item: extra, itemId: 'anilist:$idStr');
        },
      ),

      GoRoute(
        path: '/actor/:id',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
           final id = state.pathParameters['id']!;
           final extra = state.extra as CastMember?;
           return ActorDetailsScreen(actor: extra, actorId: id);
        },
      ),
    ],
  );
}
