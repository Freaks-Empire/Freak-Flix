import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/discover_filter.dart';

import '../services/tmdb_discover_service.dart';
import '../widgets/discover_filter_sheet.dart';
import '../widgets/discover_section.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  DiscoverBundle _bundle = DiscoverBundle.empty;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final filter = context.read<DiscoverFilterNotifier>().filter;
      final service = context.read<TmdbDiscoverService>();
      final bundle = await service.fetchAll(filter: filter);
      if (!mounted) return;
      setState(() => _bundle = bundle);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openFilters() async {
    final notifier = context.read<DiscoverFilterNotifier>();
    final updated = await showModalBottomSheet<DiscoverFilter>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DiscoverFilterSheet(initial: notifier.filter),
    );
    if (updated != null) {
      notifier.update(updated);
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      appBar: AppBar(
        title: const Text('Discover'),
        actions: [
          IconButton(
            tooltip: 'Filters',
            icon: const Icon(Icons.tune),
            onPressed: _openFilters,
          ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      body: _error != null
          ? _ErrorState(message: _error!, onRetry: _load)
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                children: [
                  DiscoverSection(
                    title: 'Trending',
                    items: _bundle.trending,
                    loading: _loading,
                    onRetry: _load,
                    onFetchNextPage: (p) => context.read<TmdbDiscoverService>().fetchTrending(filter: context.read<DiscoverFilterNotifier>().filter, page: p),
                  ),
                  DiscoverSection(
                    title: 'Recommended',
                    items: _bundle.recommended,
                    loading: _loading,
                    onRetry: _load,
                    onFetchNextPage: (p) => context.read<TmdbDiscoverService>().fetchRecommended(filter: context.read<DiscoverFilterNotifier>().filter, page: p),
                  ),
                  DiscoverSection(
                    title: 'Popular',
                    items: _bundle.popular,
                    loading: _loading,
                    onRetry: _load,
                    onFetchNextPage: (p) => context.read<TmdbDiscoverService>().fetchPopular(filter: context.read<DiscoverFilterNotifier>().filter, page: p),
                  ),
                  DiscoverSection(
                    title: 'Upcoming',
                    items: _bundle.upcoming,
                    loading: _loading,
                    onRetry: _load,
                    onFetchNextPage: (p) => context.read<TmdbDiscoverService>().fetchUpcoming(filter: context.read<DiscoverFilterNotifier>().filter, page: p),
                  ),
                  DiscoverSection(
                    title: 'Top Rated',
                    items: _bundle.topRated,
                    loading: _loading,
                    onRetry: _load,
                    onFetchNextPage: (p) => context.read<TmdbDiscoverService>().fetchTopRated(filter: context.read<DiscoverFilterNotifier>().filter, page: p),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 38, color: theme.colorScheme.error),
            const SizedBox(height: 8),
            Text(
              'Could not load Discover',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
