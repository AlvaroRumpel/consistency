import '../configs/local_data.dart';
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
  late LocalData _localData;

  SettingsController(super.initialState);

  @override
  void onInit() => reload();

  Future<void> reload() async {
    await emitGuard(
      loadingState: SettingLoading(),
      newState: (_) async {
        _localData = await LocalData.i;
        return SettingData(
            nickname: await _localData.searchNickname() ?? 'User');
      },
      errorState: (e) => SettingError(message: e.toString()),
    );
  }

  Future<void> clearAllData() async {
    final current = state;
    if (current is! SettingData) return;

    emitGuard(
      loadingState: SettingData(nickname: current.nickname),
      newState: (_) async {
        await _localData.clearAllData();
        return SettingData(nickname: 'User');
      },
      errorState: (e) => SettingError(message: e.toString()),
    );
  }

  Future<bool> undoClearAllData() async {
    final current = state;
    if (current is! SettingData) return false;

    var success = await _localData.undoRecoveryData();

    if (success) {
      final nickname = await _localData.searchNickname() ?? 'User';
      emit(SettingData(nickname: nickname));
    }

    return success;
  }

  Future<bool> saveNickname(String? newNickname) async {
    final current = state;
    if (current is! SettingData) return false;

    if (newNickname == null ||
        newNickname.isEmpty ||
        newNickname == current.nickname) {
      return true;
    }

    await emitGuard(
      loadingState: SettingData(nickname: current.nickname),
      newState: (_) async {
        await _localData.saveNickname(newNickname);
        return SettingData(nickname: newNickname);
      },
      errorState: (e) => SettingError(message: e.toString()),
    );

    return state is SettingData;
  }
}
