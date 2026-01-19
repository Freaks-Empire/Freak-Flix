import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/tmdb_item.dart';
import '../models/media_item.dart';
import '../services/tmdb_service.dart';
import '../services/stash_db_service.dart';
import '../providers/settings_provider.dart';
import '../widgets/search_widgets.dart';
import '../widgets/settings_widgets.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({Key? key}) : super(key: key);

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  List<TmdbItem> _results = [];
  bool _isSearching = false;
  bool _loading = false;
  Timer? _debounce;
  List<String> _recentSearches = [];

  // Cached Data
  List<TmdbItem> _trendingMovies = [];
  List<TmdbItem> _trendingTv = [];
  List<TmdbItem> _anime = [];
  List<MediaItem> _stashUpdates = [];
  
  bool _loadingTrending = true;
  String? _trendingError;

  static const Map<String, String> _folding = {
    'á': 'a', 'à': 'a', 'â': 'a', 'ä': 'a', 'ã': 'a', 'å': 'a',
    'ç': 'c', 'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
    'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i', 'ñ': 'n',
    'ó': 'o', 'ò': 'o', 'ô': 'o', 'ö': 'o', 'õ': 'o',
    'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u', 'ý': 'y', 'ÿ': 'y',
    'Á': 'a', 'À': 'a', 'Â': 'a', 'Ä': 'a', 'Ã': 'a', 'Å': 'a',
    'Ç': 'c', 'É': 'e', 'È': 'e', 'Ê': 'e', 'Ë': 'e',
    'Í': 'i', 'Ì': 'i', 'Î': 'i', 'Ï': 'i', 'Ñ': 'n',
    'Ó': 'o', 'Ò': 'o', 'Ô': 'o', 'Ö': 'o', 'Õ': 'o',
    'Ú': 'u', 'Ù': 'u', 'Û': 'u', 'Ü': 'u', 'Ý': 'y',
  };

  @override
  void initState() {
    super.initState();
    _loadRecents();
    _loadTrendingData();
  }

  @override
  void dispose() {
    _controller.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadTrendingData() async {
    setState(() {
      _loadingTrending = true;
      _trendingError = null;
    });

    try {
      final tmdb = context.read<TmdbService>();
      final settings = context.read<SettingsProvider>();

      // Fetch all data in parallel
      final results = await Future.wait([
        tmdb.getTrendingMovies(),
        tmdb.getTrendingTv(),
        tmdb.getAnime(),
        if (settings.enableAdultContent && settings.stashEndpoints.isNotEmpty)
          context.read<StashDbService>().getRecentScenes(settings.stashEndpoints)
        else
          Future.value(<MediaItem>[]),
      ]);

      if (mounted) {
        setState(() {
          _trendingMovies = results[0] as List<TmdbItem>;
          _trendingTv = results[1] as List<TmdbItem>;
          _anime = results[2] as List<TmdbItem>;
          _stashUpdates = results[3] as List<MediaItem>;
          _loadingTrending = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _trendingError = e.toString();
          _loadingTrending = false;
        });
      }
    }
  }

  Future<void> _loadRecents() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _recentSearches = prefs.getStringList('recent_searches') ?? [];
    });
  }

  Future<void> _addRecent(String query) async {
    if (query.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('recent_searches') ?? [];
    list.remove(query);
    list.insert(0, query);
    if (list.length > 10) list.removeLast();
    await prefs.setStringList('recent_searches', list);
    setState(() => _recentSearches = list);
  }

  Future<void> _removeRecent(String query) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('recent_searches') ?? [];
    list.remove(query);
    await prefs.setStringList('recent_searches', list);
    setState(() => _recentSearches = list);
  }

  Future<void> _clearRecents() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('recent_searches');
    setState(() => _recentSearches = []);
  }

  void _onSearchChanged(String query) {
    if (query.isEmpty) {
      if (_debounce?.isActive ?? false) _debounce!.cancel();
      setState(() {
        _isSearching = false;
        _results = [];
      });
      return;
    }

    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) return;

    setState(() {
      _isSearching = true;
      _loading = true;
    });

    try {
      final service = context.read<TmdbService>();
      final results = await service.searchMulti(query);
      final filtered = _filterResults(results, query);
      if (mounted) {
        setState(() {
          _results = filtered;
          _loading = false;
        });
        _addRecent(query);
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<TmdbItem> _filterResults(List<TmdbItem> items, String query) {
    final q = _normalizeText(query);
    if (q.isEmpty) return items;
    final tokens = q.split(' ').where((token) => token.isNotEmpty).toList(growable: false);
    if (tokens.isEmpty) return items;

    bool matches(TmdbItem item) {
      final title = _normalizeText(item.title);
      final overview = _normalizeText(item.overview ?? '');
      final haystack = '$title $overview';
      return tokens.every((t) => haystack.contains(t));
    }

    return items.where(matches).toList(growable: false);
  }

  String _normalizeText(String input) {
    final lower = input.toLowerCase();
    final folded = lower.split('').map((ch) => _folding[ch] ?? ch).join();
    final cleaned = folded.replaceAll(RegExp(r'[^a-z0-9]+'), ' ');
    return cleaned.trim().replaceAll(RegExp(r' +'), ' ');
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            const SliverToBoxAdapter(child: SizedBox(height: 80)),

            // SEARCH HEADER
            SliverPersistentHeader(
              pinned: true,
              floating: true,
              delegate: SearchHeaderDelegate(
                controller: _controller,
                onChanged: _onSearchChanged,
                onClear: () {
                  _controller.clear();
                  setState(() => _isSearching = false);
                  FocusScope.of(context).unfocus();
                },
              ),
            ),

            // LOADING INDICATOR
            if (_loading)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.only(top: 100),
                  child: Center(child: CircularProgressIndicator(color: AppColors.accent)),
                ),
              )
            else if (!_isSearching) ...[
              const SliverToBoxAdapter(child: SizedBox(height: 20)),

              // RECENT SEARCHES
              if (_recentSearches.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: SectionHeader(
                    title: "Recent Searches",
                    action: "Clear All",
                    onAction: _clearRecents,
                  ),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, index) => RecentSearchTile(
                      text: _recentSearches[index],
                      onTap: () {
                        _controller.text = _recentSearches[index];
                        _performSearch(_recentSearches[index]);
                      },
                      onDelete: () => _removeRecent(_recentSearches[index]),
                    ),
                    childCount: _recentSearches.length,
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 32)),
              ],

              const SliverToBoxAdapter(child: SectionHeader(title: "Browse by Genre")),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
              SliverToBoxAdapter(
                child: GenreCloud(
                  onGenreSelected: (genre) {
                    _controller.text = genre;
                    _performSearch(genre);
                  },
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),

              // ERROR STATE
              if (_trendingError != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 48),
                        const SizedBox(height: 8),
                        Text('Failed to load trending content', style: TextStyle(color: AppColors.textSub)),
                        const SizedBox(height: 8),
                        FilledButton(onPressed: _loadTrendingData, child: const Text('Retry')),
                      ],
                    ),
                  ),
                )
              // LOADING STATE
              else if (_loadingTrending)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 60),
                    child: Center(child: CircularProgressIndicator(color: AppColors.accent)),
                  ),
                )
              // CONTENT
              else ...[
                // TRENDING MOVIES
                if (_trendingMovies.isNotEmpty) ...[
                  const SliverToBoxAdapter(child: SectionHeader(title: "Trending Movies")),
                  const SliverToBoxAdapter(child: SizedBox(height: 12)),
                  SliverToBoxAdapter(child: CachedContentRow(items: _trendingMovies)),
                  const SliverToBoxAdapter(child: SizedBox(height: 32)),
                ],

                // TRENDING TV
                if (_trendingTv.isNotEmpty) ...[
                  const SliverToBoxAdapter(child: SectionHeader(title: "Trending TV Shows")),
                  const SliverToBoxAdapter(child: SizedBox(height: 12)),
                  SliverToBoxAdapter(child: CachedContentRow(items: _trendingTv)),
                  const SliverToBoxAdapter(child: SizedBox(height: 32)),
                ],

                // ANIME
                if (_anime.isNotEmpty) ...[
                  const SliverToBoxAdapter(child: SectionHeader(title: "Popular Anime")),
                  const SliverToBoxAdapter(child: SizedBox(height: 12)),
                  SliverToBoxAdapter(child: CachedContentRow(items: _anime)),
                  const SliverToBoxAdapter(child: SizedBox(height: 32)),
                ],

                // STASH UPDATES (Adult)
                if (settings.enableAdultContent && _stashUpdates.isNotEmpty) ...[
                  const SliverToBoxAdapter(child: SectionHeader(title: "Stash Updates", action: "Manage")),
                  const SliverToBoxAdapter(child: SizedBox(height: 12)),
                  SliverToBoxAdapter(child: CachedContentRow(items: _stashUpdates, isPortrait: false)),
                  const SliverToBoxAdapter(child: SizedBox(height: 32)),
                ],
              ],

              const SliverToBoxAdapter(child: SizedBox(height: 40)),
            ] else ...[
              // SEARCH RESULTS
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SearchResultsGrid(results: _results),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
