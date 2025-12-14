class TmdbEpisode {
  final int id;
  final String name;
  final String overview;
  final String? stillPath;
  final String? airDate;
  final int episodeNumber;
  final int seasonNumber;
  final double voteAverage;

  const TmdbEpisode({
    required this.id,
    required this.name,
    required this.overview,
    this.stillPath,
    this.airDate,
    required this.episodeNumber,
    required this.seasonNumber,
    required this.voteAverage,
  });

  factory TmdbEpisode.fromMap(Map<String, dynamic> map, String imageBase) {
    final still = map['still_path'] as String?;
    return TmdbEpisode(
      id: map['id'] as int,
      name: map['name'] as String? ?? 'Episode ${map['episode_number']}',
      overview: map['overview'] as String? ?? '',
      stillPath: still != null ? '$imageBase$still' : null,
      airDate: map['air_date'] as String?,
      episodeNumber: (map['episode_number'] as num?)?.toInt() ?? 0,
      seasonNumber: (map['season_number'] as num?)?.toInt() ?? 0,
      voteAverage: (map['vote_average'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
