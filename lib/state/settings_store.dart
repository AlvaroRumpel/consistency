import 'package:flutter/material.dart';

import '../data/settings_repository.dart';

class SettingsStore extends ChangeNotifier {
  final SettingsRepository _repo;
  SettingsStore(this._repo);

  String? get nickname => _repo.nickname;
  ThemeMode get themeMode => _repo.themeMode;
  int get threshold => _repo.threshold;
  bool get notifEnabled => _repo.notifEnabled;
  (int, int) get notifTime => _repo.notifTime;
  bool get onboardingDone => _repo.onboardingDone;
  String? get widgetLocale => _repo.widgetLocale;

  Future<void> _apply(Future<void> Function() write) async {
    await write();
    notifyListeners();
  }

  Future<void> setNickname(String? v) => _apply(() => _repo.setNickname(v));
  Future<void> setThemeMode(ThemeMode m) => _apply(() => _repo.setThemeMode(m));
  Future<void> setThreshold(int v) => _apply(() => _repo.setThreshold(v));
  Future<void> setNotifEnabled(bool v) =>
      _apply(() => _repo.setNotifEnabled(v));
  Future<void> setNotifTime(int h, int m) =>
      _apply(() => _repo.setNotifTime(h, m));
  Future<void> setOnboardingDone(bool v) =>
      _apply(() => _repo.setOnboardingDone(v));

  /// Deliberately not through [_apply]: nothing on screen reads it, and
  /// notifying here would bounce straight back into `WidgetSyncService`,
  /// which is what writes it.
  Future<void> setWidgetLocale(String v) => _repo.setWidgetLocale(v);
}
