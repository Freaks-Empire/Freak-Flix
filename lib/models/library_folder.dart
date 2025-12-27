/// lib/models/library_folder.dart
enum LibraryType { movies, tv, anime, adult, other }

String libraryTypeToString(LibraryType type) {
  switch (type) {
    case LibraryType.movies:
      return 'movies';
    case LibraryType.tv:
      return 'tv';
    case LibraryType.anime:
      return 'anime';
    case LibraryType.adult:
      return 'adult';
    case LibraryType.other:
      return 'other';
  }
}

LibraryType libraryTypeFromString(String? value) {
  switch (value) {
    case 'movies':
      return LibraryType.movies;
    case 'tv':
      return LibraryType.tv;
    case 'anime':
      return LibraryType.anime;
    case 'adult':
      return LibraryType.adult;
    case 'other':
      return LibraryType.other;
    default:
      return LibraryType.other;
  }
}

class LibraryFolder {
  final String id;
  final String path;
  final String accountId;
  final LibraryType type;

  const LibraryFolder({
    required this.id,
    required this.path,
    required this.accountId,
    required this.type,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'path': path,
        'accountId': accountId,
        'type': libraryTypeToString(type),
      };

  factory LibraryFolder.fromJson(Map<String, dynamic> json) => LibraryFolder(
        id: json['id'] as String,
        path: json['path'] as String,
        accountId: json['accountId'] as String,
        type: libraryTypeFromString(json['type'] as String?),
      );
}
