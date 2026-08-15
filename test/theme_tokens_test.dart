import 'package:consistency/configs/theme.dart';
import 'package:consistency/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ThemeData tokens', () {
    test('themeDark defines every token this task introduced', () {
      expect(themeDark.cardColor, isNotNull);
      expect(themeDark.iconTheme.color, isNotNull);
      expect(themeDark.dividerColor, isNotNull);
      expect(themeDark.textSelectionTheme.cursorColor, isNotNull);
    });

    test('themeLight defines every token this task introduced', () {
      expect(themeLight.cardColor, isNotNull);
      expect(themeLight.iconTheme.color, isNotNull);
      expect(themeLight.dividerColor, isNotNull);
      expect(themeLight.textSelectionTheme.cursorColor, isNotNull);
    });
  });

  group('app smoke test', () {
    testWidgets('builds with no exception in dark mode', (tester) async {
      SharedPreferences.setMockInitialValues({'themeDark': true});

      await tester.pumpWidget(const ConsistencyApp());
      await tester.pump();
      // Fires the splash screen's Future.delayed(1500ms) navigation timer
      // so it doesn't leak into the next pump/test as a pending timer.
      await tester.pump(const Duration(milliseconds: 1600));
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
    });

    testWidgets('builds with no exception in light mode', (tester) async {
      SharedPreferences.setMockInitialValues({'themeDark': false});

      await tester.pumpWidget(const ConsistencyApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1600));
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });
}
