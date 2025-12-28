import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'providers/profile_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/library_provider.dart';

// Screens
import 'screens/setup_screen.dart';
import 'screens/profile_selection_screen.dart';
import 'screens/main_screen.dart'; // We will create this
import 'screens/details/actor_details_screen.dart';
import 'screens/details_screen.dart';
import 'models/cast_member.dart';
import 'models/media_item.dart';

// Keys
final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

GoRouter createRouter(
  SettingsProvider settings,
  ProfileProvider profiles,
) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    refreshListenable: Listenable.merge([settings, profiles]),
    debugLogDiagnostics: true,
    
    redirect: (context, state) {
      final isSetup = settings.isSetupCompleted;
      final isProfileSelected = profiles.activeProfile != null;
      
      // 1. If Setup not done, go to /setup
      if (!isSetup) {
        if (state.uri.toString() != '/setup') return '/setup';
        return null; // Stay on /setup
      }

      // 2. If Setup done but visiting /setup, redirect to /
      if (isSetup && state.uri.toString() == '/setup') {
        return '/';
      }

      // 3. If Profile not selected, go to /profiles
      if (!isProfileSelected) {
        if (state.uri.toString() != '/profiles') return '/profiles';
        return null;
      }

      // 4. If Profile selected but visiting /profiles, redirect to /
      if (isProfileSelected && state.uri.toString() == '/profiles') {
        return '/';
      }

      return null; // No redirect
    },

    routes: [
      // 1. Setup
      GoRoute(
        path: '/setup',
        builder: (context, state) => const SetupScreen(),
      ),

      // 2. Profiles
      GoRoute(
        path: '/profiles',
        builder: (context, state) => const ProfileSelectionScreen(),
      ),

      // 3. Main App (Shell) - Actually, since we use a custom Dock+PageView, 
      //    we might just make "/" the MainScreen which handles its own tabs internally.
      //    Using ShellRoute for tabs requires mapping tabs to URLs (e.g. /movies, /tv).
      //    For now, keeping it simple: just one route "/" that has the PageView.
      GoRoute(
        path: '/',
        builder: (context, state) => const MainScreen(),
        routes: [
           // Sub-routes (Pushed on top of MainScreen)
           GoRoute(
             path: 'media/:id',
             builder: (context, state) {
                final id = state.pathParameters['id']!;
                final extra = state.extra as MediaItem?;
                return DetailsScreen(item: extra, itemId: id);
             },
           ),
           GoRoute(
             path: 'actor/:id',
             builder: (context, state) {
                final id = state.pathParameters['id']!;
                final extra = state.extra as CastMember?;
                return ActorDetailsScreen(actor: extra, actorId: id);
             },
           ),
        ],
      ),
    ],
  );
}
