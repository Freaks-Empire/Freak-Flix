// lib/utils/platform/platform.dart

import 'platform_stub.dart'
    if (dart.library.io) 'platform_io.dart'
    if (dart.library.html) 'platform_web.dart' as current_platform;

// Stub file for conditional imports
export 'platform_stub.dart'
    if (dart.library.io) 'platform_io.dart'
    if (dart.library.html) 'platform_web.dart';

/// Returns true on desktop platforms (Windows, Linux, macOS).
bool get isDesktopPlatform =>
    current_platform.Platform.isWindows ||
    current_platform.Platform.isLinux ||
    current_platform.Platform.isMacOS;

/// Returns a user-facing platform label for unsupported-state messaging.
String get currentPlatformLabel {
  if (current_platform.Platform.isWeb) return 'Web';
  if (current_platform.Platform.isWindows) return 'Windows';
  if (current_platform.Platform.isMacOS) return 'macOS';
  if (current_platform.Platform.isLinux) return 'Linux';
  if (current_platform.Platform.isAndroid) return 'Android';
  if (current_platform.Platform.isIOS) return 'iOS';
  return 'this platform';
}
