/// lib/screens/details_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/media_item.dart';
import '../models/tmdb_item.dart';
import '../models/cast_member.dart'; 
import '../providers/library_provider.dart';
import '../providers/settings_provider.dart';
import '../services/stash_db_service.dart';
import '../models/stash_endpoint.dart';
import '../services/tmdb_service.dart';

import 'details/movie_details_screen.dart';
import 'details/tv_details_screen.dart';
import 'details/scene_details_screen.dart';

class DetailsScreen extends StatefulWidget {
  final String itemId;
  final MediaItem? item;

  const DetailsScreen({super.key, required this.itemId, this.item});

  @override
  State<DetailsScreen> createState() => _DetailsScreenState();
}

class _DetailsScreenState extends State<DetailsScreen> {
  MediaItem? _item;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _resolveItem();
  }

  Future<void> _resolveItem() async {
    if (widget.item != null) {
      if (mounted) setState(() { _item = widget.item; _isLoading = false; });
      return;
    }

    final id = widget.itemId;
    
    // 1. Check Library
    if (!mounted) return;
    final library = context.read<LibraryProvider>();
    try {
      final local = library.items.firstWhere((i) => i.id == id);
      if (mounted) setState(() { _item = local; _isLoading = false; });
      return;
    } catch (_) {
      // Not in library
    }

    // 2. Fetch Remote
    if (id.startsWith('stashdb:')) {
        // StashDB Scene
        final settings = context.read<SettingsProvider>();
        final service = StashDbService();
        final realId = id.replaceFirst('stashdb:', '');
        final scene = await service.getScene(realId, settings.stashEndpoints);
        
        if (mounted) {
           setState(() {
              _item = scene;
              _isLoading = false;
              if (scene == null) _error = "Scene not found";
           });
        }
    } else {
        // TMDB (Movie or TV)
        final service = context.read<TmdbService>();
        
        int? tid;
        bool isMovie = true;
        bool isTv = true;

        if (id.startsWith('movie:')) {
             tid = int.tryParse(id.replaceFirst('movie:', ''));
             isTv = false;
        } else if (id.startsWith('tv:')) {
             tid = int.tryParse(id.replaceFirst('tv:', ''));
             isMovie = false;
        } else if (id.startsWith('tmdb_')) {
             tid = int.tryParse(id.replaceFirst('tmdb_', ''));
        } else {
             tid = int.tryParse(id);
        }
        
        tid ??= 0;

        // Try Movie
        if (isMovie) {
          try {
             final movie = await service.getMovieDetails(tid);
             if (movie != null) {
                 final mItem = MediaItem(
                     id: id,
                     title: movie.title,
                     year: movie.releaseDate != null ? DateTime.tryParse(movie.releaseDate!)?.year : null,
                     type: MediaType.movie,
                     posterUrl: movie.posterPath != null ? 'https://image.tmdb.org/t/p/w500${movie.posterPath}' : null,
                     backdropUrl: movie.backdropPath != null ? 'https://image.tmdb.org/t/p/original${movie.backdropPath}' : null,
                     overview: movie.overview,
                     tmdbId: tid,
                     fileName: movie.title, 
                     filePath: '',
                     folderPath: '',
                     sizeBytes: 0,
                     lastModified: DateTime.now(),
                 );
                 if (mounted) setState(() { _item = mItem; _isLoading = false; });
                 return;
             }
          } catch (_) {}
        }
        
        // Try TV
        if (isTv) {
          try {
             final tv = await service.getTvDetails(tid);
             if (tv != null) {
                 final tItem = MediaItem(
                     id: id,
                     title: tv.originalName, 
                     year: tv.firstAirDate != null ? DateTime.tryParse(tv.firstAirDate!)?.year : null,
                     type: MediaType.tv,
                     posterUrl: tv.posterPath != null ? 'https://image.tmdb.org/t/p/w500${tv.posterPath}' : null,
                     backdropUrl: tv.backdropPath != null ? 'https://image.tmdb.org/t/p/original${tv.backdropPath}' : null,
                     overview: tv.overview,
                     tmdbId: tid,
                     fileName: tv.originalName,
                     filePath: '',
                     folderPath: '',
                     sizeBytes: 0,
                     lastModified: DateTime.now(),
                 );
                  if (mounted) setState(() { _item = tItem; _isLoading = false; });
                  return;
             }
          } catch (_) {}
        }

        if (mounted) setState(() { _isLoading = false; _error = "Item not found"; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
       return const Scaffold(
           backgroundColor: Colors.black,
           body: Center(child: CircularProgressIndicator(color: Colors.redAccent)),
       );
    }

    if (_error != null || _item == null) {
       return Scaffold(
           backgroundColor: Colors.black,
           appBar: AppBar(backgroundColor: Colors.transparent),
           body: Center(child: Text(_error ?? "Item not found", style: const TextStyle(color: Colors.white))),
       );
    }

    final item = _item!;

    if (item.isAdult || item.type == MediaType.scene) {
      return SceneDetailsScreen(item: item);
    }
    if (item.type == MediaType.tv || item.isAnime) {
      return TvDetailsScreen(item: item);
    }
    return MovieDetailsScreen(item: item);
  }
}
