
import 'dart:ui';
import 'package:flutter/material.dart';

class NavigationDock extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;

  const NavigationDock({super.key, required this.index, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Center(
      heightFactor: 1.0,
      child: Container(
        margin: const EdgeInsets.only(top: 16), // "Sticky" top margin
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10), // Frosted glass effect
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: (isDark ? Colors.black : Colors.white).withOpacity(0.7),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: (isDark ? Colors.white : Colors.black).withOpacity(0.1),
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
                  _DockItem(
                    icon: Icons.home_filled,
                    label: 'Home',
                    isSelected: index == 0,
                    onTap: () => onTap(0),
                    theme: theme,
                  ),
                  const SizedBox(width: 8),
                  _DockItem(
                    icon: Icons.movie_outlined,
                    label: 'Movies',
                    isSelected: index == 1,
                    onTap: () => onTap(1),
                    theme: theme,
                  ),
                  const SizedBox(width: 8),
                  _DockItem(
                    icon: Icons.tv,
                    label: 'TV',
                    isSelected: index == 2,
                    onTap: () => onTap(2),
                    theme: theme,
                  ),
                  const SizedBox(width: 8),
                  _DockItem(
                    icon: Icons.animation, // or distinct icon
                    label: 'Anime',
                    isSelected: index == 3,
                    onTap: () => onTap(3),
                    theme: theme,
                  ),
                  const SizedBox(width: 8),
                  _DockItem(
                    icon: Icons.search,
                    label: 'Search',
                    isSelected: index == 4,
                    onTap: () => onTap(4),
                    theme: theme,
                  ),
                  const SizedBox(width: 8),
                  _DockItem(
                    icon: Icons.settings_outlined,
                    label: 'Settings',
                    isSelected: index == 5,
                    onTap: () => onTap(5),
                    theme: theme,
                  ),
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
