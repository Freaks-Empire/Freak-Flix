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
import 'screens/adult_screen.dart';

class FreakFlixApp extends StatefulWidget {
  const FreakFlixApp({super.key});

  @override
  State<FreakFlixApp> createState() => _FreakFlixAppState();
}

class _FreakFlixAppState extends State<FreakFlixApp> {
  int _index = 0;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final library = context.watch<LibraryProvider>();
    final profileProvider = context.watch<ProfileProvider>();

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

    return MaterialApp(
      title: 'Freak-Flix',
      scrollBehavior: CustomScrollBehavior(),
      debugShowCheckedModeBanner: false,
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      theme: themeData,
      darkTheme: darkThemeData,
      home: profileProvider.isLoading 
          ? const Scaffold(backgroundColor: Colors.black, body: Center(child: CircularProgressIndicator()))
          : (!settings.isSetupCompleted) 
              ? const SetupScreen()
              : (profileProvider.activeProfile == null 
                  ? const ProfileSelectionScreen()
                  : Scaffold(
              extendBodyBehindAppBar: true, // Allow content to go behind
              body: Stack(
                children: [
                   // Main Content
                   Positioned.fill(
                     child: PageView(
                       controller: _pageController,
                       onPageChanged: (index) => setState(() => _index = index),
                       children: [
                         const DiscoverScreen(type: DiscoverType.all),
                         const MoviesScreen(),
                         const TvScreen(),
                         const AnimeScreen(),
                         if (settings.enableAdultContent) const AdultScreen(),
                         const SearchScreen(),
                         const SettingsScreen(),
                       ],
                     ),
                   ),
                   
                   // Navigation Dock (Top Center)
                   Align(
                     alignment: Alignment.topCenter,
                     child: SafeArea(
                       child: NavigationDock(
                         index: _index,
                         onTap: (i) {
                            setState(() => _index = i);
                            _pageController.animateToPage(
                              i,
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                         },
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
                            color: Colors.grey[900]?.withOpacity(0.95),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const SizedBox(
                                    height: 16,
                                    width: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.redAccent),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    library.scanningStatus.isNotEmpty
                                        ? library.scanningStatus
                                        : 'Scanning library...',
                                    style: const TextStyle(fontSize: 12, color: Colors.white),
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
        )
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

