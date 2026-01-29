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

String libraryTypeDisplayName(LibraryType type) {
  switch (type) {
    case LibraryType.movies:
      return 'Movies';
    case LibraryType.tv:
      return 'TV Shows';
    case LibraryType.anime:
      return 'Anime';
    case LibraryType.adult:
      return 'Adult';
    case LibraryType.other:
      return 'Other';
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
  final String? name; // User-friendly name for the library

  const LibraryFolder({
    required this.id,
    required this.path,
    required this.accountId,
    required this.type,
    this.name,
  });

  /// Returns a display name for the library
  /// Priority: name > last path segment > type name
  String get displayName {
    if (name != null && name!.isNotEmpty) return name!;
    
    // Extract meaningful name from path
    if (path.isNotEmpty && path != '/') {
      final segments = path.split('/').where((s) => s.isNotEmpty).toList();
      if (segments.isNotEmpty) return segments.last;
    }
    
    // Fallback to type name
    return libraryTypeDisplayName(type);
  }

  /// Returns whether this is a cloud library
  bool get isCloud => accountId.isNotEmpty;

  /// Returns a source description based on path prefix or accountId
  String get sourceLabel {
    // Check for remote storage protocols in path
    if (path.startsWith('sftp:')) return 'SFTP';
    if (path.startsWith('ftp:')) return 'FTP';
    if (path.startsWith('webdav:')) return 'WebDAV';
    // OneDrive folders have accountId but no protocol prefix
    if (isCloud) return 'OneDrive';
    return 'Local';
  }

  LibraryFolder copyWith({
    String? id,
    String? path,
    String? accountId,
    LibraryType? type,
    String? name,
  }) {
    return LibraryFolder(
      id: id ?? this.id,
      path: path ?? this.path,
      accountId: accountId ?? this.accountId,
      type: type ?? this.type,
      name: name ?? this.name,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'path': path,
        'accountId': accountId,
        'type': libraryTypeToString(type),
        'name': name,
      };

  factory LibraryFolder.fromJson(Map<String, dynamic> json) => LibraryFolder(
        id: json['id'] as String,
        path: json['path'] as String,
        accountId: json['accountId'] as String,
        type: libraryTypeFromString(json['type'] as String?),
        name: json['name'] as String?,
      );
}
