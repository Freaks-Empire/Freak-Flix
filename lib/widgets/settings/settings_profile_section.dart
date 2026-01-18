import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import '../../providers/profile_provider.dart';
import '../../providers/library_provider.dart';
import '../../screens/manage_profile_screen.dart';
import '../../models/user_profile.dart';
import '../../models/media_item.dart';
import '../settings_widgets.dart';
import '../profile/profile_stat_card.dart';
import '../profile/profile_activity_chart.dart';
import '../profile/profile_genre_chart.dart';
import '../profile/profile_recent_activity.dart';

class SettingsProfileSection extends StatelessWidget {
  const SettingsProfileSection({super.key});

  @override
  Widget build(BuildContext context) {
    final profileProvider = context.watch<ProfileProvider>();
    final libraryProvider = context.watch<LibraryProvider>();
    final activeProfile = profileProvider.activeProfile;

    if (activeProfile == null) {
      return _buildNoProfileState();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Profile Header
        _buildProfileHeader(context, activeProfile),
        
        const SizedBox(height: 32),
        
        // Statistics Cards
        _buildStatisticsGrid(libraryProvider, activeProfile),
        
        const SizedBox(height: 24),
        
        // Watch Activity Chart
        ProfileActivityChart(
          activityByDay: libraryProvider.watchActivityByDay,
        ),
        
        const SizedBox(height: 24),
        
        // Two-column layout for Genre Chart and Quick Stats
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth >= 600) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: ProfileGenreChart(
                      topGenres: libraryProvider.topGenres(5),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildQuickActions(context),
                  ),
                ],
              );
            }
            return Column(
              children: [
                ProfileGenreChart(
                  topGenres: libraryProvider.topGenres(5),
                ),
                const SizedBox(height: 24),
                _buildQuickActions(context),
              ],
            );
          },
        ),
        
        const SizedBox(height: 24),
        
        // Recent Activity
        ProfileRecentActivity(
          recentItems: libraryProvider.recentActivity.take(20).toList(),
        ),
        
        const SizedBox(height: 24),
        
        // Watch History Summary
        _buildHistorySummary(context, libraryProvider),
      ],
    );
  }

  Widget _buildNoProfileState() {
    return Container(
      padding: const EdgeInsets.all(48),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              LucideIcons.userX,
              color: AppColors.accent,
              size: 48,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'No Active Profile',
            style: TextStyle(
              color: AppColors.textMain,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Please select a profile to continue',
            style: TextStyle(
              color: AppColors.textSub.withOpacity(0.7),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(BuildContext context, UserProfile activeProfile) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            activeProfile.color.withOpacity(0.2),
            AppColors.surface,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: activeProfile.color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Avatar with accent ring
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  activeProfile.color,
                  activeProfile.color.withOpacity(0.6),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: activeProfile.color.withOpacity(0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.bg,
                  width: 3,
                ),
              ),
              child: ClipOval(
                child: activeProfile.avatarId.startsWith('assets')
                    ? Image.asset(
                        activeProfile.avatarId,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.person,
                          color: activeProfile.color,
                          size: 36,
                        ),
                      )
                    : Icon(
                        Icons.person,
                        color: activeProfile.color,
                        size: 36,
                      ),
              ),
            ),
          ),
          const SizedBox(width: 20),
          // Profile Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activeProfile.name,
                  style: const TextStyle(
                    color: AppColors.textMain,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF22C55E).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Color(0xFF22C55E),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'Currently active',
                        style: TextStyle(
                          color: Color(0xFF22C55E),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Edit Button
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ManageProfileScreen(profile: activeProfile),
                ),
              );
            },
            icon: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.border.withOpacity(0.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                LucideIcons.settings2,
                color: AppColors.textSub,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsGrid(LibraryProvider library, dynamic profile) {
    final watchTimeSeconds = library.totalWatchTimeSeconds;
    final watchTimeFormatted = formatWatchTime(watchTimeSeconds);
    
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth >= 600 ? 4 : 2;
        final childAspectRatio = constraints.maxWidth >= 600 ? 1.3 : 1.4;
        
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: childAspectRatio,
          children: [
            ProfileStatCard(
              icon: LucideIcons.clock,
              value: watchTimeFormatted,
              label: 'Watch Time',
              accentColor: const Color(0xFF8B5CF6),
            ),
            ProfileStatCard(
              icon: LucideIcons.film,
              value: '${library.watchedMoviesCount}',
              label: 'Movies Watched',
              accentColor: const Color(0xFFF97316),
            ),
            ProfileStatCard(
              icon: LucideIcons.tv,
              value: '${library.watchedEpisodesCount}',
              label: 'Episodes',
              accentColor: const Color(0xFF06B6D4),
            ),
            ProfileStatCard(
              icon: LucideIcons.library,
              value: '${library.totalLibraryCount}',
              label: 'Library Size',
              accentColor: const Color(0xFF22C55E),
            ),
          ],
        );
      },
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF97316).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.bolt_rounded,
                  color: Color(0xFFF97316),
                  size: 16,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'QUICK ACTIONS',
                style: TextStyle(
                  color: AppColors.textSub,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildActionTile(
            icon: LucideIcons.userCog,
            title: 'Edit Profile',
            subtitle: 'Change name, avatar, color',
            onTap: () {
              final profile = context.read<ProfileProvider>().activeProfile;
              if (profile != null) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ManageProfileScreen(profile: profile),
                  ),
                );
              }
            },
          ),
          const Divider(color: AppColors.border, height: 1),
          _buildActionTile(
            icon: LucideIcons.users,
            title: 'Switch Profile',
            subtitle: 'Choose a different profile',
            onTap: () {
              // Deselect current profile to trigger redirect to profile selection
              context.read<ProfileProvider>().deselectProfile();
              context.go('/profiles');
            },
          ),
          const Divider(color: AppColors.border, height: 1),
          _buildActionTile(
            icon: LucideIcons.trash2,
            title: 'Clear Watch History',
            subtitle: 'Reset your activity data',
            isDestructive: true,
            onTap: () {
              _showClearHistoryDialog(context);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final color = isDestructive ? AppColors.accent : AppColors.textMain;
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: color,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: AppColors.textSub.withOpacity(0.7),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                LucideIcons.chevronRight,
                color: AppColors.textSub.withOpacity(0.5),
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHistorySummary(BuildContext context, LibraryProvider library) {
    final historyItems = library.historyItems;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF22C55E).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF22C55E),
                  size: 16,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'COMPLETED',
                style: TextStyle(
                  color: AppColors.textSub,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                ),
              ),
              const Spacer(),
              Text(
                '${historyItems.length} items',
                style: TextStyle(
                  color: AppColors.textSub.withOpacity(0.6),
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (historyItems.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Icon(
                      Icons.movie_filter_outlined,
                      color: AppColors.textSub.withOpacity(0.3),
                      size: 40,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No completed items yet',
                      style: TextStyle(
                        color: AppColors.textSub.withOpacity(0.6),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            SizedBox(
              height: 200,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: historyItems.length > 20 ? 20 : historyItems.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final item = historyItems[index];
                  return _buildCompletedCard(context, item);
                },
              ),
            ),
          if (historyItems.length > 20)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                '+ ${historyItems.length - 20} more',
                style: TextStyle(
                  color: AppColors.textSub.withOpacity(0.6),
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCompletedCard(BuildContext context, MediaItem item) {
    final posterUrl = item.posterUrl;
    
    return GestureDetector(
      onTap: () => context.push('/media/${item.id}', extra: item),
      child: SizedBox(
        width: 110,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Poster with completed badge
            Stack(
              children: [
                Container(
                  width: 110,
                  height: 150,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(8),
                    image: posterUrl != null
                        ? DecorationImage(
                            image: NetworkImage(posterUrl),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: posterUrl == null
                      ? Center(
                          child: Icon(
                            LucideIcons.film,
                            color: AppColors.textSub.withOpacity(0.3),
                            size: 32,
                          ),
                        )
                      : null,
                ),
                // Completed badge
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Color(0xFF22C55E),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Title
            Text(
              item.title ?? item.fileName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textMain,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }


  void _showClearHistoryDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border),
        ),
        title: const Row(
          children: [
            Icon(LucideIcons.alertTriangle, color: AppColors.accent, size: 24),
            SizedBox(width: 12),
            Text(
              'Clear Watch History?',
              style: TextStyle(color: AppColors.textMain, fontSize: 18),
            ),
          ],
        ),
        content: Text(
          'This will reset all your watch progress and history for this profile. This action cannot be undone.',
          style: TextStyle(
            color: AppColors.textSub.withOpacity(0.8),
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSub),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () {
              // Clear the user data for current profile
              final profileProvider = context.read<ProfileProvider>();
              profileProvider.importUserData({});
              Navigator.of(ctx).pop();
              
              // Show success snackbar
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.white),
                      SizedBox(width: 12),
                      Text('Watch history cleared'),
                    ],
                  ),
                  backgroundColor: const Color(0xFF22C55E),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              );
            },
            child: const Text('Clear History'),
          ),
        ],
      ),
    );
  }
}
