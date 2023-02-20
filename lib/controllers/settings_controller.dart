import 'package:consistency/configs/local_data.dart';
import 'package:consistency/controllers/base_controller.dart';
import 'package:flutter/material.dart';

class SettingsController extends BaseController {
  ValueNotifier<String> nickname = ValueNotifier('User');
  late LocalData localData;

  @override
  void onDispose() {
    // TODO: implement onDispose
  }

  @override
  void onInit() async {
    localData = await LocalData.i;
    nickname.value = await localData.searchNickname() ?? 'User';
  }

  Future<void> clearAllData() async {
    await localData.clearAllData();
    nickname.value = 'User';
  }
}
