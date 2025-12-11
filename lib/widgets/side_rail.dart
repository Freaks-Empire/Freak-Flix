import 'package:flutter/material.dart';

class SideRail extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;

  const SideRail({super.key, required this.index, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = <_RailItem>[
      _RailItem(icon: Icons.search, tooltip: 'Search / Discover', pageIndex: 1),
      _RailItem(icon: Icons.home_filled, tooltip: 'Home', pageIndex: 0),
      _RailItem(icon: Icons.star_outline, tooltip: 'Movies', pageIndex: 2),
      _RailItem(icon: Icons.list_alt_outlined, tooltip: 'TV', pageIndex: 3),
      _RailItem(icon: Icons.movie_creation_outlined, tooltip: 'Anime', pageIndex: 4),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      child: Column(
        children: [
          Container(
            width: 64,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface.withOpacity(0.7),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.18),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              children: [
                for (final item in items) ...[
                  _RailButton(
                    icon: item.icon,
                    tooltip: item.tooltip,
                    selected: index == item.pageIndex,
                    onTap: () => onTap(item.pageIndex),
                    theme: theme,
                  ),
                  const SizedBox(height: 10),
                ],
                const SizedBox(height: 6),
                _RailButton(
                  icon: Icons.person_outline,
                  tooltip: 'Profile / Settings',
                  selected: index == 5,
                  onTap: () => onTap(5),
                  theme: theme,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RailItem {
  final IconData icon;
  final String tooltip;
  final int pageIndex;
  const _RailItem({required this.icon, required this.tooltip, required this.pageIndex});
}

class _RailButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool selected;
  final VoidCallback onTap;
  final ThemeData theme;

  const _RailButton({
    required this.icon,
    required this.tooltip,
    required this.selected,
    required this.onTap,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? Colors.white : theme.colorScheme.onSurface.withOpacity(0.8);
    final bg = selected
        ? theme.colorScheme.primary
        : theme.colorScheme.surfaceVariant.withOpacity(0.4);
    final border = selected
        ? theme.colorScheme.primary
        : theme.colorScheme.outlineVariant;

    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 300),
      child: InkResponse(
        onTap: onTap,
        radius: 26,
        child: Container(
          height: 44,
          width: 44,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: border, width: 1),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
      ),
    );
  }
}
