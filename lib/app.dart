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
import 'widgets/side_rail.dart';

class FreakFlixApp extends StatefulWidget {
  const FreakFlixApp({super.key});

  @override
  State<FreakFlixApp> createState() => _FreakFlixAppState();
}

class _FreakFlixAppState extends State<FreakFlixApp> {
  int _index = 0;
  final _pages = const [
    DiscoverScreen(), // New Homepage
    SettingsScreen(),
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
              body: Stack(
                children: [
                  if (!settings.hasTmdbKey)
                    const SetupScreen()
                  else ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SideRail(index: _index, onTap: (i) => setState(() => _index = i)),
                        Expanded(child: _pages[_index]),
                      ],
                    ),
                    if (library.isLoading)
                      Positioned(
                        top: 24,
                        left: 84,
                        right: 12,
                        child: Material(
                          elevation: 4,
                          borderRadius: BorderRadius.circular(8),
                          color: Theme.of(context).colorScheme.surface.withOpacity(0.9),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            child: Row(
                              children: [
                                const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2.2),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    library.scanningStatus.isNotEmpty
                                        ? library.scanningStatus
                                        : 'Scanning library in background... You can keep browsing.',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ]
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

