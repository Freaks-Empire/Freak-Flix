import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/tmdb_item.dart';
import '../services/tmdb_service.dart';
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
      if (mounted) {
        setState(() {
          _results = results;
          _loading = false;
        });
        _addRecent(query);
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
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
                   child: Center(child: CircularProgressIndicator(color: AppColors.accent)),
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

              const SliverToBoxAdapter(child: SectionHeader(title: "Browse by Genre")),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                sliver: SliverToBoxAdapter(
                    child: GenreCloud(
                        onGenreSelected: (genre) {
                            _controller.text = genre;
                            _performSearch(genre);
                        },
                    )
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
              
              // TRENDING
              const SliverToBoxAdapter(child: SectionHeader(title: "Trending Today")),
              const SliverToBoxAdapter(child: SizedBox(height: 12)),
              const SliverToBoxAdapter(child: TrendingHorizontalList()),
              const SliverToBoxAdapter(child: SizedBox(height: 40)), // Bottom padding

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
