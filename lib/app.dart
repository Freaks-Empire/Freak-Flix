/// lib/app.dart
import 'package:flutter/material.dart';
import 'dart:ui'; // Required for PointerDeviceKind
import 'package:provider/provider.dart';
import 'providers/settings_provider.dart';
import 'providers/library_provider.dart';
import 'providers/profile_provider.dart'; // Import
import 'screens/profile_selection_screen.dart'; // Import
import 'screens/setup_screen.dart';

import 'screens/discover_screen.dart';
import 'screens/settings_screen.dart';

import 'screens/search_screen.dart';
import 'widgets/navigation_dock.dart';
import 'services/tmdb_discover_service.dart';

import 'screens/movies_screen.dart';
import 'screens/tv_screen.dart';
import 'screens/anime_screen.dart';
import 'package:go_router/go_router.dart';
import 'router.dart';
import 'screens/adult_screen.dart';

class FreakFlixApp extends StatefulWidget {
  const FreakFlixApp({super.key});

  @override
  State<FreakFlixApp> createState() => _FreakFlixAppState();
}

class _FreakFlixAppState extends State<FreakFlixApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    // Initialize Router
    final settings = context.read<SettingsProvider>();
    final profiles = context.read<ProfileProvider>();
    _router = createRouter(settings, profiles);
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final dark = settings.isDarkMode;
    
    // Theme Config
    final themeData = ThemeData(
        brightness: Brightness.light,
        colorSchemeSeed: Colors.redAccent,
        useMaterial3: true,
      );
    final darkThemeData = ThemeData(
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.redAccent,
        useMaterial3: true,
      );

    return MaterialApp.router(
      title: 'Freak-Flix',
      scrollBehavior: CustomScrollBehavior(),
      debugShowCheckedModeBanner: false,
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      theme: themeData,
      darkTheme: darkThemeData,
      routerConfig: _router,
    );
  }
}

class CustomScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
      };
}

