/// test/platform/platform_guard_test.dart
///
/// Regression coverage for platform guard decisions and unsupported-path
/// messaging used by startup, scan orchestration, and settings flows.

import 'package:flutter_test/flutter_test.dart';

import 'package:freak_flix/main.dart';
import 'package:freak_flix/services/scan_orchestration_service.dart';
import 'package:freak_flix/widgets/settings/settings_sync_section.dart';
import 'package:freak_flix/widgets/trailer_player.dart';

void main() {
  group('Startup platform guard', () {
    test('initializes auto backup manager only on windows desktop', () {
      expect(
        shouldInitializeAutoBackupManager(isWindowsDesktop: true),
        isTrue,
      );
      expect(
        shouldInitializeAutoBackupManager(isWindowsDesktop: false),
        isFalse,
      );
    });
  });

  group('Unsupported capability messaging', () {
    test('scan note is explicit on web and ios', () {
      expect(
        scanConstraintNote(isWeb: true, isIOS: false),
        contains('Web'),
      );
      expect(
        scanConstraintNote(isWeb: false, isIOS: true),
        contains('iOS'),
      );
      expect(
        scanConstraintNote(isWeb: false, isIOS: false),
        isEmpty,
      );
    });

    test('scheduled auto backup reports unsupported platforms', () {
      expect(
        unsupportedAutoBackupMessage(
          isWindowsDesktop: false,
          platformLabel: 'Linux',
        ),
        contains('Linux'),
      );
      expect(
        unsupportedAutoBackupMessage(
          isWindowsDesktop: true,
          platformLabel: 'Windows',
        ),
        isNull,
      );
    });
  });

  group('Trailer launch guard', () {
    test('uses external launcher on desktop runtimes only', () {
      expect(useExternalTrailerLaunch(isDesktopRuntime: true), isTrue);
      expect(useExternalTrailerLaunch(isDesktopRuntime: false), isFalse);
    });
  });
}
