import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../providers/library_provider.dart';
import '../widgets/navigation_dock.dart';

class MainScreen extends StatelessWidget {
  final StatefulNavigationShell? navigationShell;

  const MainScreen({super.key, this.navigationShell});

  @override
  Widget build(BuildContext context) {
     final library = context.watch<LibraryProvider>();
     
     // If not using Shell (legacy fallback or error), show empty container or legacy layout.
     // But with createRouter configuration, this should always be provided.
     if (navigationShell == null) {
       return const Scaffold(body: Center(child: Text("Router Error: No Navigation Shell")));
     }

     return Scaffold(
        extendBodyBehindAppBar: true, 
        body: Stack(
          children: [
             // Main Content (Router Branch)
             Positioned.fill(
               child: navigationShell!,
             ),
             
             // Navigation Dock (Top Center)
             Align(
               alignment: Alignment.topCenter,
               child: SafeArea(
                 child: NavigationDock(
                   index: navigationShell!.currentIndex,
                   onTap: (i) {
                      navigationShell!.goBranch(
                        i,
                        initialLocation: i == navigationShell!.currentIndex, 
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
