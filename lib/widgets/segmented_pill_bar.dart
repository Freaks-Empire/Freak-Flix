import 'package:flutter/material.dart';

class SegmentedPillItem {
  final String label;
  final IconData icon;

  const SegmentedPillItem(this.label, this.icon);
}

class SegmentedPillBar extends StatelessWidget {
  final List<SegmentedPillItem> items;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  const SegmentedPillBar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const accent = Color(0xFFB259FF); // trakt-ish purple
    const bg = Color(0xFF32343A);

    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = constraints.maxWidth / items.length;

        return Container(
          height: 40,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: bg.withOpacity(0.6),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                left: itemWidth * selectedIndex,
                top: 0,
                bottom: 0,
                width: itemWidth,
                child: Container(
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                children: List.generate(items.length, (index) {
                  final item = items[index];
                  final isSelected = index == selectedIndex;

                  final iconColor =
                      isSelected ? Colors.white : Colors.white.withOpacity(0.8);
                  final textColor =
                      isSelected ? Colors.white : Colors.white.withOpacity(0.85);

                  return Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(999),
                      onTap: () => onChanged(index),
                      child: Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              item.icon,
                              size: 18,
                              color: iconColor,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              item.label,
                              style: theme.textTheme.labelLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: textColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        );
      },
    );
  }
}
