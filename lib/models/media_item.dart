import 'dart:convert';

enum MediaType { movie, tv, anime, unknown }

MediaType mediaTypeFromString(String? value) {
  switch (value?.toLowerCase()) {
    case 'movie':
      return MediaType.movie;
    case 'tv':
    case 'series':
      return MediaType.tv;
    case 'anime':
      return MediaType.anime;
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
    case MediaType.anime:
      return 'anime';
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

  bool isWatched;
  int lastPositionSeconds;
  int? totalDurationSeconds;

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
    this.isWatched = false,
    this.lastPositionSeconds = 0,
    this.totalDurationSeconds,
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
    bool? isWatched,
    int? lastPositionSeconds,
    int? totalDurationSeconds,
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
      isWatched: isWatched ?? this.isWatched,
      lastPositionSeconds: lastPositionSeconds ?? this.lastPositionSeconds,
      totalDurationSeconds: totalDurationSeconds ?? this.totalDurationSeconds,
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
        'isWatched': isWatched,
        'lastPositionSeconds': lastPositionSeconds,
        'totalDurationSeconds': totalDurationSeconds,
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
      isWatched: json['isWatched'] as bool? ?? false,
      lastPositionSeconds: json['lastPositionSeconds'] as int? ?? 0,
      totalDurationSeconds: json['totalDurationSeconds'] as int?,
    );
  }

  static List<MediaItem> listFromJson(String raw) {
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded.map((e) => MediaItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  static String listToJson(List<MediaItem> items) => jsonEncode(items.map((e) => e.toJson()).toList());
}