import 'package:consistency/configs/colors.dart';
import 'package:consistency/configs/theme.dart';
import 'package:consistency/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ThemeData tokens', () {
    test('themeDark carries the exact dark-mode token values', () {
      expect(themeDark.brightness, Brightness.dark);
      expect(themeDark.cardColor, AppColors.blackColor);
      expect(themeDark.iconTheme.color, AppColors.whiteColor);
      expect(themeDark.dividerColor,
          AppColors.whiteColor.shade900.withValues(alpha: .3));
      expect(themeDark.textSelectionTheme.cursorColor, AppColors.whiteColor);
    });

    test('themeLight carries the exact light-mode token values', () {
      expect(themeLight.brightness, Brightness.light);
      expect(themeLight.cardColor, AppColors.whiteColor.shade700);
      expect(themeLight.iconTheme.color, AppColors.blackColor);
      expect(
          themeLight.dividerColor, AppColors.blackColor.withValues(alpha: .3));
      expect(themeLight.textSelectionTheme.cursorColor, AppColors.blackColor);
    });
  });

  group('app smoke test', () {
    testWidgets('builds with no exception in dark mode', (tester) async {
      SharedPreferences.setMockInitialValues({'themeDark': true});

      await tester.pumpWidget(const ConsistencyApp());
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
      // Non-vacuous check that ThemeModel actually resolved the persisted
      // theme, not just that the app built. Several Scaffolds are mounted by
      // now (the manager page's tabs), but they all read the same MaterialApp
      // theme, so any of them proves the point.
      expect(
        Theme.of(tester.element(find.byType(Scaffold).first)).brightness,
        Brightness.dark,
      );
    });
  });
}
