import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/tmdb_item.dart';
import '../services/tmdb_service.dart';
import '../services/stash_db_service.dart';
import '../providers/settings_provider.dart';
import '../widgets/search_widgets.dart'; // New widgets
import '../widgets/settings_widgets.dart'; // Reuse AppColors

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

  // Lightweight diacritic folding for common Latin characters so searches stay ASCII-only.
  static const Map<String, String> _folding = {
    'á': 'a',
    'à': 'a',
    'â': 'a',
    'ä': 'a',
    'ã': 'a',
    'å': 'a',
    'ç': 'c',
    'é': 'e',
    'è': 'e',
    'ê': 'e',
    'ë': 'e',
    'í': 'i',
    'ì': 'i',
    'î': 'i',
    'ï': 'i',
    'ñ': 'n',
    'ó': 'o',
    'ò': 'o',
    'ô': 'o',
    'ö': 'o',
    'õ': 'o',
    'ú': 'u',
    'ù': 'u',
    'û': 'u',
    'ü': 'u',
    'ý': 'y',
    'ÿ': 'y',
    'Á': 'a',
    'À': 'a',
    'Â': 'a',
    'Ä': 'a',
    'Ã': 'a',
    'Å': 'a',
    'Ç': 'c',
    'É': 'e',
    'È': 'e',
    'Ê': 'e',
    'Ë': 'e',
    'Í': 'i',
    'Ì': 'i',
    'Î': 'i',
    'Ï': 'i',
    'Ñ': 'n',
    'Ó': 'o',
    'Ò': 'o',
    'Ô': 'o',
    'Ö': 'o',
    'Õ': 'o',
    'Ú': 'u',
    'Ù': 'u',
    'Û': 'u',
    'Ü': 'u',
    'Ý': 'y',
  };

  @override
  void initState() {
    super.initState();
    _loadRecents();
  }

  @override
  void dispose() {
    _controller.dispose();
    _debounce?.cancel();
    super.dispose();
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
    final tokens =
        q.split(' ').where((token) => token.isNotEmpty).toList(growable: false);
    if (tokens.isEmpty) return items;

    bool matches(TmdbItem item) {
      final title = _normalizeText(item.title);
      final overview = _normalizeText(item.overview ?? '');
      final haystack = '$title $overview';
      // Require every token to appear somewhere in the title or overview.
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
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // 1. SPACER (Fix for Nav Dock overlap)
            const SliverToBoxAdapter(child: SizedBox(height: 80)),

            // 2. STICKY SEARCH HEADER
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
                  child: Center(
                      child:
                          CircularProgressIndicator(color: AppColors.accent)),
                ),
              )

            // 2. CONTENT SWITCHER
            else if (!_isSearching) ...[
              // ZERO STATE (Discovery)
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

              const SliverToBoxAdapter(
                  child: SectionHeader(title: "Browse by Genre")),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
              
              SliverToBoxAdapter(
                child: GenreCloud(
                  onGenreSelected: (genre) {
                    _controller.text = genre;
                    _performSearch(genre);
                  },
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),

              // TRENDING MOVIES
              const SliverToBoxAdapter(
                  child: SectionHeader(title: "Trending Movies")),
              const SliverToBoxAdapter(child: SizedBox(height: 12)),
              SliverToBoxAdapter(
                child: Consumer<TmdbService>(
                  builder: (context, tmdb, _) => ContentRow(future: tmdb.getTrendingMovies()),
                )
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 32)),

              // TRENDING TV SHOWS
              const SliverToBoxAdapter(
                  child: SectionHeader(title: "Trending TV Shows")),
              const SliverToBoxAdapter(child: SizedBox(height: 12)),
               SliverToBoxAdapter(
                child: Consumer<TmdbService>(
                  builder: (context, tmdb, _) => ContentRow(future: tmdb.getTrendingTv()),
                )
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 32)),

              // ANIME
              const SliverToBoxAdapter(
                  child: SectionHeader(title: "Popular Anime")),
              const SliverToBoxAdapter(child: SizedBox(height: 12)),
               SliverToBoxAdapter(
                child: Consumer<TmdbService>(
                  builder: (context, tmdb, _) => ContentRow(future: tmdb.getAnime()),
                )
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 32)),

              // ADULT TRENDING (Stash Updates)
              Consumer<SettingsProvider>(
                builder: (context, settings, _) {
                  if (!settings.enableAdultContent) return const SliverToBoxAdapter();
                  
                  return SliverMainAxisGroup(
                    slivers: [
                      const SliverToBoxAdapter(
                          child: SectionHeader(title: "Stash Updates", action: "Manage",)), 
                      const SliverToBoxAdapter(child: SizedBox(height: 12)),
                      SliverToBoxAdapter(
                        child: Consumer<StashDbService>(
                          builder: (context, stash, _) => ContentRow(
                            future: stash.getRecentScenes(settings.stashEndpoints),
                            isPortrait: false, // Scenes are usually landscape
                          ),
                        )
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 32)),
                    ],
                  );
                },
              ),

              const SliverToBoxAdapter(
                  child: SizedBox(height: 40)), // Bottom padding
            ] else ...[
              // ACTIVE SEARCH RESULTS GRID
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
