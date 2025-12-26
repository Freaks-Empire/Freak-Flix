import 'dart:convert';
import 'cast_member.dart';

enum MediaType { movie, tv, scene, unknown }

class EpisodeItem {
  final int? season;
  final int? episode;
  final String filePath;

  const EpisodeItem({this.season, this.episode, required this.filePath});

  Map<String, dynamic> toJson() => {
        'season': season,
        'episode': episode,
        'filePath': filePath,
      };

  factory EpisodeItem.fromJson(Map<String, dynamic> json) => EpisodeItem(
        season: json['season'] as int?,
        episode: json['episode'] as int?,
        filePath: json['filePath'] as String,
      );
}

class TvShowGroup {
  final String title;
  final bool isAnime;
  final String? posterUrl;
  final String? backdropUrl;
  final int? year;
  final String showKey;
  final List<MediaItem> episodes;

  const TvShowGroup({
    required this.title,
    required this.isAnime,
    required this.showKey,
    required this.episodes,
    this.posterUrl,
    this.backdropUrl,
    this.year,
  });

  MediaItem get firstEpisode => episodes.first;
  int get episodeCount => episodes.length;
}

MediaType mediaTypeFromString(String? value) {
  switch (value?.toLowerCase()) {
    case 'movie':
      return MediaType.movie;
    case 'tv':
    case 'series':
      return MediaType.tv;
    case 'anime':
      return MediaType.tv;
    case 'scene':
      return MediaType.scene;
    default:
      return MediaType.unknown;
  }
}

String mediaTypeToString(MediaType type) {
  switch (type) {
    case MediaType.movie:
      return 'movie';
    case MediaType.tv:
      return 'tv';
    case MediaType.scene:
      return 'scene';
    case MediaType.unknown:
      return 'unknown';
  }
}

class MediaItem {
  final String id;
  final String filePath;
  final String fileName;
  final String folderPath;
  final int sizeBytes;
  final DateTime lastModified;

  String? title;
  int? year;
  MediaType type;
  int? season;
  int? episode;

  String? posterUrl;
  String? backdropUrl;
  String? overview;
  double? rating;
  int? runtimeMinutes;
  List<String> genres;

  // Optional streaming URL for remote items (e.g., OneDrive).
  String? streamUrl;

  bool isAnime;
  int? tmdbId;
  int? anilistId;
  String? showKey;
  List<EpisodeItem> episodes;

  bool isWatched;
  int lastPositionSeconds;
  int? totalDurationSeconds;
  bool isAdult;
  List<CastMember> cast;

  MediaItem({
    required this.id,
    required this.filePath,
    required this.fileName,
    required this.folderPath,
    required this.sizeBytes,
    required this.lastModified,
    this.title,
    this.year,
    this.type = MediaType.unknown,
    this.season,
    this.episode,
    this.posterUrl,
    this.backdropUrl,
    this.overview,
    this.rating,
    this.runtimeMinutes,
    this.genres = const [],
    this.isAnime = false,
    this.tmdbId,
    this.anilistId,
    this.showKey,
    this.episodes = const [],
    this.isWatched = false,
    this.lastPositionSeconds = 0,
    this.totalDurationSeconds,
    this.streamUrl,
    this.isAdult = false,
    this.cast = const [],
  });

  MediaItem copyWith({
    String? title,
    int? year,
    MediaType? type,
    int? season,
    int? episode,
    String? posterUrl,
    String? backdropUrl,
    String? overview,
    double? rating,
    int? runtimeMinutes,
    List<String>? genres,
    bool? isAnime,
    int? tmdbId,
    int? anilistId,
    String? showKey,
    List<EpisodeItem>? episodes,
    bool? isWatched,
    int? lastPositionSeconds,
    int? totalDurationSeconds,
    bool? isAdult,
    List<CastMember>? cast,
  }) {
    return MediaItem(
      id: id,
      filePath: filePath,
      fileName: fileName,
      folderPath: folderPath,
      sizeBytes: sizeBytes,
      lastModified: lastModified,
      title: title ?? this.title,
      year: year ?? this.year,
      type: type ?? this.type,
      season: season ?? this.season,
      episode: episode ?? this.episode,
      posterUrl: posterUrl ?? this.posterUrl,
      backdropUrl: backdropUrl ?? this.backdropUrl,
      overview: overview ?? this.overview,
      rating: rating ?? this.rating,
      runtimeMinutes: runtimeMinutes ?? this.runtimeMinutes,
      genres: genres ?? this.genres,
      isAnime: isAnime ?? this.isAnime,
      tmdbId: tmdbId ?? this.tmdbId,
      anilistId: anilistId ?? this.anilistId,
      showKey: showKey ?? this.showKey,
      episodes: episodes ?? this.episodes,
      isWatched: isWatched ?? this.isWatched,
      lastPositionSeconds: lastPositionSeconds ?? this.lastPositionSeconds,
      streamUrl: streamUrl ?? this.streamUrl,
      isAdult: isAdult ?? this.isAdult,
      cast: cast ?? this.cast,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'filePath': filePath,
        'fileName': fileName,
        'folderPath': folderPath,
        'sizeBytes': sizeBytes,
        'lastModified': lastModified.toIso8601String(),
        'title': title,
        'year': year,
        'type': mediaTypeToString(type),
        'season': season,
        'episode': episode,
        'posterUrl': posterUrl,
        'backdropUrl': backdropUrl,
        'overview': overview,
        'rating': rating,
        'runtimeMinutes': runtimeMinutes,
        'genres': genres,
        'isAnime': isAnime,
        'tmdbId': tmdbId,
        'showKey': showKey,
        'anilistId': anilistId,
        'episodes': episodes.map((e) => e.toJson()).toList(),
        'isWatched': isWatched,
        'isAdult': isAdult,
        'cast': cast.map((c) => c.toJson()).toList(),
      };

  factory MediaItem.fromJson(Map<String, dynamic> json) {
    return MediaItem(
      id: json['id'] as String,
      filePath: json['filePath'] as String,
      fileName: json['fileName'] as String,
      folderPath: json['folderPath'] as String,
      sizeBytes: json['sizeBytes'] as int,
      lastModified: DateTime.parse(json['lastModified'] as String),
      title: json['title'] as String?,
      year: json['year'] as int?,
      type: mediaTypeFromString(json['type'] as String?),
      season: json['season'] as int?,
      episode: json['episode'] as int?,
      posterUrl: json['posterUrl'] as String?,
      backdropUrl: json['backdropUrl'] as String?,
      overview: json['overview'] as String?,
      rating: (json['rating'] as num?)?.toDouble(),
      runtimeMinutes: json['runtimeMinutes'] as int?,
      genres: (json['genres'] as List<dynamic>?)?.cast<String>() ?? [],
      isAnime: json['isAnime'] as bool? ?? false,
      tmdbId: json['tmdbId'] as int?,

      anilistId: json['anilistId'] as int?,
      showKey: json['showKey'] as String?,
      episodes: (json['episodes'] as List<dynamic>? ?? [])
          .map((e) => EpisodeItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      isWatched: json['isWatched'] as bool? ?? false,
      lastPositionSeconds: json['lastPositionSeconds'] as int? ?? 0,
      totalDurationSeconds: json['totalDurationSeconds'] as int?,
      streamUrl: json['streamUrl'] as String?,
      isAdult: json['isAdult'] as bool? ?? false,
      cast: (json['cast'] as List<dynamic>? ?? [])
          .map((c) => CastMember.fromJson(c as Map<String, dynamic>))
          .toList(),
    );
  }

  static List<MediaItem> listFromJson(String raw) {
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((e) => MediaItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static String listToJson(List<MediaItem> items) =>
      jsonEncode(items.map((e) => e.toJson()).toList());
}
