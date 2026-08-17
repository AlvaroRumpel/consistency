import 'package:consistency/pages/settings_page.dart';
import 'package:consistency/state/settings_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'helpers.dart';

void main() {
  testWidgets('threshold slider shows and persists the value', (tester) async {
    final app = await buildApp(prefs: {'threshold': 50});
    await tester.pumpWidget(app);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    // Jump straight to the settings tab.
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Daily target: 50%'), findsOneWidget);

    final ctx = tester.element(find.byType(SettingsPage));
    await ctx.read<SettingsStore>().setThreshold(75);
    await tester.pump();
    expect(find.text('Daily target: 75%'), findsOneWidget);
  });
}
