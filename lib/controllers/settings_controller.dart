import '../state/app_store.dart';
import '../state/settings_store.dart';
import 'base_controller.dart';

sealed class SettingState {}

class SettingLoading extends SettingState {}

class SettingError extends SettingState {
  final String message;

  SettingError({required this.message});
}

class SettingData extends SettingState {
  final String nickname;

  SettingData({required this.nickname});
}

class SettingsController extends BaseController<SettingState> {
  final AppStore store;
  final SettingsStore settings;

  SettingsController(this.store, this.settings) : super(SettingLoading());

  @override
  void onInit() {
    settings.addListener(reload);
    reload();
  }

  void reload() => emit(SettingData(nickname: settings.nicknameOrDefault));

  Future<void> clearAllData() => store.clearAll();

  Future<bool> undoClearAllData() => store.undoClear();

  Future<bool> saveNickname(String? newNickname) async {
    final nickname = newNickname?.trim();
    if (nickname == null || nickname.isEmpty || nickname == settings.nickname) {
      return true;
    }
    await settings.setNickname(nickname);
    return true;
  }

  @override
  void onDispose() {
    settings.removeListener(reload);
    super.onDispose();
  }
}
