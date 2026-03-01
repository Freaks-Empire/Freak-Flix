/// test/security/adult_privacy_test.dart
///
/// Regression tests for adult-content privacy defaults and gating.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:freak_flix/models/user_profile.dart';
import 'package:freak_flix/providers/profile_provider.dart';
import 'package:freak_flix/providers/settings_provider.dart';
import 'package:freak_flix/router.dart';
import 'package:freak_flix/widgets/navigation_dock.dart';

class _TestSettingsProvider extends SettingsProvider {
  @override
  Future<void> save() async {}
}

Future<ProfileProvider> _configuredProfiles() async {
  final profiles = ProfileProvider();
  profiles.profiles = const [
    UserProfile(
      id: 'profile-1',
      name: 'Admin',
      avatarId: 'assets/logo.png',
      colorValue: 0xFF2196F3,
    ),
  ];
  await profiles.selectProfile('profile-1');
  return profiles;
}

void main() {
  group('Adult privacy defaults', () {
    test('adult content is disabled by default', () {
      final settings = _TestSettingsProvider();

      expect(settings.enableAdultContent, isFalse);
    });

    test('adult opt-in toggles deterministically', () async {
      final settings = _TestSettingsProvider();

      await settings.toggleAdultContent(true);
      expect(settings.enableAdultContent, isTrue);

      await settings.toggleAdultContent(false);
      expect(settings.enableAdultContent, isFalse);
    });

    test('import without adult key falls back to privacy-safe default off',
        () async {
      final settings = _TestSettingsProvider();
      await settings.toggleAdultContent(true);

      await settings.importSettings({'isDarkMode': false});

      expect(settings.enableAdultContent, isFalse);
    });

    test('import ignores non-boolean adult values', () async {
      final settings = _TestSettingsProvider();

      await settings.importSettings({'enableAdultContent': 'true'});

      expect(settings.enableAdultContent, isFalse);
    });
  });

  group('Router adult gating', () {
    test('redirects /adult to /discover when opt-in is disabled', () async {
      final settings = _TestSettingsProvider();
      final profiles = await _configuredProfiles();
      await settings.completeSetup();

      final redirect = appRedirectPath(
        settings: settings,
        profiles: profiles,
        path: '/adult',
      );

      expect(redirect, '/discover');
    });

    test('allows /adult when user explicitly opts in', () async {
      final settings = _TestSettingsProvider();
      final profiles = await _configuredProfiles();
      await settings.completeSetup();
      await settings.toggleAdultContent(true);

      final redirect = appRedirectPath(
        settings: settings,
        profiles: profiles,
        path: '/adult',
      );

      expect(redirect, isNull);
    });

    test('re-blocks /adult after opt-out', () async {
      final settings = _TestSettingsProvider();
      final profiles = await _configuredProfiles();
      await settings.completeSetup();
      await settings.toggleAdultContent(true);
      await settings.toggleAdultContent(false);

      final redirect = appRedirectPath(
        settings: settings,
        profiles: profiles,
        path: '/adult',
      );

      expect(redirect, '/discover');
    });

    test('does not overmatch non-adult-prefixed routes', () async {
      final settings = _TestSettingsProvider();
      final profiles = await _configuredProfiles();
      await settings.completeSetup();

      final redirect = appRedirectPath(
        settings: settings,
        profiles: profiles,
        path: '/adult-library',
      );

      expect(redirect, isNull);
    });
  });

  group('Navigation adult tab visibility', () {
    test('resolved index maps hidden adult branch to first visible tab', () {
      final index = resolvedNavigationDockIndex(
        adultEnabled: false,
        currentIndex: 4,
      );

      expect(index, 0);
    });

    testWidgets('adult tab is shown only when opted in', (tester) async {
      final settings = _TestSettingsProvider();

      await tester.pumpWidget(
        ChangeNotifierProvider<SettingsProvider>.value(
          value: settings,
          child: MaterialApp(
            home: Scaffold(
              body: NavigationDock(
                index: 0,
                onTap: (_) {},
              ),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.lock_outline), findsNothing);

      await settings.toggleAdultContent(true);
      await tester.pump();
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);

      await settings.toggleAdultContent(false);
      await tester.pump();
      expect(find.byIcon(Icons.lock_outline), findsNothing);
    });
  });
}
