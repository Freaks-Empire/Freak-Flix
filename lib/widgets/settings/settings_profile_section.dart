import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/profile_provider.dart';
import '../settings_widgets.dart';
import 'package:lucide_icons/lucide_icons.dart';

class SettingsProfileSection extends StatelessWidget {
  const SettingsProfileSection({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final profileProvider = context.watch<ProfileProvider>();
    final activeProfile = profileProvider.activeProfile;

    if (activeProfile == null) {
       return const SettingsGroup(
        title: 'Profile',
        children: [
          SettingsTile(
            icon: LucideIcons.userX,
            title: 'No Active Profile',
            subtitle: 'Please select a profile to continue',
            trailing: SizedBox(),
          ),
        ],
      );
    }

    return SettingsGroup(
      title: 'Active Profile',
      children: [
        SettingsTile(
          icon: LucideIcons.user,
          title: activeProfile.name,
          subtitle: 'Currently active',
          trailing: Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: activeProfile.color,
              shape: BoxShape.circle,
            ),
             child: activeProfile.avatarId.startsWith('assets') 
                ? null // Handle asset images if needed, for now null
                : const Icon(Icons.person, color: Colors.white, size: 20),
          ),
          isLast: true,
        ),
        // Add switch profile button as a separate tile or just keep it simple as per design
        // The original design had a "Switch Profile" button.
        // Let's add it as a tile action or a separate tile.
      ],
    );
  }
}
