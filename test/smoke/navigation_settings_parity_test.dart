/// test/smoke/navigation_settings_parity_test.dart
///
/// Semantic parity checks for navigation dock and settings visibility behavior.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:freak_flix/providers/settings_provider.dart';
import 'package:freak_flix/widgets/navigation_dock.dart';

class _TestSettingsProvider extends SettingsProvider {
  @override
  Future<void> save() async {}
}

void main() {
  group('Navigation/settings parity', () {
    test('branch mapping stays stable with adult hidden vs visible', () {
      expect(
        visibleNavigationBranchIndices(adultEnabled: false),
        const [0, 1, 2, 3, 5, 6],
      );
      expect(
        visibleNavigationBranchIndices(adultEnabled: true),
        const [0, 1, 2, 3, 4, 5, 6],
      );
    });

    testWidgets('dock renders parity-safe tabs and branch taps',
        (tester) async {
      final settings = _TestSettingsProvider();
      var tappedBranch = -1;

      await tester.pumpWidget(
        ChangeNotifierProvider<SettingsProvider>.value(
          value: settings,
          child: MaterialApp(
            home: Scaffold(
              body: NavigationDock(
                index: 0,
                onTap: (branch) => tappedBranch = branch,
              ),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.lock_outline), findsNothing);
      await tester.tap(find.byIcon(Icons.search));
      expect(tappedBranch, 5);

      await tester.tap(find.byIcon(Icons.settings_outlined));
      expect(tappedBranch, 6);

      await settings.toggleAdultContent(true);
      await tester.pump();
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);

      await tester.tap(find.byIcon(Icons.lock_outline));
      expect(tappedBranch, 4);
    });
  });
}
