/// lib/models/tmdb_person.dart
import 'tmdb_item.dart';

class TmdbPerson {
  final int id;
  final String name;
  final String? biography;
  final String? birthday;
  final String? placeOfBirth;
  final String? profilePath;
  final List<TmdbItem> knownFor;

  const TmdbPerson({
    required this.id,
    required this.name,
    this.biography,
    this.birthday,
    this.placeOfBirth,
    this.profilePath,
    required this.knownFor,
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
        .take(20) // Limit to top 20
        .toList();

    // Sort by popularity or date? TMDB 'cast' is usually arbitrary order or by id. 
    // Let's sort by popularity if available, or vote_count.
    // For now, accept TMDB return order which is often popularity.

    return TmdbPerson(
      id: map['id'] as int,
      name: map['name'] as String? ?? 'Unknown',
      biography: map['biography'] as String?,
      birthday: map['birthday'] as String?,
      placeOfBirth: map['place_of_birth'] as String?,
      profilePath: map['profile_path'] != null ? '$imageBase${map['profile_path']}' : null,
      knownFor: castList,
    );
  }
}
