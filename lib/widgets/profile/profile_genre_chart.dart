import 'package:flutter/material.dart';
import '../settings_widgets.dart';

/// A horizontal bar chart showing top genres
class ProfileGenreChart extends StatelessWidget {
  final List<MapEntry<String, int>> topGenres;

  const ProfileGenreChart({
    super.key,
    required this.topGenres,
  });

  static const _genreColors = [
    Color(0xFFEF4444), // Red
    Color(0xFFF97316), // Orange
    Color(0xFFEAB308), // Yellow
    Color(0xFF22C55E), // Green
    Color(0xFF3B82F6), // Blue
  ];

  @override
  Widget build(BuildContext context) {
    if (topGenres.isEmpty) {
      return _buildEmptyState();
    }

    final maxValue = topGenres.first.value;

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
                  color: const Color(0xFF8B5CF6).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.category_rounded,
                  color: Color(0xFF8B5CF6),
                  size: 16,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'TOP GENRES',
                style: TextStyle(
                  color: AppColors.textSub,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...topGenres.asMap().entries.map((entry) {
            final index = entry.key;
            final genre = entry.value;
            final percentage = maxValue > 0 ? genre.value / maxValue : 0.0;
            final color = _genreColors[index % _genreColors.length];

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        genre.key,
                        style: const TextStyle(
                          color: AppColors.textMain,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        '${genre.value}',
                        style: TextStyle(
                          color: color,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Stack(
                    children: [
                      Container(
                        height: 8,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.easeOutCubic,
                        height: 8,
                        width: MediaQuery.of(context).size.width * 0.4 * percentage,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [color, color.withOpacity(0.7)],
                          ),
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: [
                            BoxShadow(
                              color: color.withOpacity(0.4),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(
            Icons.pie_chart_rounded,
            color: AppColors.textSub.withOpacity(0.3),
            size: 48,
          ),
          const SizedBox(height: 12),
          Text(
            'No genre data yet',
            style: TextStyle(
              color: AppColors.textSub.withOpacity(0.6),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Watch content to see your preferences',
            style: TextStyle(
              color: AppColors.textSub.withOpacity(0.4),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
