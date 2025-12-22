enum TmdbMediaType { movie, tv }

class TmdbItem {
  final int id;
  final String title;
  final String? posterUrl;
  final TmdbMediaType type;
  final int? releaseYear;
  final double? voteAverage;
  final int? voteCount;
  final double? popularity;
  final String? overview;

  const TmdbItem({
    required this.id,
    required this.title,
    required this.type,
    this.posterUrl,
    this.releaseYear,
    this.voteAverage,
    this.voteCount,
    this.popularity,
    this.overview,
  });

  static TmdbItem fromMap(
    Map<String, dynamic> map, {
    required String imageBase,
    required TmdbMediaType defaultType,
  }) {
    final mediaTypeStr = (map['media_type'] as String?) ??
        (defaultType == TmdbMediaType.tv ? 'tv' : 'movie');
    final mediaType = mediaTypeStr == 'tv' ? TmdbMediaType.tv : TmdbMediaType.movie;

    final title = (mediaType == TmdbMediaType.tv
            ? map['name'] as String?
            : map['title'] as String?) ??
        '';

    final posterPath = map['poster_path'] as String?;
    final dateStr = (mediaType == TmdbMediaType.tv
            ? map['first_air_date']
            : map['release_date'])
        as String?;
    final year = dateStr != null && dateStr.length >= 4
        ? int.tryParse(dateStr.substring(0, 4))
        : null;

    return TmdbItem(
      id: (map['id'] as num).toInt(),
      title: title,
      type: mediaType,
      posterUrl: posterPath != null ? '$imageBase$posterPath' : null,
      releaseYear: year,
      voteAverage: (map['vote_average'] as num?)?.toDouble(),
      voteCount: (map['vote_count'] as num?)?.toInt(),
      popularity: (map['popularity'] as num?)?.toDouble(),
      overview: map['overview'] as String?,
    );
  }
  static TmdbItem fromMediaItem(dynamic item) {
    // Note: 'item' is strictly MediaItem but avoiding circular imports if possible, 
    // or we just import it. Let's import it.
    // Actually, to avoid modifying imports blindly, I'll assume I can import.
    // Wait, I can't import if I don't see imports. 
    // I need to add import first.
    // But let's just use dynamic for now or strict typing if I add import.
    // Let's add the import line at the top first if needed? 
    // No, let's just add the method and I'll fix imports next.
    // Actually, sticking to the plan:
    
    return TmdbItem(
      id: item.tmdbId ?? item.hashCode, 
      title: item.title ?? item.fileName,
      type: item.type.toString().contains('movie') ? TmdbMediaType.movie : TmdbMediaType.tv,
      posterUrl: item.posterUrl,
      releaseYear: item.year,
      voteAverage: item.rating,
      overview: item.overview,
    );
  }
}
