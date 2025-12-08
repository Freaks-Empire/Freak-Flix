import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/settings_provider.dart';
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
        body: Row(
          children: [
            NavBar(
              index: _index,
              onTap: (i) => setState(() => _index = i),
            ),
            Expanded(child: _pages[_index]),
          ],
        ),
      ),
    );
  }
}