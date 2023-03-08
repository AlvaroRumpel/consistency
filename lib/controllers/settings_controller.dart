import 'package:consistency/configs/local_data.dart';
import 'package:consistency/controllers/base_controller.dart';
import 'package:flutter/material.dart';

class SettingsController extends BaseController {
  ValueNotifier<String> nickname = ValueNotifier('User');
  ValueNotifier<bool> themeDark = ValueNotifier(true);
  late LocalData localData;

  @override
  void onDispose() {
    // TODO: implement onDispose
  }

  @override
  void onInit() async {
    localData = await LocalData.i;
    nickname.value = await localData.searchNickname() ?? 'User';
    themeDark.value = localData.searchTheme();
  }

  Future<void> clearAllData() async {
    await localData.clearAllData();
    nickname.value = 'User';
  }

  Future<bool> undoClearAllData() async {
    var success = await localData.undoRecoveryData();

    if (success) {
      nickname.value = await localData.searchNickname() ?? 'User';
    }

    return success;
  }

  Future<void> changeTheme(bool value) async {
    themeDark.value = value;
    await localData.saveTheme(value);
  }
}
