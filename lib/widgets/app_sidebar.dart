import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../providers/profile_provider.dart';

class AppSidebar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  const AppSidebar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = context.watch<SettingsProvider>();
    final profile = context.watch<ProfileProvider>();
    
    // Calculate indices dynamically
    final searchIndex = settings.enableAdultContent ? 5 : 4;
    final settingsIndex = settings.enableAdultContent ? 6 : 5;

    return Container(
      width: 250,
      color: Colors.black, // Dark background for sidebar
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo Area
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: 'Freak',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: Colors.blueAccent, // Neon blue
                    ),
                  ),
                  TextSpan(
                    text: 'Flix',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: Colors.pinkAccent, // Neon pink
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),

          // Navigation Items
          _SidebarItem(
            icon: Icons.home_filled,
            label: 'Home',
            isSelected: selectedIndex == 0,
            onTap: () => onDestinationSelected(0),
          ),
          _SidebarItem(
            icon: Icons.movie_outlined,
            label: 'Movies',
            isSelected: selectedIndex == 1,
            onTap: () => onDestinationSelected(1),
          ),
          _SidebarItem(
            icon: Icons.tv,
            label: 'TV Shows',
            isSelected: selectedIndex == 2,
            onTap: () => onDestinationSelected(2),
          ),
          _SidebarItem(
            icon: Icons.animation,
            label: 'Anime',
            isSelected: selectedIndex == 3,
            onTap: () => onDestinationSelected(3),
          ),
           if (settings.enableAdultContent)
            _SidebarItem(
              icon: Icons.lock_outline,
              label: 'Adult',
              isSelected: selectedIndex == 4,
              onTap: () => onDestinationSelected(4),
            ),

          const Spacer(),
          
          const Divider(color: Colors.white10),
          const SizedBox(height: 16),

          // Secondary Items
           _SidebarItem(
            icon: Icons.search,
            label: 'Search',
            isSelected: selectedIndex == searchIndex,
            onTap: () => onDestinationSelected(searchIndex),
          ),
          _SidebarItem(
            icon: Icons.settings_outlined,
            label: 'Settings',
            isSelected: selectedIndex == settingsIndex,
            onTap: () => onDestinationSelected(settingsIndex),
          ),
          
          const SizedBox(height: 16),
          // User Profile (Mock)
          Container(
             padding: const EdgeInsets.all(8),
             decoration: BoxDecoration(
               color: Colors.white10,
               borderRadius: BorderRadius.circular(12),
             ),
             child: Row(
               children: [
                 const CircleAvatar(
                   radius: 16,
                   backgroundColor: Colors.blueGrey,
                   child: Icon(Icons.person, size: 20, color: Colors.white),
                 ),
                 const SizedBox(width: 12),
                 Expanded(
                   child: Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                       Text(
                         profile.activeProfile?.name ?? 'User',
                         style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                       ),
                       const Text(
                         'Premium',
                         style: TextStyle(color: Colors.white54, fontSize: 10),
                       ),
                     ],
                   ),
                 ),
                 const Icon(Icons.more_vert, color: Colors.white54, size: 20),
               ],
             ),
          ),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: isSelected ? Colors.white10 : Colors.transparent, // Active state background
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 22,
                  color: isSelected ? Colors.redAccent : Colors.white70,
                ),
                const SizedBox(width: 16),
                Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white70,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
