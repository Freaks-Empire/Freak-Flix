import 'package:flutter/material.dart';

class DiscoverFilter {
  final int? genreId; // TMDB genre id, null = all
  final int? decadeStartYear; // e.g. 1990, null = all
  final int? minRating; // 0-10 TMDB vote_average rounded, null = any
  final bool ignoreWatched;
  final bool ignoreWatchlisted;

  const DiscoverFilter({
    this.genreId,
    this.decadeStartYear,
    this.minRating,
    this.ignoreWatched = false,
    this.ignoreWatchlisted = false,
  });

  DiscoverFilter copyWith({
    int? genreId,
    int? decadeStartYear,
    int? minRating,
    bool? ignoreWatched,
    bool? ignoreWatchlisted,
  }) {
    return DiscoverFilter(
      genreId: genreId ?? this.genreId,
      decadeStartYear: decadeStartYear ?? this.decadeStartYear,
      minRating: minRating ?? this.minRating,
      ignoreWatched: ignoreWatched ?? this.ignoreWatched,
      ignoreWatchlisted: ignoreWatchlisted ?? this.ignoreWatchlisted,
    );
  }

  static const empty = DiscoverFilter();
}

class DiscoverFilterNotifier extends ChangeNotifier {
  DiscoverFilter _filter = DiscoverFilter.empty;
  DiscoverFilter get filter => _filter;

  void update(DiscoverFilter newFilter) {
    _filter = newFilter;
    notifyListeners();
  }

  void reset() {
    _filter = DiscoverFilter.empty;
    notifyListeners();
  }
}
