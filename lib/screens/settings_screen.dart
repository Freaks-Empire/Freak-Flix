import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../widgets/settings_widgets.dart';
import '../widgets/activity_command_center.dart';

// Modular Sections
import '../widgets/settings/settings_profile_section.dart';
import '../widgets/settings/settings_library_section.dart';
import '../widgets/settings/settings_metadata_section.dart';
import '../widgets/settings/settings_sync_section.dart';
import '../widgets/settings/settings_advanced_section.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    // Determine if we are on mobile or desktop/tablet (roughly)
    // The NavigationRail is best for landscape. For strict mobile portrait, 
    // a BottomNavigationBar or Drawer might be better, but the user requested NavigationRail.
    // We will assume a responsive-ish approach or enforce it. 
    // Given "Settings Shell" request, likely Desktop/Tablet focus or generic.
    
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Row(
          children: [
            // SIDEBAR (NavigationRail)
            NavigationRail(
              backgroundColor: AppColors.bg,
              selectedIndex: _selectedIndex,
              onDestinationSelected: (int index) {
                setState(() {
                  _selectedIndex = index;
                });
              },
              labelType: NavigationRailLabelType.all,
              indicatorColor: AppColors.accent.withOpacity(0.2),
              selectedIconTheme: const IconThemeData(color: AppColors.accent),
              unselectedIconTheme: const IconThemeData(color: AppColors.textSub),
              unselectedLabelTextStyle: const TextStyle(color: AppColors.textSub, fontSize: 11),
              selectedLabelTextStyle: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold, fontSize: 11),
              
              leading: Padding(
                padding: const EdgeInsets.only(bottom: 20, top: 20),
                child: IconButton(
                  icon: const Icon(LucideIcons.arrowLeft, color: AppColors.textMain),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              
              destinations: const [
                NavigationRailDestination(icon: Icon(LucideIcons.user), label: Text('Profile')),
                NavigationRailDestination(icon: Icon(LucideIcons.library), label: Text('Library')),
                NavigationRailDestination(icon: Icon(LucideIcons.database), label: Text('Metadata')),
                NavigationRailDestination(icon: Icon(LucideIcons.cloud), label: Text('Sync')),
                NavigationRailDestination(icon: Icon(LucideIcons.settings), label: Text('Advanced')),
              ],
            ),
            
            // VERTICAL DIVIDER
            const VerticalDivider(thickness: 1, width: 1, color: AppColors.border),

            // MAIN CONTENT AREA
            Expanded(
              child: Column(
                children: [
                  // Global Status Bar (Activity)
                  const Padding(
                    padding: EdgeInsets.fromLTRB(24, 24, 24, 0),
                    child: ActivityCommandCenter(),
                  ),

                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.only(
                        left: 32, 
                        right: 32, 
                        bottom: 32,
                        top: 100, // Safe Area for Navigation Dock
                      ),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 900),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header
                            Text(
                              _getTitleForIndex(_selectedIndex),
                              style: const TextStyle(color: AppColors.textMain, fontSize: 32, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _getSubtitleForIndex(_selectedIndex),
                              style: const TextStyle(color: AppColors.textSub, fontSize: 16),
                            ),
                            const SizedBox(height: 30),
                            
                            // The Content
                            _buildContentForIndex(_selectedIndex),
                            
                            const SizedBox(height: 64),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getTitleForIndex(int index) {
    switch (index) {
      case 0: return 'Profile & Accounts';
      case 1: return 'Libraries & Scanning';
      case 2: return 'Metadata Providers';
      case 3: return 'Sync & Backup';
      case 4: return 'Advanced Settings';
      default: return 'Settings';
    }
  }

    String _getSubtitleForIndex(int index) {
    switch (index) {
      case 0: return 'Manage your identity and watching preferences';
      case 1: return 'Configure local folders and cloud storage';
      case 2: return 'External services for media information';
       case 3: return 'Keep your data safe and synchronized';
      case 4: return 'System configuration and hidden features';
      default: return '';
    }
  }

  Widget _buildContentForIndex(int index) {
    switch (index) {
      case 0: return const SettingsProfileSection();
      case 1: return const SettingsLibrarySection();
      case 2: return const SettingsMetadataSection();
      case 3: return const SettingsSyncSection();
      case 4: return const SettingsAdvancedSection();
      default: return const SizedBox();
    }
  }
}
