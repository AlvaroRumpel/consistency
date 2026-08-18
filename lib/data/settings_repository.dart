import 'package:flutter/material.dart' show ThemeMode;
import 'package:shared_preferences/shared_preferences.dart';

/// Small typed facade over SharedPreferences. Legacy keys are kept so
/// installed apps keep their nickname and theme.
class SettingsRepository {
  final SharedPreferences _p;
  SettingsRepository(this._p);

  static const _nickname = 'nickname';
  static const _themeDark = 'themeDark';
  static const _threshold = 'threshold';
  static const _notifEnabled = 'notifEnabled';
  static const _notifHour = 'notifHour';
  static const _notifMinute = 'notifMinute';
  static const _onboardingDone = 'onboardingDone';
  static const _widgetLocale = 'widgetLocale';

  String? get nickname {
    final n = _p.getString(_nickname)?.trim();
    return (n == null || n.isEmpty) ? null : n;
  }

  Future<void> setNickname(String? v) {
    final n = v?.trim();
    return (n == null || n.isEmpty)
        ? _p.remove(_nickname)
        : _p.setString(_nickname, n);
  }

  ThemeMode get themeMode => switch (_p.getBool(_themeDark)) {
        null => ThemeMode.system,
        true => ThemeMode.dark,
        false => ThemeMode.light,
      };

  Future<void> setThemeMode(ThemeMode m) => switch (m) {
        ThemeMode.system => _p.remove(_themeDark),
        ThemeMode.dark => _p.setBool(_themeDark, true),
        ThemeMode.light => _p.setBool(_themeDark, false),
      };

  int get threshold => (_p.getInt(_threshold) ?? 50).clamp(0, 100);
  Future<void> setThreshold(int v) => _p.setInt(_threshold, v.clamp(0, 100));

  bool get notifEnabled => _p.getBool(_notifEnabled) ?? false;
  Future<void> setNotifEnabled(bool v) => _p.setBool(_notifEnabled, v);

  (int, int) get notifTime =>
      (_p.getInt(_notifHour) ?? 20, _p.getInt(_notifMinute) ?? 0);
  Future<void> setNotifTime(int hour, int minute) async {
    await _p.setInt(_notifHour, hour);
    await _p.setInt(_notifMinute, minute);
  }

  bool get onboardingDone => _p.getBool(_onboardingDone) ?? false;
  Future<void> setOnboardingDone(bool v) => _p.setBool(_onboardingDone, v);

  /// Language code the home-screen widget was last published with. Not a
  /// user setting: the headless midnight tick has no app locale, so the
  /// foreground app leaves its own here for the tick to read back.
  String? get widgetLocale => _p.getString(_widgetLocale);
  Future<void> setWidgetLocale(String v) => _p.setString(_widgetLocale, v);
}
