import 'package:flutter/material.dart';
import '../models/tmdb_item.dart';
import 'discover_card.dart';

class DiscoverSection extends StatefulWidget {
  final String title;
  final List<TmdbItem> items;
  final bool loading;
  final VoidCallback? onRetry;
  final Future<List<TmdbItem>> Function(int page)? onFetchNextPage;

  const DiscoverSection({
    super.key,
    required this.title,
    required this.items,
    this.loading = false,
    this.onRetry,
    this.onFetchNextPage,
  });

  @override
  State<DiscoverSection> createState() => _DiscoverSectionState();
}

class _DiscoverSectionState extends State<DiscoverSection> {
  late List<TmdbItem> _items;
  final ScrollController _scrollController = ScrollController();
  int _currentPage = 1;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _items = widget.items;
    _scrollController.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(DiscoverSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.items != oldWidget.items) {
      // If parent sends new list (e.g. refresh), reset
      setState(() {
        _items = widget.items;
        _currentPage = 1;
        _isLoadingMore = false;
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_isLoadingMore || widget.onFetchNextPage == null) return;

    if (_scrollController.position.extentAfter < 200) {
      _loadNextPage();
    }
  }

  Future<void> _loadNextPage() async {
    setState(() => _isLoadingMore = true);
    try {
      final nextPage = _currentPage + 1;
      final newItems = await widget.onFetchNextPage!(nextPage);
      if (mounted && newItems.isNotEmpty) {
        setState(() {
          _items.addAll(newItems);
          _currentPage = nextPage;
        });
      }
    } catch (e) {
      debugPrint('Error fetching next page: $e');
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Keep sync if parent loading state changes for initial load
    final effectiveLoading = widget.loading && _items.isEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                widget.title,
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, size: 18),
              const Spacer(),
              if (effectiveLoading || _isLoadingMore)
                const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (_items.isEmpty && widget.onRetry != null && !effectiveLoading)
                IconButton(
                  tooltip: 'Retry',
                  icon: const Icon(Icons.refresh),
                  onPressed: widget.onRetry,
                ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 280,
            child: _items.isEmpty
                ? Center(
                    child: Text(
                      effectiveLoading ? 'Loading...' : 'No items',
                      style: theme.textTheme.bodyMedium,
                    ),
                  )
                : ListView.separated(
                    controller: _scrollController,
                    scrollDirection: Axis.horizontal,
                    itemCount: _items.length + (_isLoadingMore ? 1 : 0),
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      if (index >= _items.length) {
                         return const Center(child: Padding(
                           padding: EdgeInsets.all(16.0),
                           child: CircularProgressIndicator(),
                         ));
                      }
                      return DiscoverCard(item: _items[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
