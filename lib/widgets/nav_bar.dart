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
        padding: EdgeInsets.all(12.0),
        child: Text(
          'Freak Flix',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
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