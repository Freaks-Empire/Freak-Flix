/// test/router/onboarding_redirect_test.dart
///
/// Tests for setup redirect behavior - ensures source completion is not a hard gate.

import 'package:flutter_test/flutter_test.dart';

import 'package:freak_flix/router.dart';

void main() {
  group('Onboarding redirect behavior', () {
    test('redirects to setup when not completed', () {
      final result = redirectPathForState(
        isSetupCompleted: false,
        isProfileSelected: true,
        isAdultContentEnabled: false,
        path: '/discover',
      );

      expect(result, '/setup');
    });

    test('allows discover when setup completed', () {
      final result = redirectPathForState(
        isSetupCompleted: true,
        isProfileSelected: true,
        isAdultContentEnabled: false,
        path: '/discover',
      );

      expect(result, isNull);
    });

    test('redirects away from setup when already completed', () {
      final result = redirectPathForState(
        isSetupCompleted: true,
        isProfileSelected: true,
        isAdultContentEnabled: false,
        path: '/setup',
      );

      expect(result, '/discover');
    });

    test('does not block on source completion', () {
      // This test verifies that source completion is NOT a gate
      // The redirect only checks isSetupCompleted, not source statuses
      final result = redirectPathForState(
        isSetupCompleted: true, // Setup complete even with no sources
        isProfileSelected: true,
        isAdultContentEnabled: false,
        path: '/discover',
      );

      // Should allow access - source completion is optional
      expect(result, isNull);
    });

    test('still protects adult routes when disabled', () {
      final result = redirectPathForState(
        isSetupCompleted: true,
        isProfileSelected: true,
        isAdultContentEnabled: false,
        path: '/adult',
      );

      // Should redirect away from adult route
      expect(result, '/discover');
    });

    test('allows adult routes when enabled', () {
      final result = redirectPathForState(
        isSetupCompleted: true,
        isProfileSelected: true,
        isAdultContentEnabled: true,
        path: '/adult',
      );

      expect(result, isNull);
    });

    test('redirects root to discover', () {
      final result = redirectPathForState(
        isSetupCompleted: true,
        isProfileSelected: true,
        isAdultContentEnabled: false,
        path: '/',
      );

      expect(result, '/discover');
    });

    test('handles profile selection gating separately', () {
      // Setup complete but no profile selected
      final result = redirectPathForState(
        isSetupCompleted: true,
        isProfileSelected: false,
        isAdultContentEnabled: false,
        path: '/discover',
      );

      expect(result, '/profiles');
    });
  });
}
