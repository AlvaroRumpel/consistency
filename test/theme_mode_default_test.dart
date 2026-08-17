import 'package:consistency/data/settings_repository.dart';
import 'package:consistency/state/settings_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('theme resolves to system when the user never picked one', () async {
    SharedPreferences.setMockInitialValues({});
    final s = SettingsStore(
        SettingsRepository(await SharedPreferences.getInstance()));
    expect(s.themeMode, ThemeMode.system);
  });
}
