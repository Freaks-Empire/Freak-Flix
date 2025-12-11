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
}
