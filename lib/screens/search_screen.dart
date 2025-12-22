import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/tmdb_item.dart';
import '../models/media_item.dart';
import '../services/tmdb_service.dart';
import '../providers/library_provider.dart';
import '../widgets/discover_card.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  List<TmdbItem> _results = [];
  bool _loading = false;
  Timer? _debounce;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // Auto-focus the search bar when entering the screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _debounce?.cancel();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) {
      if (mounted) setState(() => _results = []);
      return;
    }

    setState(() => _loading = true);
    try {
      final library = context.read<LibraryProvider>();
      final tmdb = context.read<TmdbService>();

      // Parallel execution
      final results = await Future.wait([
        Future.sync(() => library.search(query)),
        tmdb.searchMulti(query),
      ]);

      final localItems = results[0] as List<MediaItem>;
      final tmdbItems = results[1] as List<TmdbItem>;

      // Convert local items to display format
      final localTmdbItems = localItems
          .map((m) => TmdbItem.fromMediaItem(m))
          .toList();

      // Deduplicate: If a TMDB item is already covered by a local item (same TMDB ID), use the local one.
      // (Actually, we just show the local one and filter it out from TMDB list if needed)
      final localIds = localTmdbItems.map((i) => i.id).toSet();
      
      final filteredTmdbItems = tmdbItems.where((i) {
        // Keep if not in local set. 
        // Note: Local items from Stash might calculate a fake ID or usually have a hash code as ID if no TMDB ID.
        // If local item HAS a valid TMDB ID, we want to hide the generic TMDB result to avoid duplicates.
        return !localIds.contains(i.id);
      }).toList();

      if (mounted) {
        setState(() {
          _results = [...localTmdbItems, ...filteredTmdbItems];
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Search error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: Colors.black, // Consistent dark theme
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 100, left: 24, right: 24, bottom: 24),
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                style: const TextStyle(color: Colors.white, fontSize: 18),
                decoration: InputDecoration(
                  hintText: 'Search movies & TV shows...',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                  prefixIcon: const Icon(Icons.search, color: Colors.white70),
                  suffixIcon: _loading
                      ? const Padding(
                          padding: EdgeInsets.all(12.0),
                          child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2)),
                        )
                      : (_controller.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, color: Colors.white70),
                              onPressed: () {
                                _controller.clear();
                                _performSearch('');
                              },
                            )
                          : null),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.1),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                ),
                onChanged: _onSearchChanged,
                onSubmitted: _performSearch,
              ),
            ),
            
            Expanded(
              child: _results.isEmpty && _controller.text.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search, size: 64, color: Colors.white.withOpacity(0.1)),
                          const SizedBox(height: 16),
                          Text(
                            'Find your next favorite',
                            style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 16),
                          ),
                        ],
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 200,
                        childAspectRatio: 0.55,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                      ),
                      itemCount: _results.length,
                      itemBuilder: (ctx, i) => DiscoverCard(item: _results[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
