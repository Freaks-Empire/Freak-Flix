import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'settings_widgets.dart'; // For AppColors
import '../models/tmdb_item.dart';
import '../models/media_item.dart';
import '../services/tmdb_service.dart';
import 'discover_card.dart';
import 'package:flutter_animate/flutter_animate.dart';

// 1. THE GLASSMOPRHIC SEARCH BAR
class SearchHeaderDelegate extends SliverPersistentHeaderDelegate {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  SearchHeaderDelegate({required this.controller, required this.onChanged, required this.onClear});

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    // Frosted glass effect
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          color: AppColors.bg.withOpacity(0.7), // Transparent for glass effect
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
          alignment: Alignment.center,
          child: TextField(
            controller: controller,
            onChanged: onChanged,
            style: const TextStyle(color: Colors.white, fontSize: 16),
            cursorColor: AppColors.accent,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white.withOpacity(0.1), // Glassy fill
              hintText: 'Search movies, shows, anime...',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
              prefixIcon: Icon(LucideIcons.search, color: Colors.white.withOpacity(0.5), size: 20),
              suffixIcon: controller.text.isNotEmpty 
                ? IconButton(icon: const Icon(Icons.close, color: Colors.white70), onPressed: onClear)
                : null,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.accent, width: 1)),
              contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
            ),
          ),
        ),
      ),
    );
  }

  @override
  double get maxExtent => 80;
  @override
  double get minExtent => 80;
  @override
  bool shouldRebuild(covariant SearchHeaderDelegate oldDelegate) => true;
}

// 2. GENRE CAROUSEL (The "Chips" turned into Cards)
class GenreCloud extends StatelessWidget {
  final Function(String) onGenreSelected;
  const GenreCloud({Key? key, required this.onGenreSelected}) : super(key: key);

  final List<Map<String, dynamic>> _genres = const [
    {"name": "Action", "colors": [Color(0xFF8E2DE2), Color(0xFF4A00E0)]},
    {"name": "Sci-Fi", "colors": [Color(0xFF00c6ff), Color(0xFF0072ff)]},
    {"name": "Anime", "colors": [Color(0xFFff9966), Color(0xFFff5e62)]},
    {"name": "Horror", "colors": [Color(0xFF000000), Color(0xFF434343)]},
    {"name": "Docs", "colors": [Color(0xFF11998e), Color(0xFF38ef7d)]},
    {"name": "Drama", "colors": [Color(0xFF5f2c82), Color(0xFF49a09d)]},
    {"name": "Comedy", "colors": [Color(0xFFf7971e), Color(0xFFffd200)]},
    {"name": "Thriller", "colors": [Color(0xFFC33764), Color(0xFF1D2671)]},
    {"name": "Adult", "colors": [Color(0xFFFF416C), Color(0xFFFF4B2B)]}, // Added Adult
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 60,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: _genres.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final g = _genres[index];
          return InkWell(
            onTap: () => onGenreSelected(g['name']),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 110,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  colors: g['colors'],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(color: (g['colors'][0] as Color).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                g['name'],
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  shadows: [Shadow(color: Colors.black45, blurRadius: 2)],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// 3. RECENT SEARCH ROW
class RecentSearchTile extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const RecentSearchTile({Key? key, required this.text, required this.onTap, required this.onDelete}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Row(
            children: [
              const Icon(LucideIcons.history, color: AppColors.textSub, size: 18),
              const SizedBox(width: 16),
              Expanded(child: Text(text, style: const TextStyle(color: AppColors.textMain, fontSize: 16))),
              IconButton(
                icon: const Icon(LucideIcons.x, color: AppColors.textSub, size: 16),
                onPressed: onDelete,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// 4. SECTION HEADER
class SectionHeader extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;
  const SectionHeader({Key? key, required this.title, this.action, this.onAction}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
          if (action != null)
            GestureDetector(
              onTap: onAction,
              child: Text(action!, style: const TextStyle(color: AppColors.accent, fontSize: 13, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
    );
  }
}

// 5. GENERIC CONTENT ROW (Was TrendingHorizontalList)
class ContentRow extends StatelessWidget {
  final Future<List<dynamic>> future; // Accepts TmdbItem or MediaItem
  final bool isPortrait; // For Adult/Scenes vs Movies
  
  const ContentRow({
    Key? key, 
    required this.future, 
    this.isPortrait = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      // Adjust height based on aspect ratio approx
      height: isPortrait ? 250 : 180, 
      child: FutureBuilder<List<dynamic>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.accent));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const SizedBox(); 
          }
          final items = snapshot.data!;
          
          return ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final item = items[index];
              
              // Handle both TmdbItem and MediaItem
              TmdbItem tmdbItem;
              if (item is MediaItem) {
                 // Convert MediaItem (Stash) to TmdbItem wrapper for DiscoverCard
                 tmdbItem = TmdbItem(
                   id: int.tryParse(item.tmdbId?.toString() ?? '0') ?? 0, 
                   title: item.title ?? 'Unknown',
                   overview: item.overview ?? '',
                   posterUrl: item.posterUrl ?? item.filePath, // Use screenshot if poster missing
                   backdropUrl: item.backdropUrl,
                   voteAverage: item.rating,
                   releaseYear: item.year,
                   type: item.type == MediaType.movie ? TmdbMediaType.movie : TmdbMediaType.tv, // Stash usually scenes
                 );
              } else {
                tmdbItem = item as TmdbItem;
              }

              return SizedBox(
                width: isPortrait ? 140 : 220, 
                child: DiscoverCard(item: tmdbItem, showOverlays: false, showTitle: true),
              ).animate().fade().slideX(begin: 0.2, end: 0, delay: Duration(milliseconds: 50 * index), duration: 400.ms, curve: Curves.easeOut);
            },
          );
        },
      ),
    );
  }
}

// 6. SEARCH RESULTS GRID
class SearchResultsGrid extends StatelessWidget {
  final List<TmdbItem> results;
  const SearchResultsGrid({Key? key, required this.results}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.only(top: 80),
          child: Center(
            child: Column(
              children: [
                Icon(LucideIcons.searchX, size: 64, color: Colors.white10),
                SizedBox(height: 16),
                Text('No results found', style: TextStyle(color: AppColors.textSub, fontSize: 16)),
              ],
            ),
          ),
        ),
      );
    }

    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 200,
        childAspectRatio: 0.65,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      delegate: SliverChildBuilderDelegate(
        (ctx, i) => DiscoverCard(item: results[i]), // Full overlays for search results
        childCount: results.length,
      ),
    );
  }
}

