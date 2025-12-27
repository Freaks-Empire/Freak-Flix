/// lib/models/cast_member.dart
enum CastSource { tmdb, stashDb }

class CastMember {
  final String id;
  final String name;
  final String character;
  final String? profileUrl;
  final CastSource source;

  const CastMember({
    required this.id,
    required this.name,
    required this.character,
    this.profileUrl,
    required this.source,
  });

  factory CastMember.fromJson(Map<String, dynamic> json) {
    return CastMember(
      id: json['id'] as String,
      name: json['name'] as String,
      character: json['character'] as String,
      profileUrl: json['profileUrl'] as String?,
      source: CastSource.values.firstWhere(
        (e) => e.toString() == json['source'],
        orElse: () => CastSource.tmdb,
      ),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'character': character,
        'profileUrl': profileUrl,
        'source': source.toString(),
      };
}
