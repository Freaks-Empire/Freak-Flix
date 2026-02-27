// lib/widgets/navigation_dock.dart

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';

class NavigationDockDestination {
  final int branchIndex;
  final IconData icon;
  final String label;
  final bool adultOnly;

  const NavigationDockDestination({
    required this.branchIndex,
    required this.icon,
    required this.label,
    this.adultOnly = false,
  });
}

const _dockDestinations = <NavigationDockDestination>[
  NavigationDockDestination(
    branchIndex: 0,
    icon: Icons.home_filled,
    label: 'Home',
  ),
  NavigationDockDestination(
    branchIndex: 1,
    icon: Icons.movie_outlined,
    label: 'Movies',
  ),
  NavigationDockDestination(
    branchIndex: 2,
    icon: Icons.tv,
    label: 'TV',
  ),
  NavigationDockDestination(
    branchIndex: 3,
    icon: Icons.animation,
    label: 'Anime',
  ),
  NavigationDockDestination(
    branchIndex: 4,
    icon: Icons.lock_outline,
    label: 'Adult',
    adultOnly: true,
  ),
  NavigationDockDestination(
    branchIndex: 5,
    icon: Icons.search,
    label: 'Search',
  ),
  NavigationDockDestination(
    branchIndex: 6,
    icon: Icons.settings_outlined,
    label: 'Settings',
  ),
];

List<NavigationDockDestination> visibleNavigationDockDestinations({
  required bool adultEnabled,
}) {
  return _dockDestinations
      .where((destination) => !destination.adultOnly || adultEnabled)
      .toList(growable: false);
}

List<int> visibleNavigationBranchIndices({required bool adultEnabled}) {
  return visibleNavigationDockDestinations(adultEnabled: adultEnabled)
      .map((destination) => destination.branchIndex)
      .toList(growable: false);
}

class NavigationDock extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;

  const NavigationDock({super.key, required this.index, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = context.watch<SettingsProvider>();
    final isDark = theme.brightness == Brightness.dark;
    final destinations = visibleNavigationDockDestinations(
      adultEnabled: settings.enableAdultContent,
    );

    return Center(
      heightFactor: 1.0,
      child: Container(
        margin: const EdgeInsets.only(top: 16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: (isDark ? Colors.black : Colors.white).withOpacity(0.7),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color:
                      (isDark ? Colors.white : Colors.black).withOpacity(0.1),
                  width: 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < destinations.length; i++) ...[
                    _DockItem(
                      icon: destinations[i].icon,
                      label: destinations[i].label,
                      isSelected: index == destinations[i].branchIndex,
                      onTap: () => onTap(destinations[i].branchIndex),
                      theme: theme,
                    ),
                    if (i != destinations.length - 1) const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DockItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final ThemeData theme;

  const _DockItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final color = isSelected
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurface.withOpacity(0.6);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
