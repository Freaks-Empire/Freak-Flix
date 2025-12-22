import 'dart:io' as io;

class Platform {
  static bool get isWindows => io.Platform.isWindows;
  static bool get isLinux => io.Platform.isLinux;
  static bool get isMacOS => io.Platform.isMacOS;
  static bool get isAndroid => io.Platform.isAndroid;
  static bool get isIOS => io.Platform.isIOS;
  static bool get isWeb => false;
  static String get pathSeparator => io.Platform.pathSeparator;
}

class PlatformStat {
  final int size;
  final DateTime modified;
  PlatformStat(this.size, this.modified);
}

abstract class PlatformFileSystemEntity {
  String get path;
  PlatformStat statSync();
}

class PlatformFile implements PlatformFileSystemEntity {
  final io.File _file;
  PlatformFile(String path) : _file = io.File(path);

  @override
  String get path => _file.path;

  @override
  PlatformStat statSync() {
    final s = _file.statSync();
    return PlatformStat(s.size, s.modified);
  }
}

class PlatformDirectory implements PlatformFileSystemEntity {
  final io.Directory _dir;
  PlatformDirectory(String path) : _dir = io.Directory(path);

  @override
  String get path => _dir.path;

  @override
  PlatformStat statSync() {
    final s = _dir.statSync();
    return PlatformStat(s.size, s.modified);
  }

  bool existsSync() => _dir.existsSync();

  List<PlatformFileSystemEntity> listSync({bool recursive = false, bool followLinks = true}) {
    return _dir.listSync(recursive: recursive, followLinks: followLinks).map((e) {
      if (e is io.File) return PlatformFile(e.path);
      if (e is io.Directory) return PlatformDirectory(e.path);
      return null;
    }).whereType<PlatformFileSystemEntity>().toList();
  }
}
