import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'settings_widgets.dart'; // For AppColors
import '../models/tmdb_item.dart';
import '../services/tmdb_service.dart';
import 'discover_card.dart';

// 1. THE GLASSMOPRHIC SEARCH BAR
class SearchHeaderDelegate extends SliverPersistentHeaderDelegate {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  SearchHeaderDelegate({required this.controller, required this.onChanged, required this.onClear});

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: AppColors.bg.withOpacity(0.95), // Slight transparency for glass effect
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      alignment: Alignment.center,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: const TextStyle(color: Colors.white, fontSize: 16),
        cursorColor: AppColors.accent,
        decoration: InputDecoration(
          filled: true,
          fillColor: AppColors.surface,
          hintText: 'Search movies, shows, anime...',
          hintStyle: const TextStyle(color: AppColors.textSub),
          prefixIcon: const Icon(LucideIcons.search, color: AppColors.textSub, size: 20),
          suffixIcon: controller.text.isNotEmpty 
            ? IconButton(icon: const Icon(Icons.close, color: AppColors.textSub), onPressed: onClear)
            : null,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.accent, width: 1)),
          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
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

// 2. GENRE PILLS (The "Chips")
class GenreCloud extends StatelessWidget {
  final Function(String) onGenreSelected;
  const GenreCloud({Key? key, required this.onGenreSelected}) : super(key: key);

  final genres = const ["Action", "Sci-Fi", "Anime", "Horror", "Documentary", "Drama", "Comedy", "Thriller"];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 12,
      children: genres.map((g) => InkWell(
        onTap: () => onGenreSelected(g),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Text(g, style: const TextStyle(color: AppColors.textMain, fontSize: 13)),
        ),
      )).toList(),
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
    return ListTile(
      leading: const Icon(LucideIcons.clock, color: AppColors.textSub, size: 18),
      title: Text(text, style: const TextStyle(color: AppColors.textSub)),
      trailing: IconButton(
        icon: const Icon(LucideIcons.x, color: AppColors.textSub, size: 16),
        onPressed: onDelete,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
      dense: true,
      onTap: onTap,
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
          Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
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

// 5. TRENDING LIST
class TrendingHorizontalList extends StatelessWidget {
  const TrendingHorizontalList({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final tmdbService = Provider.of<TmdbService>(context, listen: false);

    return SizedBox(
      height: 250, // Height for posters
      child: FutureBuilder<List<TmdbItem>>(
        future: tmdbService.getTrending(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.accent));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const SizedBox(); // No trending? Hide it.
          }
          final items = snapshot.data!;
          
          return ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              // We'll reuse DiscoverCard but maybe constrain it?
              // DiscoverCard is responsive, so putting it in a Container with width helps.
              return SizedBox(
                width: 140, 
                child: DiscoverCard(item: items[index]),
              );
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
                Icon(LucideIcons.searchX, size: 48, color: AppColors.textSub),
                SizedBox(height: 16),
                Text('No results found', style: TextStyle(color: AppColors.textSub)),
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
        (ctx, i) => DiscoverCard(item: results[i]),
        childCount: results.length,
      ),
    );
  }
}
