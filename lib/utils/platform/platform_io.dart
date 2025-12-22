import 'dart:io';

bool get isDesktop => Platform.isWindows || Platform.isLinux || Platform.isMacOS;
bool get isMobile => Platform.isAndroid || Platform.isIOS;
bool get isWeb => false;

String get pathSeparator => Platform.pathSeparator;

/// Safely check if a directory exists
bool dirExists(String path) => Directory(path).existsSync();

/// Safely list files in a directory
List<String> listFiles(String path) {
  try {
    return Directory(path)
        .listSync()
        .whereType<File>()
        .map((f) => f.path)
        .toList();
  } catch (e) {
    return [];
  }
}
