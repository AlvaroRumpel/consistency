import 'package:consistency/data/settings_repository.dart';
import 'package:consistency/state/settings_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('defaults on a fresh install', () async {
    SharedPreferences.setMockInitialValues({});
    final s = SettingsStore(
        SettingsRepository(await SharedPreferences.getInstance()));
    expect(s.themeMode, ThemeMode.system);
    expect(s.nickname, isNull);
    expect(s.nicknameOrDefault, 'User');
    expect(s.threshold, 50);
    expect(s.notifEnabled, isFalse);
    expect(s.notifTime, (20, 0));
    expect(s.onboardingDone, isFalse);
  });

  test('reads legacy keys and persists on the same keys', () async {
    SharedPreferences.setMockInitialValues(
        {'themeDark': true, 'nickname': 'Alvaro'});
    final prefs = await SharedPreferences.getInstance();
    final s = SettingsStore(SettingsRepository(prefs));
    expect(s.themeMode, ThemeMode.dark);
    expect(s.nickname, 'Alvaro');

    var notified = 0;
    s.addListener(() => notified++);
    await s.setThemeMode(ThemeMode.light);
    expect(prefs.getBool('themeDark'), isFalse);
    await s.setThemeMode(ThemeMode.system);
    expect(prefs.containsKey('themeDark'), isFalse);
    await s.setThreshold(75);
    expect(prefs.getInt('threshold'), 75);
    await s.setNotifTime(7, 30);
    expect(s.notifTime, (7, 30));
    await s.setNickname('  ');
    expect(s.nickname, isNull);
    expect(notified, 5);
  });

  test('threshold is clamped to 0..100', () async {
    SharedPreferences.setMockInitialValues({});
    final s = SettingsStore(
        SettingsRepository(await SharedPreferences.getInstance()));
    await s.setThreshold(140);
    expect(s.threshold, 100);
    await s.setThreshold(-5);
    expect(s.threshold, 0);
  });
}
