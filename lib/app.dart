import 'package:flutter/material.dart';
import 'dart:ui'; // Required for PointerDeviceKind
import 'package:provider/provider.dart';
import 'providers/settings_provider.dart';
import 'providers/library_provider.dart';
import 'providers/auth_provider.dart';
import 'screens/discover_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/auth/auth_screen.dart';
import 'screens/setup_screen.dart';
import 'widgets/navigation_dock.dart';
import 'services/tmdb_discover_service.dart';

class FreakFlixApp extends StatefulWidget {
  const FreakFlixApp({super.key});

  @override
  State<FreakFlixApp> createState() => _FreakFlixAppState();
}

class _FreakFlixAppState extends State<FreakFlixApp> {
  int _index = 0;
  final _pages = const [
    DiscoverScreen(type: DiscoverType.all), // Home
    DiscoverScreen(type: DiscoverType.movie), // Movies
    DiscoverScreen(type: DiscoverType.tv), // TV
    DiscoverScreen(type: DiscoverType.anime), // Anime
    SettingsScreen(), // Settings
  ];

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final library = context.watch<LibraryProvider>();
    final auth = context.watch<AuthProvider>();
    final dark = settings.isDarkMode;
    return MaterialApp(
      title: 'Freak-Flix',
      scrollBehavior: CustomScrollBehavior(),
      debugShowCheckedModeBanner: false,
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        brightness: Brightness.light,
        colorSchemeSeed: Colors.redAccent,
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.redAccent,
        useMaterial3: true,
      ),
      home: auth.isAuthenticated
          ? Scaffold(
              extendBodyBehindAppBar: true, // Allow content to go behind
              body: Stack(
                children: [
                   // Main Content
                   Positioned.fill(
                     child: AnimatedSwitcher(
                       duration: const Duration(milliseconds: 300),
                       switchInCurve: Curves.easeOut,
                       switchOutCurve: Curves.easeIn,
                       transitionBuilder: (child, animation) {
                         return FadeTransition(
                           opacity: animation,
                           child: ScaleTransition(
                             scale: Tween<double>(begin: 0.98, end: 1.0).animate(animation),
                             child: child,
                           ),
                         );
                       },
                       child: KeyedSubtree(
                         key: ValueKey<int>(_index),
                         child: _pages[_index],
                       ),
                     ),
                   ),
                   
                   // Navigation Dock (Top Center)
                   Align(
                     alignment: Alignment.topCenter,
                     child: SafeArea(
                       child: NavigationDock(
                         index: _index,
                         onTap: (i) => setState(() => _index = i),
                       ),
                     ),
                   ),

                   // Scanning Indicator
                    if (library.isLoading)
                      Positioned(
                        top: 24+60, // Push down below dock
                        left: 24,
                        right: 24,
                        child: Center(
                          child: Material(
                            elevation: 4,
                            borderRadius: BorderRadius.circular(20),
                            color: Theme.of(context).colorScheme.surface.withOpacity(0.9),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const SizedBox(
                                    height: 16,
                                    width: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    library.scanningStatus.isNotEmpty
                                        ? library.scanningStatus
                                        : 'Scanning library...',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                ],
              ),
            )
          : const AuthScreen(),
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

