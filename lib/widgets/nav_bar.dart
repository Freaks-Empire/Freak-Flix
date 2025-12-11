import 'package:flutter/material.dart';

class NavBar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;
  const NavBar({super.key, required this.index, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = [
      (Icons.home_filled, 'Home'),
      (Icons.auto_awesome, 'Discover'),
      (Icons.movie, 'Movies'),
      (Icons.tv, 'TV'),
      (Icons.animation, 'Anime'),
      (Icons.settings, 'Settings'),
    ];

    return Material(
      elevation: 0,
      color: theme.colorScheme.background,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Text(
              'Freak Flix',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: List.generate(items.length, (i) {
                final selected = i == index;
                final (icon, label) = items[i];
                return InkWell(
                  borderRadius: BorderRadius.circular(22),
                  onTap: () => onTap(i),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected
                          ? theme.colorScheme.primary.withOpacity(
                              theme.brightness == Brightness.dark ? 0.22 : 0.12)
                          : theme.colorScheme.surface.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: selected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.outlineVariant,
                        width: 1,
                      ),
                    ),
                    child: AnimatedSize(
                      duration: const Duration(milliseconds: 150),
                      curve: Curves.easeOut,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            icon,
                            size: 18,
                            color: selected
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurface.withOpacity(0.8),
                          ),
                          if (selected) ...[
                            const SizedBox(width: 6),
                            Text(
                              label,
                              style: theme.textTheme.labelLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}
