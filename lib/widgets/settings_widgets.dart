import 'package:flutter/material.dart';

// 1. CONSTANTS for the "Zinc" Look
class AppColors {
  static const bg = Color(0xFF09090b);      // Zinc 950
  static const surface = Color(0xFF18181b); // Zinc 900
  static const border = Color(0xFF27272a);  // Zinc 800
  static const textMain = Color(0xFFfafafa);
  static const textSub = Color(0xFFa1a1aa); // Zinc 400
  static const accent = Color(0xFFef4444);  // Brand Red
}

// 2. THE CARD CONTAINER (SettingsGroup)
class SettingsGroup extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const SettingsGroup({Key? key, required this.title, required this.children}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8, top: 24),
          child: Text(
            title.toUpperCase(),
            style: const TextStyle(
              color: AppColors.textSub,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }
}

// 3. THE ROW ITEM (SettingsTile)
class SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget trailing;
  final bool isLast;
  final VoidCallback? onTap;

  const SettingsTile({
    Key? key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.trailing,
    this.isLast = false,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: isLast 
            ? const BorderRadius.vertical(bottom: Radius.circular(12))
            : null, // Only round corners if it's the last item
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(icon, color: AppColors.textSub, size: 20),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(color: AppColors.textMain, fontSize: 15)),
                    if (subtitle != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(subtitle!, style: const TextStyle(color: AppColors.textSub, fontSize: 13)),
                      ),
                  ],
                ),
              ),
              trailing,
            ],
          ),
        ),
      ),
    );
  }
}
