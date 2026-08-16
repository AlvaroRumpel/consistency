import 'package:consistency/configs/colors.dart';
import 'package:consistency/configs/theme.dart';
import 'package:consistency/data/settings_repository.dart';
import 'package:consistency/main.dart';
import 'package:consistency/state/settings_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ThemeData tokens', () {
    test('themeDark carries the design token values', () {
      expect(themeDark.brightness, Brightness.dark);
      expect(themeDark.cardColor, AppColors.cardDark);
      expect(themeDark.scaffoldBackgroundColor, AppColors.surfaceDark);
      expect(themeDark.iconTheme.color, AppColors.textDark);
      expect(themeDark.dividerColor, AppColors.dividerDark);
      expect(themeDark.textSelectionTheme.cursorColor, AppColors.textDark);
    });

    test('themeLight carries the design token values', () {
      expect(themeLight.brightness, Brightness.light);
      expect(themeLight.cardColor, AppColors.cardLight);
      expect(themeLight.scaffoldBackgroundColor, AppColors.surfaceLight);
      expect(themeLight.iconTheme.color, AppColors.textLight);
      expect(themeLight.dividerColor, AppColors.dividerLight);
      expect(themeLight.textSelectionTheme.cursorColor, AppColors.textLight);
    });
  });

  group('app smoke test', () {
    testWidgets('builds with no exception in dark mode', (tester) async {
      SharedPreferences.setMockInitialValues({'themeDark': true});
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
        Brightness.dark,
      );
    });
  });
}
