/// lib/models/tmdb_person.dart
import 'tmdb_item.dart';

class TmdbPerson {
  final int id;
  final String name;
  final String? biography;
  final String? birthday;
  final String? placeOfBirth;
  final String? profilePath;
  final String? deathDay;
  final List<TmdbItem> knownFor;
  final Map<String, String> externalIds;

  const TmdbPerson({
    required this.id,
    required this.name,
    this.biography,
    this.birthday,
    this.deathDay,
    this.placeOfBirth,
    this.profilePath,
    required this.knownFor,
    this.externalIds = const {},
  });

  factory TmdbPerson.fromMap(Map<String, dynamic> map, String imageBase) {
    final combinedCredits = map['combined_credits'] as Map<String, dynamic>?;
    final castList = (combinedCredits?['cast'] as List<dynamic>? ?? [])
        .map((m) {
           // Skip items without posters or title
           if (m['poster_path'] == null) return null;
           return TmdbItem.fromMap(
             m, 
             imageBase: imageBase,
             defaultType: m['media_type'] == 'tv' ? TmdbMediaType.tv : TmdbMediaType.movie,
           );
         })
        .whereType<TmdbItem>()
        .take(50) // Increased limit to allow filtering into Movies/TV later
        .toList();

    // Parse External IDs
    final externals = map['external_ids'] as Map<String, dynamic>? ?? {};
    final exIds = <String, String>{};
    if (externals['imdb_id'] != null) exIds['imdb'] = externals['imdb_id'].toString();
    if (externals['facebook_id'] != null) exIds['facebook'] = externals['facebook_id'].toString();
    if (externals['instagram_id'] != null) exIds['instagram'] = externals['instagram_id'].toString();
    if (externals['twitter_id'] != null) exIds['twitter'] = externals['twitter_id'].toString();
    if (externals['tiktok_id'] != null) exIds['tiktok'] = externals['tiktok_id'].toString();

    return TmdbPerson(
      id: map['id'] as int,
      name: map['name'] as String? ?? 'Unknown',
      biography: map['biography'] as String?,
      birthday: map['birthday'] as String?,
      deathDay: map['deathday'] as String?,
      placeOfBirth: map['place_of_birth'] as String?,
      profilePath: map['profile_path'] != null ? '$imageBase${map['profile_path']}' : null,
      knownFor: castList,
      externalIds: exIds,
    );
  }
}
