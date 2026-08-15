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
  final bool themeDark;

  SettingData({required this.nickname, required this.themeDark});
}

class SettingsController extends BaseController<SettingState> {
  late LocalData _localData;

  SettingsController(super.initialState);

  @override
  void onInit() async {
    _localData = await LocalData.i;
    emitGuard(
      loadingState: SettingLoading(),
      newState: (_) async {
        final nickname = await _localData.searchNickname() ?? 'User';
        final themeDark = _localData.searchTheme();

        return SettingData(nickname: nickname, themeDark: themeDark);
      },
      errorState: (e) => SettingError(message: e.toString()),
    );
  }

  Future<void> clearAllData() async {
    final newState = state as SettingData;
    emitGuard(
      loadingState: SettingData(
        nickname: newState.nickname,
        themeDark: newState.themeDark,
      ),
      newState: (_) async {
        await _localData.clearAllData();
        return SettingData(nickname: 'User', themeDark: newState.themeDark);
      },
      errorState: (e) => SettingError(message: e.toString()),
    );
  }

  Future<bool> undoClearAllData() async {
    final newState = state as SettingData;
    emit(SettingData(
      nickname: newState.nickname,
      themeDark: newState.themeDark,
    ));

    var success = await _localData.undoRecoveryData();

    if (success) {
      final nickname = await _localData.searchNickname() ?? 'User';

      emit(SettingData(nickname: nickname, themeDark: newState.themeDark));
    }

    return success;
  }

  Future<bool> saveNickname(String? newNickname) async {
    final newState = state as SettingData;
    if (newNickname == null ||
        newNickname.isEmpty ||
        newNickname == newState.nickname) {
      return true;
    }

    await emitGuard(
      loadingState: SettingData(
        nickname: newState.nickname,
        themeDark: newState.themeDark,
      ),
      newState: (_) async {
        await _localData.saveNickname(newNickname);
        return SettingData(
          nickname: newNickname,
          themeDark: newState.themeDark,
        );
      },
      errorState: (e) => SettingError(message: e.toString()),
    );

    return state is SettingData;
  }

  Future<void> changeTheme(bool value) async {
    final newState = state as SettingData;
    emitGuard(
      loadingState: SettingData(
        nickname: newState.nickname,
        themeDark: newState.themeDark,
      ),
      newState: (_) async {
        await _localData.saveTheme(value);
        return SettingData(nickname: newState.nickname, themeDark: value);
      },
      errorState: (e) => SettingError(message: e.toString()),
    );
  }
}
