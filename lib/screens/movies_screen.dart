import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/library_provider.dart';
import '../widgets/movie_card.dart';
import '../widgets/settings_widgets.dart';
import '../widgets/empty_state.dart';

class MoviesScreen extends StatefulWidget {
  const MoviesScreen({Key? key}) : super(key: key);

  @override
  State<MoviesScreen> createState() => _MoviesScreenState();
}

class _MoviesScreenState extends State<MoviesScreen> {
  @override
  Widget build(BuildContext context) {
    // 1. Get Data
    final provider = context.watch<LibraryProvider>();
    final allMovies = provider.movies;
    
    // 2. Determine Featured Movie (Random or specific if available)
    // For now, let's grab the first one, or random if we wanted.
    // Ideally, we'd have a 'featured' flag or a method to get a random item.
    // Let's just take the first movie for now as the "Trending" one if available.
    final featuredMovie = allMovies.isNotEmpty ? allMovies.first : null;

    if (allMovies.isEmpty && !provider.isLoading) {
      return const EmptyState(message: 'No movies found.');
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: CustomScrollView(
        slivers: [
          // 1. SPACER (Push content below floating Dock)
          const SliverToBoxAdapter(child: SizedBox(height: 80)),

          // 2. HERO BANNER (Featured Movie)
          if (featuredMovie != null)
            SliverToBoxAdapter(
              child: Container(
                height: 300,
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  // Use backdrop if available, else poster, else color
                  image: (featuredMovie.backdropUrl != null && featuredMovie.backdropUrl!.isNotEmpty)
                      ? DecorationImage(
                          image: NetworkImage(featuredMovie.backdropUrl!),
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
                      const Text("Featured Movie", style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold, fontSize: 12)),
                      Text(
                        featuredMovie.title ?? "Untitled", 
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
                          context.push('/details', extra: featuredMovie);
                        },
                      )
                    ],
                  ),
                ),
              ),
            ),

          // 3. FILTERS (Simulated for now, can be hooked up later)
          SliverToBoxAdapter(
            child: SizedBox(
              height: 50,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: ["All Movies", "Recently Added", "4K HDR", "Action", "Comedy", "Sci-Fi"]
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
                maxCrossAxisExtent: 200, // Cards will be ~200px wide
                childAspectRatio: 0.65,  // Portrait poster ratio
                crossAxisSpacing: 16,
                mainAxisSpacing: 24,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final movie = allMovies[index];
                  return MovieCard(
                    title: movie.title ?? "Unknown",
                    year: movie.year?.toString() ?? "",
                    posterUrl: movie.posterUrl,
                    onTap: () {
                      context.push('/details', extra: movie);
                    },
                  );
                },
                childCount: allMovies.length,
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