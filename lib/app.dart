import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/settings_provider.dart';
import 'providers/library_provider.dart';
import 'screens/home_screen.dart';
import 'screens/movies_screen.dart';
import 'screens/tv_screen.dart';
import 'screens/anime_screen.dart';
import 'screens/settings_screen.dart';
import 'widgets/nav_bar.dart';

class LocalFlixApp extends StatefulWidget {
  const LocalFlixApp({super.key});

  @override
  State<LocalFlixApp> createState() => _LocalFlixAppState();
}

class _LocalFlixAppState extends State<LocalFlixApp> {
  int _index = 0;
  final _pages = const [
    HomeScreen(),
    MoviesScreen(),
    TvScreen(),
    AnimeScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final library = context.watch<LibraryProvider>();
    final dark = settings.isDarkMode;
    return MaterialApp(
      title: 'LocalFlix',
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
      home: Scaffold(
        body: Stack(
          children: [
            Row(
              children: [
                NavBar(
                  index: _index,
                  onTap: (i) => setState(() => _index = i),
                ),
                Expanded(child: _pages[_index]),
              ],
            ),
            if (library.isLoading)
              Positioned(
                top: 12,
                left: 76,
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
          ],
        ),
      ),
    );
  }
}