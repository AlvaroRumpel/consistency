import 'package:flutter/foundation.dart';

import '../state/app_store.dart';
import '../state/settings_store.dart';
import 'base_controller.dart';

sealed class SettingState {}

class SettingLoading extends SettingState {}

class SettingError extends SettingState {}

class SettingData extends SettingState {
  /// null until the user picks one; the UI falls back to l10n.defaultNickname.
  final String? nickname;

  SettingData({required this.nickname});
}

class SettingsController extends BaseController<SettingState> {
  final AppStore store;
  final SettingsStore settings;

  SettingsController(this.store, this.settings) : super(SettingLoading());

  @override
  void onInit() {
    store.addListener(reload);
    settings.addListener(reload);
    reload();
  }

  void reload() {
    if (store.loadError != null) {
      emit(SettingError());
      return;
    }
    emit(SettingData(nickname: settings.nickname));
  }

  Future<void> clearAllData() => store.clearAll();

  Future<bool> undoClearAllData() => store.undoClear();

  Future<void> saveNickname(String? newNickname) async {
    final nickname = newNickname?.trim();
    if (nickname == null || nickname.isEmpty || nickname == settings.nickname) {
      return;
    }
    try {
      await settings.setNickname(nickname);
    } catch (e) {
      debugPrint('setNickname failed: $e');
    }
  }

  @override
  void onDispose() {
    store.removeListener(reload);
    settings.removeListener(reload);
    super.onDispose();
  }
}
