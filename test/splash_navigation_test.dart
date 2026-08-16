import 'package:consistency/data/settings_repository.dart';
import 'package:consistency/main.dart';
import 'package:consistency/pages/skeleton_page.dart';
import 'package:consistency/state/settings_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('splash navigates as soon as storage is ready, no fixed delay',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ConsistencyApp(settings: SettingsStore(SettingsRepository(prefs))),
    );
    // A handful of frames — far less than the old 1500ms timer.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(find.byType(SkelentonPage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
