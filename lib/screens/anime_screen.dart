import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/library_provider.dart';
import '../widgets/media_card.dart';
import '../widgets/empty_state.dart';
import '../widgets/settings_widgets.dart'; // For AppColors

class AnimeScreen extends StatefulWidget {
  const AnimeScreen({super.key});

  @override
  State<AnimeScreen> createState() => _AnimeScreenState();
}

class _AnimeScreenState extends State<AnimeScreen> {
  @override
  Widget build(BuildContext context) {
    // 1. Get Data
    final shows = context.watch<LibraryProvider>().groupedAnimeShows;
    
    // 2. Map items for display
    final displayItems = shows.map((show) {
      return show.firstEpisode.copyWith(
        title: show.title,
        posterUrl: show.posterUrl ?? show.firstEpisode.posterUrl,
        backdropUrl: show.backdropUrl ?? show.firstEpisode.backdropUrl,
        year: show.year ?? show.firstEpisode.year,
        episode: null,
      );
    }).toList();

    // 3. Determine Featured Anime
    final featuredItem = displayItems.isNotEmpty ? displayItems.first : null;
    final featuredShow = shows.isNotEmpty ? shows.first : null;

    if (shows.isEmpty) return const EmptyState(message: 'No anime found.');

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: CustomScrollView(
        slivers: [
          // 1. SPACER
          const SliverToBoxAdapter(child: SizedBox(height: 80)),

          // 2. HERO BANNER
          if (featuredItem != null)
            SliverToBoxAdapter(
              child: Container(
                height: 300,
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  // Use backdrop if available, else poster, else color
                  image: (featuredItem.backdropUrl != null && featuredItem.backdropUrl!.isNotEmpty)
                      ? DecorationImage(
                          image: NetworkImage(featuredItem.backdropUrl!),
                          fit: BoxFit.cover,
                          alignment: Alignment.topCenter,
                        )
                      : null,
                  color: AppColors.surface, // Fallback color
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter, 
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black.withOpacity(0.9)],
                    ),
                  ),
                  padding: const EdgeInsets.all(24),
                  alignment: Alignment.bottomLeft,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Featured Anime", style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold, fontSize: 12)),
                      Text(
                        featuredItem.title ?? "Untitled", 
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 28),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.play_arrow), 
                        label: const Text("View Details"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent, 
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () {
                           // For anime, we navigate using the show ID or anilist ID logic
                           // Same logic as MediaCard tap
                           if (featuredItem.isAnime && featuredItem.anilistId != null) {
                              final slug = featuredItem.title?.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '-').replaceAll(RegExp(r'-+'), '-') ?? 'anime';
                              context.push('/anime/${featuredItem.anilistId}/$slug', extra: featuredItem);
                           } else {
                              // Fallback
                              context.push('/media/${Uri.encodeComponent(featuredItem.id)}', extra: featuredItem);
                           }
                        },
                      )
                    ],
                  ),
                ),
              ),
            ),

          // 3. FILTERS
          SliverToBoxAdapter(
            child: SizedBox(
              height: 50,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: ["All Anime", "Recently Added", "Favorites", "Action", "Romance", "Fantasy"]
                    .map((e) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Chip(
                            label: Text(e), 
                            backgroundColor: AppColors.surface, 
                            labelStyle: const TextStyle(color: AppColors.textSub, fontSize: 12),
                            side: BorderSide.none,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                        ))
                    .toList(),
              ),
            ),
          ),
          
          const SliverToBoxAdapter(child: SizedBox(height: 20)),

          // 4. THE GRID
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 200, 
                childAspectRatio: 2 / 3,
                crossAxisSpacing: 16,
                mainAxisSpacing: 24,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final show = shows[index];
                  final display = displayItems[index]; // Calculated earlier
                  return MediaCard(item: display, badge: '${show.episodeCount} eps');
                },
                childCount: shows.length,
              ),
            ),
          ),
          
          // Bottom padding
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }
}