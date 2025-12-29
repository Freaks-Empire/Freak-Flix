/// lib/models/stash_performer.dart
class StashPerformer {
  final String id;
  final String name;
  final String? birthdate;
  final int? heightCm;
  final String? measurements;
  final String? breastType;
  final String? country;
  final String? ethnicity;
  final String? eyeColor;
  final String? hairColor;
  final String? careerStartYear; // Often int, but keep flexible
  final String? careerEndYear;
  final List<String> tattoos;
  final List<String> piercings;
  final List<String> aliases;
  final Map<String, String> urls;
  final String? imageUrl;

  const StashPerformer({
    required this.id,
    required this.name,
    this.birthdate,
    this.heightCm,
    this.measurements,
    this.breastType,
    this.country,
    this.ethnicity,
    this.eyeColor,
    this.hairColor,
    this.careerStartYear,
    this.careerEndYear,
    this.tattoos = const [],
    this.piercings = const [],
    this.aliases = const [],
    this.urls = const {},
    this.imageUrl,
  });

  factory StashPerformer.fromJson(Map<String, dynamic> json) {
    List<String> parseList(dynamic val) {
       if (val is List) return val.map((e) => e.toString()).toList();
       return [];
    }

    // Tattoos/Piercings in StashDB might be objects {location, description}
    // We'll simplisticly map them if they are complex, or Strings.
    // StashDB Public API usually returns lists of type BodyModification { location, description }
    List<String> parseMods(dynamic list) {
        if (list is List) {
           return list.map((item) {
              if (item is Map) {
                 final loc = item['location'] ?? '';
                 final desc = item['description']; // can be null
                 return desc != null && desc.isNotEmpty ? '$loc ($desc)' : loc; 
              }
              return item.toString();
           }).cast<String>().toList();
        }
        return [];
    }

    // Helper to extract social URLs
    final urlList = json['urls'] as List<dynamic>? ?? [];
    final urlMap = <String, String>{};
    for (final u in urlList) {
        // StashDB URL object usually { url: "...", type: "..." }
        if (u is Map) {
           final type = (u['type'] as String?)?.toLowerCase() ?? 'link';
           final link = u['url'] as String?;
           if (link != null) urlMap[type] = link;
        } else if (u is String) {
           // Fallback
           urlMap['link'] = u;
        }
    }
    // Also check direct fields if flat
    if (json['twitter'] != null) urlMap['twitter'] = json['twitter'];
    if (json['instagram'] != null) urlMap['instagram'] = json['instagram'];

    // Career
    final active = json['career_start_year']?.toString();
    final retired = json['career_end_year']?.toString();

    // Image
    String? img;
    if (json['images'] != null && (json['images'] as List).isNotEmpty) {
       img = json['images'][0]['url'];
    }

    return StashPerformer(
      id: json['id'] as String,
      name: json['name'] as String,
      birthdate: json['birthdate'] as String?,
      heightCm: json['height_cm'] as int?,
      measurements: json['measurements'] as String?,
      breastType: json['fake_tits'] as String?, // Map appropriately if Enum ('NATURAL', 'FAKE')
      country: json['country'] as String?,
      ethnicity: json['ethnicity'] as String?,
      eyeColor: json['eye_color'] as String?,
      hairColor: json['hair_color'] as String?,
      careerStartYear: active,
      careerEndYear: retired,
      tattoos: parseMods(json['tattoos']),
      piercings: parseMods(json['piercings']),
      aliases: parseList(json['aliases']),
      urls: urlMap,
      imageUrl: img,
    );
  }
}
