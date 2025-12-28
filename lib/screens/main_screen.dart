import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';
import '../providers/library_provider.dart';
import '../models/discover_filter.dart';

import '../widgets/navigation_dock.dart';
import 'discover_screen.dart';
import 'movies_screen.dart';
import 'tv_screen.dart';
import 'anime_screen.dart';
import 'adult_screen.dart';
import 'search_screen.dart';
import 'settings_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
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

     return Scaffold(
        extendBodyBehindAppBar: true, 
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
     );
   }
}
