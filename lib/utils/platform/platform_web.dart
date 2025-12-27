/// lib/utils/platform/platform_web.dart

class Platform {
  static const bool isWindows = false;
  static const bool isLinux = false;
  static const bool isMacOS = false;
  static const bool isAndroid = false;
  static const bool isIOS = false;
  static const bool isWeb = true;
  static const String pathSeparator = '/';
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
  final String _path;
  PlatformFile(this._path);

  @override
  String get path => _path;

  @override
  PlatformStat statSync() {
    return PlatformStat(0, DateTime.now());
  }
}

class PlatformDirectory implements PlatformFileSystemEntity {
  final String _path;
  PlatformDirectory(this._path);

  @override
  String get path => _path;

  @override
  PlatformStat statSync() {
    return PlatformStat(0, DateTime.now());
  }

  bool existsSync() => false;

  List<PlatformFileSystemEntity> listSync({bool recursive = false, bool followLinks = true}) {
    return [];
  }
}
