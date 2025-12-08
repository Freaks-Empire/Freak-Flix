import 'package:flutter/material.dart';

class NavBar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;
  const NavBar({super.key, required this.index, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.home_filled, 'Home'),
      (Icons.movie, 'Movies'),
      (Icons.tv, 'TV'),
      (Icons.animation, 'Anime'),
      (Icons.settings, 'Settings'),
    ];
    return NavigationRail(
      selectedIndex: index,
      onDestinationSelected: onTap,
      labelType: NavigationRailLabelType.all,
      leading: const Padding(
        padding: EdgeInsets.all(8.0),
        child: FlutterLogo(size: 32),
      ),
      destinations: [
        for (final item in items)
          NavigationRailDestination(
            icon: Icon(item.$1),
            selectedIcon: Icon(item.$1, color: Colors.redAccent),
            label: Text(item.$2),
          ),
      ],
    );
  }
}