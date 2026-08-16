import 'package:consistency/configs/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Own file on purpose: LocalData caches SharedPreferences in a static, so
// the empty seed below must be the first one this isolate sees.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('ThemeModel resolves to system when the user never picked a theme',
      () async {
    SharedPreferences.setMockInitialValues({});
    final model = ThemeModel();
    var notified = false;
    model.addListener(() => notified = true);
    expect(model.themeMode, ThemeMode.system);
    // Let _load() finish; it must not flip system → light/dark on its own.
    for (var i = 0; i < 10; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(model.themeMode, ThemeMode.system);
    expect(notified, isTrue);
  });

  test('setMode persists tri-state on the legacy themeDark key', () async {
    final model = ThemeModel();
    final prefs = await SharedPreferences.getInstance();

    await model.setMode(ThemeMode.dark);
    expect(model.themeMode, ThemeMode.dark);
    expect(prefs.getBool('themeDark'), isTrue);

    await model.setMode(ThemeMode.light);
    expect(prefs.getBool('themeDark'), isFalse);

    await model.setMode(ThemeMode.system);
    expect(model.themeMode, ThemeMode.system);
    expect(prefs.containsKey('themeDark'), isFalse);
  });
}
