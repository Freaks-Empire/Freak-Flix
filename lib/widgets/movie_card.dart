import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'settings_widgets.dart'; // Reuse AppColors

class MovieCard extends StatelessWidget {
  final String title;
  final String year;
  final String? posterUrl;
  final VoidCallback onTap;

  const MovieCard({
    super.key,
    required this.title,
    required this.year,
    this.posterUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. THE POSTER
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4)),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Image or Fallback
                  if (posterUrl != null && posterUrl!.isNotEmpty)
                    CachedNetworkImage(
                      imageUrl: posterUrl!,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(color: AppColors.surface),
                      errorWidget: (context, url, error) => const _FallbackPoster(),
                    )
                  else
                    const _FallbackPoster(),

                  // Gradient Overlay (For text readability on hover, or permanent subtle shadow)
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black54],
                        stops: [0.7, 1.0],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // 2. MINIMALIST METADATA
          const SizedBox(height: 8),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
          ),
          Text(
            year,
            style: const TextStyle(color: AppColors.textSub, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _FallbackPoster extends StatelessWidget {
  const _FallbackPoster();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface, // Zinc 900
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.movie_creation_outlined, color: AppColors.textSub.withOpacity(0.3), size: 48),
        ],
      ),
    );
  }
}
