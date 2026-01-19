import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import '../../models/media_item.dart';
import '../settings_widgets.dart';

/// A horizontal scrollable list showing recent watch activity
class ProfileRecentActivity extends StatelessWidget {
  final List<MediaItem> recentItems;
  final void Function(MediaItem)? onItemTap;

  const ProfileRecentActivity({
    super.key,
    required this.recentItems,
    this.onItemTap,
  });

  @override
  Widget build(BuildContext context) {
    if (recentItems.isEmpty) {
      return _buildEmptyState();
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF06B6D4).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(
                    Icons.history_rounded,
                    color: Color(0xFF06B6D4),
                    size: 16,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'RECENT ACTIVITY',
                  style: TextStyle(
                    color: AppColors.textSub,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                  ),
                ),
                const Spacer(),
                Text(
                  '${recentItems.length} items',
                  style: TextStyle(
                    color: AppColors.textSub.withOpacity(0.6),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 180,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              itemCount: recentItems.length.clamp(0, 20),
              itemBuilder: (context, index) {
                final item = recentItems[index];
                return _buildActivityItem(context, item);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityItem(BuildContext context, MediaItem item) {
    final progress = _calculateProgress(item);
    
    return GestureDetector(
      onTap: () {
        // Use custom callback if provided, otherwise navigate to media details
        if (onItemTap != null) {
          onItemTap!(item);
        } else {
          context.push('/media/${Uri.encodeComponent(item.id)}', extra: item);
        }
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          width: 100,
          margin: const EdgeInsets.only(right: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Poster with progress overlay
              Expanded(
                child: Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: item.posterUrl != null
                            ? CachedNetworkImage(
                                imageUrl: item.posterUrl!,
                                fit: BoxFit.cover,
                                width: 100,
                                height: double.infinity,
                                placeholder: (_, __) => Container(
                                  color: AppColors.border,
                                  child: const Center(
                                    child: Icon(
                                      Icons.movie_outlined,
                                      color: AppColors.textSub,
                                    ),
                                  ),
                                ),
                                errorWidget: (_, __, ___) => Container(
                                  color: AppColors.border,
                                  child: const Center(
                                    child: Icon(
                                      Icons.broken_image_outlined,
                                      color: AppColors.textSub,
                                    ),
                                  ),
                                ),
                              )
                            : Container(
                                color: AppColors.border,
                                child: const Center(
                                  child: Icon(
                                    Icons.movie_outlined,
                                    color: AppColors.textSub,
                                    size: 32,
                                  ),
                                ),
                              ),
                      ),
                    ),
                    // Watched badge
                    if (item.isWatched)
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF22C55E),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 12,
                          ),
                        ),
                      ),
                    // Progress bar at bottom
                    if (!item.isWatched && progress > 0)
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            borderRadius: const BorderRadius.only(
                              bottomLeft: Radius.circular(8),
                              bottomRight: Radius.circular(8),
                            ),
                          ),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: progress,
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppColors.accent,
                                borderRadius: const BorderRadius.only(
                                  bottomLeft: Radius.circular(8),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                item.title ?? item.fileName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textMain,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  double _calculateProgress(MediaItem item) {
    if (item.isWatched) return 1.0;
    if (item.lastPositionSeconds <= 0) return 0.0;
    
    final total = item.totalDurationSeconds ?? 
        (item.runtimeMinutes != null ? item.runtimeMinutes! * 60 : 0);
    
    if (total <= 0) return 0.0;
    return (item.lastPositionSeconds / total).clamp(0.0, 1.0);
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(
            Icons.play_circle_outline_rounded,
            color: AppColors.textSub.withOpacity(0.3),
            size: 56,
          ),
          const SizedBox(height: 16),
          Text(
            'No watch history yet',
            style: TextStyle(
              color: AppColors.textSub.withOpacity(0.7),
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start watching content to build your activity history',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSub.withOpacity(0.5),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
