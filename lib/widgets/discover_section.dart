import 'package:flutter/material.dart';
import '../models/tmdb_item.dart';
import 'discover_card.dart';

class DiscoverSection extends StatelessWidget {
  final String title;
  final List<TmdbItem> items;
  final bool loading;
  final VoidCallback? onRetry;

  const DiscoverSection({
    super.key,
    required this.title,
    required this.items,
    this.loading = false,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, size: 18),
              const Spacer(),
              if (loading)
                const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (items.isEmpty && onRetry != null)
                IconButton(
                  tooltip: 'Retry',
                  icon: const Icon(Icons.refresh),
                  onPressed: onRetry,
                ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 240,
            child: items.isEmpty
                ? Center(
                    child: Text(
                      loading ? 'Loading...' : 'No items',
                      style: theme.textTheme.bodyMedium,
                    ),
                  )
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, index) => DiscoverCard(item: items[index]),
                  ),
          ),
        ],
      ),
    );
  }
}
