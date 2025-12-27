/// lib/screens/details_screen.dart
import 'package:flutter/material.dart';

import '../models/media_item.dart';
import '../models/tmdb_item.dart';
import 'details/movie_details_screen.dart';
import 'details/tv_details_screen.dart';
import 'details/scene_details_screen.dart';

class DetailsScreen extends StatelessWidget {
  final MediaItem item;
  const DetailsScreen({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    if (item.isAdult || item.type == MediaType.scene) {
      return SceneDetailsScreen(item: item);
    }
    if (item.type == MediaType.tv || item.isAnime) {
      return TvDetailsScreen(item: item);
    }
    return MovieDetailsScreen(item: item);
  }
}
