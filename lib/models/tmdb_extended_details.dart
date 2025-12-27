
import 'tmdb_item.dart';
import 'cast_member.dart';

class TmdbExtendedDetails {
  final List<CastMember> cast;
  final List<TmdbVideo> videos;
  final List<TmdbItem> recommendations;
  final List<TmdbSeason> seasons;

  const TmdbExtendedDetails({
    required this.cast,
    required this.videos,
    required this.recommendations,
    required this.seasons,
    this.reviews = const [],
    this.externalIds = const {},
  });

  final List<TmdbReview> reviews;
  final Map<String, String> externalIds;
}

class TmdbReview {
  final String author;
  final String content;
  final double? rating;
  final String? avatarPath;

  const TmdbReview({
    required this.author,
    required this.content,
    this.rating,
    this.avatarPath,
  });

  factory TmdbReview.fromMap(Map<String, dynamic> map) {
    final details = map['author_details'] as Map<String, dynamic>?;
    var avatar = details?['avatar_path'] as String?;
    if (avatar != null && !avatar.startsWith('http')) {
      avatar = 'https://image.tmdb.org/t/p/w200$avatar';
    }
    
    return TmdbReview(
      author: map['author'] as String? ?? 'Anonymous',
      content: map['content'] as String? ?? '',
      rating: (details?['rating'] as num?)?.toDouble(),
    );
  }
}

class TmdbSeason {
  final int id;
  final String name;
  final int seasonNumber;
  final int episodeCount;
  final String? airDate;
  final String? posterPath;

  const TmdbSeason({
    required this.id,
    required this.name,
    required this.seasonNumber,
    required this.episodeCount,
    this.airDate,
    this.posterPath,
  });

  factory TmdbSeason.fromMap(Map<String, dynamic> map) {
    return TmdbSeason(
      id: map['id'] as int? ?? 0, // Fallback safely
      name: map['name'] as String? ?? '',
      seasonNumber: map['season_number'] as int? ?? 0,
      episodeCount: map['episode_count'] as int? ?? 0,
      airDate: map['air_date'] as String?,
      posterPath: map['poster_path'] as String?,
    );
  }
}



class TmdbVideo {
  final String key;
  final String site;
  final String type;
  final String name;

  const TmdbVideo({
    required this.key,
    required this.site,
    required this.type,
    required this.name,
  });

  factory TmdbVideo.fromMap(Map<String, dynamic> map) {
    return TmdbVideo(
      key: map['key'] as String? ?? '',
      site: map['site'] as String? ?? '',
      type: map['type'] as String? ?? '',
      name: map['name'] as String? ?? '',
    );
  }
}
