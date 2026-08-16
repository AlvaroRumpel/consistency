import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('builds with no exception in light mode', (tester) async {
    await tester.pumpWidget(await buildApp(prefs: {'themeDark': false}));
    await tester.pump();
    // A few real frames: lets the splash navigation settle without a
    // wall-clock timer.
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    expect(tester.takeException(), isNull);
    // Non-vacuous check that SettingsStore actually resolved the persisted
    // theme, not just that the app built. Several Scaffolds are mounted by
    // now (the manager page's tabs), but they all read the same MaterialApp
    // theme, so any of them proves the point.
    expect(
      Theme.of(tester.element(find.byType(Scaffold).first)).brightness,
      Brightness.light,
    );
  });
}
