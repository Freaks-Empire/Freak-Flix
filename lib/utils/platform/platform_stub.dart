/// lib/utils/platform/platform_stub.dart

abstract class Platform {
  static const bool isWindows = false;
  static const bool isLinux = false;
  static const bool isMacOS = false;
  static const bool isAndroid = false;
  static const bool isIOS = false;
  static const bool isWeb = false;
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

abstract class PlatformFile implements PlatformFileSystemEntity {
  factory PlatformFile(String path) => throw UnimplementedError();
}

abstract class PlatformDirectory implements PlatformFileSystemEntity {
  factory PlatformDirectory(String path) => throw UnimplementedError();
  bool existsSync();
  List<PlatformFileSystemEntity> listSync({bool recursive = false, bool followLinks = true});
}
