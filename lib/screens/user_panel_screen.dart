// User Panel Screen - The user's "Command Center"
// 
// A comprehensive screen for managing user profile, quick actions,
// service integrations, and app settings.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/profile_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/settings_widgets.dart';

class UserPanelScreen extends StatelessWidget {
  const UserPanelScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ProfileProvider>(
      builder: (context, profileProvider, _) {
        final profile = profileProvider.activeProfile;
        final settings = context.watch<SettingsProvider>();

        return Scaffold(
          backgroundColor: AppColors.bg,
          body: CustomScrollView(
            slivers: [
              // Header with SliverAppBar.large
              _buildHeader(context, profile),

              // Quick Actions Section
              _buildQuickActions(context),

              // Integration Health Dashboard
              _buildIntegrationDashboard(context, settings),

              // Settings Navigation List
              _buildSettingsList(context),

              // Footer
              _buildFooter(context, profileProvider),

              // Bottom padding
              const SliverToBoxAdapter(
                child: SizedBox(height: 100),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Builds the header section with SliverAppBar.large
  Widget _buildHeader(BuildContext context, dynamic profile) {
    final userName = profile?.name ?? 'Guest';
    final avatarId = profile?.avatarId ?? 'assets/logo.png';
    final profileColor = profile?.color ?? Colors.blue;

    return SliverAppBar.large(
      backgroundColor: AppColors.bg,
      pinned: true,
      expandedHeight: 200,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: AppColors.textMain),
        onPressed: () => context.pop(),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                profileColor.withOpacity(0.6),
                AppColors.bg,
              ],
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 16),
                // Large Circular Avatar
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: profileColor,
                      width: 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: profileColor.withOpacity(0.4),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: _buildAvatar(avatarId, profileColor),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
        title: Text(
          userName,
          style: const TextStyle(
            color: AppColors.textMain,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
    );
  }

  /// Builds the avatar widget from asset or fallback
  Widget _buildAvatar(String avatarId, Color fallbackColor) {
    // Check if it's an asset path
    if (avatarId.startsWith('assets/')) {
      return Image.asset(
        avatarId,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildFallbackAvatar(fallbackColor);
        },
      );
    }

    // Default fallback
    return _buildFallbackAvatar(fallbackColor);
  }

  /// Builds a fallback avatar with user icon
  Widget _buildFallbackAvatar(Color color) {
    return Container(
      color: color.withAlpha((0.3 * 255).round()),
      child: const Icon(
        Icons.person,
        size: 40,
        color: AppColors.textMain,
      ),
    );
  }

  /// Builds the Quick Actions section
  Widget _buildQuickActions(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(left: 4, bottom: 12),
              child: Text(
                'QUICK ACTIONS',
                style: TextStyle(
                  color: AppColors.textSub,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                ),
              ),
            ),
            Row(
              children: [
                _QuickActionCard(
                  icon: Icons.history,
                  label: 'History',
                  onTap: () {
                    // TODO: Navigate to history screen
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('History - Coming Soon')),
                    );
                  },
                ),
                const SizedBox(width: 12),
                _QuickActionCard(
                  icon: Icons.bookmark_outline,
                  label: 'Watchlist',
                  onTap: () {
                    // TODO: Navigate to watchlist screen
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Watchlist - Coming Soon')),
                    );
                  },
                ),
                const SizedBox(width: 12),
                _QuickActionCard(
                  icon: Icons.favorite_outline,
                  label: 'Favorites',
                  onTap: () {
                    // TODO: Navigate to favorites screen
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Favorites - Coming Soon')),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the Integration Health Dashboard section
  Widget _buildIntegrationDashboard(BuildContext context, SettingsProvider settings) {
    // Determine connection statuses
    final hasTmdb = settings.hasTmdbKey && settings.tmdbStatus == TmdbKeyStatus.valid;
    final hasStash = settings.stashEndpoints.any((e) => e.apiKey.isNotEmpty);
    // Trakt and AniList use environment keys, so we check if they're configured
    const hasTrakt = false; // No user-configurable Trakt auth yet
    const hasAniList = true; // AniList uses public GraphQL, always available

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(left: 4, bottom: 12),
              child: Text(
                'INTEGRATIONS',
                style: TextStyle(
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
                children: [
                  _ServiceStatusTile(
                    serviceName: 'TMDB',
                    icon: Icons.movie_outlined,
                    isConnected: hasTmdb,
                    onAction: () => context.go('/settings'),
                  ),
                  const Divider(height: 1, color: AppColors.border),
                  _ServiceStatusTile(
                    serviceName: 'AniList',
                    icon: Icons.animation_outlined,
                    isConnected: hasAniList,
                    onAction: () => context.go('/settings'),
                  ),
                  const Divider(height: 1, color: AppColors.border),
                  _ServiceStatusTile(
                    serviceName: 'Trakt',
                    icon: Icons.tv_outlined,
                    isConnected: hasTrakt,
                    onAction: () => context.go('/settings'),
                  ),
                  const Divider(height: 1, color: AppColors.border),
                  _ServiceStatusTile(
                    serviceName: 'StashDB',
                    icon: Icons.theaters_outlined,
                    isConnected: hasStash,
                    onAction: () => context.go('/settings'),
                    isLast: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the Settings Navigation List
  Widget _buildSettingsList(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: SettingsGroup(
          title: 'Settings',
          children: [
            SettingsTile(
              icon: Icons.settings_outlined,
              title: 'General Settings',
              subtitle: 'Theme, Player, Preferences',
              trailing: const Icon(Icons.chevron_right, color: AppColors.textSub),
              onTap: () => context.go('/settings'),
            ),
            const Divider(height: 1, color: AppColors.border),
            SettingsTile(
              icon: Icons.folder_outlined,
              title: 'Source Manager',
              subtitle: 'OneDrive, Local Folders',
              trailing: const Icon(Icons.chevron_right, color: AppColors.textSub),
              onTap: () => context.go('/settings'),
            ),
            const Divider(height: 1, color: AppColors.border),
            SettingsTile(
              icon: Icons.people_outline,
              title: 'Profile Management',
              subtitle: 'Switch Profile, Edit Profile',
              trailing: const Icon(Icons.chevron_right, color: AppColors.textSub),
              onTap: () => context.go('/profiles'),
              isLast: true,
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the Footer section with version and logout
  Widget _buildFooter(BuildContext context, ProfileProvider profileProvider) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
        child: Column(
          children: [
            // Version Info
            const Text(
              'Freak-Flix v1.0.366.0',
              style: TextStyle(
                color: AppColors.textSub,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 16),
            // Log Out Button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  _showLogoutConfirmation(context, profileProvider);
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  side: const BorderSide(color: Colors.redAccent),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.logout),
                label: const Text(
                  'Log Out',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Shows logout confirmation dialog
  void _showLogoutConfirmation(BuildContext context, ProfileProvider profileProvider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Log Out',
          style: TextStyle(color: AppColors.textMain),
        ),
        content: const Text(
          'Are you sure you want to log out of your profile?',
          style: TextStyle(color: AppColors.textSub),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              profileProvider.deselectProfile();
              context.go('/profiles');
            },
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
  }
}

/// Quick Action Card Widget
class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 28,
                  color: AppColors.accent,
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.textMain,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
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

/// Service Status Tile for Integration Dashboard
class _ServiceStatusTile extends StatelessWidget {
  final String serviceName;
  final IconData icon;
  final bool isConnected;
  final VoidCallback onAction;
  final bool isLast;

  const _ServiceStatusTile({
    required this.serviceName,
    required this.icon,
    required this.isConnected,
    required this.onAction,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onAction,
        borderRadius: isLast
            ? const BorderRadius.vertical(bottom: Radius.circular(12))
            : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              // Service Icon
              Icon(
                icon,
                size: 22,
                color: AppColors.textSub,
              ),
              const SizedBox(width: 14),
              // Service Name
              Expanded(
                child: Text(
                  serviceName,
                  style: const TextStyle(
                    color: AppColors.textMain,
                    fontSize: 15,
                  ),
                ),
              ),
              // Status Indicator
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isConnected
                      ? Colors.green.withAlpha((0.15 * 255).round())
                      : Colors.grey.withAlpha((0.15 * 255).round()),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isConnected ? Icons.check_circle : Icons.cancel,
                      size: 14,
                      color: isConnected ? Colors.green : Colors.grey,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isConnected ? 'Sync Now' : 'Connect',
                      style: TextStyle(
                        color: isConnected ? Colors.green : Colors.grey,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
