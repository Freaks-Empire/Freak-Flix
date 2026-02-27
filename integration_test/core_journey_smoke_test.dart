/// integration_test/core_journey_smoke_test.dart
///
/// Route-level smoke checks for mandatory core journeys.

import 'package:flutter_test/flutter_test.dart';

import 'package:freak_flix/router.dart';

void main() {
  group('Core journey smoke routes', () {
    test('setup flow gates pre-setup navigation', () {
      expect(
        redirectPathForState(
          isSetupCompleted: false,
          isProfileSelected: false,
          isAdultContentEnabled: false,
          path: '/discover',
        ),
        '/setup',
      );
      expect(
        redirectPathForState(
          isSetupCompleted: false,
          isProfileSelected: false,
          isAdultContentEnabled: false,
          path: '/setup',
        ),
        isNull,
      );
    });

    test('profile flow gates navigation after setup', () {
      expect(
        redirectPathForState(
          isSetupCompleted: true,
          isProfileSelected: false,
          isAdultContentEnabled: false,
          path: '/discover',
        ),
        '/profiles',
      );
      expect(
        redirectPathForState(
          isSetupCompleted: true,
          isProfileSelected: false,
          isAdultContentEnabled: false,
          path: '/profiles',
        ),
        isNull,
      );
    });

    test('core routes are accessible after setup and profile selection', () {
      const routes = <String>[
        '/',
        '/discover',
        '/movies',
        '/tv',
        '/anime',
        '/media/test-id',
        '/search',
        '/settings',
      ];

      for (final route in routes) {
        final redirect = redirectPathForState(
          isSetupCompleted: true,
          isProfileSelected: true,
          isAdultContentEnabled: false,
          path: route,
        );
        if (route == '/') {
          expect(redirect, '/discover');
        } else {
          expect(redirect, isNull);
        }
      }
    });

    test('adult route remains opt-in protected', () {
      expect(
        redirectPathForState(
          isSetupCompleted: true,
          isProfileSelected: true,
          isAdultContentEnabled: false,
          path: '/adult',
        ),
        '/discover',
      );
      expect(
        redirectPathForState(
          isSetupCompleted: true,
          isProfileSelected: true,
          isAdultContentEnabled: true,
          path: '/adult',
        ),
        isNull,
      );
    });
  });
}
