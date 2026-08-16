import 'package:consistency/data/settings_repository.dart';
import 'package:consistency/main.dart';
import 'package:consistency/state/settings_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Kept in its own file, separate from theme_tokens_test.dart: each test file
// runs in its own isolate, so LocalData's cached SharedPreferences instance
// (a static) starts fresh here instead of carrying over the `themeDark: true`
// left behind by the dark-mode smoke test.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('builds with no exception in light mode', (tester) async {
    SharedPreferences.setMockInitialValues({'themeDark': false});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ConsistencyApp(settings: SettingsStore(SettingsRepository(prefs))),
    );
    await tester.pump();
    // A few real frames: lets the splash navigation (async over LocalData.i)
    // settle without a wall-clock timer.
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
