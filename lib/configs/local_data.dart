import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/date_goal_model.dart';
import '../models/recovery_model.dart';

class LocalData {
  final String _nickname = 'nickname';
  final String _userData = 'userData';
  final String _themeDark = 'themeDark';
  final String _recoveryData = 'beforeDelete';

  static SharedPreferences? _sharedPreferences;

  static LocalData? _instance;

  /// Bumped when data is wiped or restored from outside the controller that
  /// owns it, so other live pages can reload. Not bumped by saveUserData —
  /// its only caller already holds the resulting state.
  static final ValueNotifier<int> revision = ValueNotifier(0);

  LocalData._();
  static Future<LocalData> get i async {
    await _initSharedPreferences();
    return _instance ??= LocalData._();
  }

  static Future<void> _initSharedPreferences() async {
    _sharedPreferences ??= await SharedPreferences.getInstance();
  }

  Future<bool> saveNickname(String nickname) =>
      _sharedPreferences!.setString(_nickname, nickname);

  Future<String?> searchNickname() async =>
      _sharedPreferences!.getString(_nickname);

  // jsonEncode calls DateGoalModel.toJson() per element, which itself returns a
  // JSON String — so the stored value is an array of JSON strings. searchUserData
  // mirrors that. Changing it breaks every installed app's saved history.
  Future<bool> saveUserData(List<DateGoalModel> goalsModel) =>
      _sharedPreferences!.setString(_userData, jsonEncode(goalsModel));

  Future<List<DateGoalModel>?> searchUserData() async {
    final userDataJson = _sharedPreferences!.getString(_userData);
    if (userDataJson == null) return null;

    return [
      for (final data in jsonDecode(userDataJson) as List)
        DateGoalModel.fromJson(data as String),
    ];
  }

  Future<bool> saveTheme(bool value) =>
      _sharedPreferences!.setBool(_themeDark, value);

  /// null = user never chose; caller falls back to ThemeMode.system.
  bool? searchTheme() => _sharedPreferences?.getBool(_themeDark);

  Future<RecoveryModel> _saveRecoveryData() async => RecoveryModel(
        nickname: await searchNickname(),
        userData: await searchUserData(),
      );

  Future<bool> undoRecoveryData() async {
    final recoveryModelString = _sharedPreferences!.getString(_recoveryData);
    if (recoveryModelString == null || recoveryModelString.isEmpty) {
      return false;
    }

    final recoveryModel = RecoveryModel.fromJson(recoveryModelString);

    if (recoveryModel.nickname != null) {
      await saveNickname(recoveryModel.nickname!);
    }
    if (recoveryModel.userData != null) {
      await saveUserData(recoveryModel.userData!);
    }

    revision.value++;
    return true;
  }

  Future<void> clearAllData() async {
    final theme = searchTheme();
    final recoveryModel = await _saveRecoveryData();
    await _sharedPreferences!.clear();
    if (theme != null) await saveTheme(theme);
    await _sharedPreferences!.setString(_recoveryData, recoveryModel.toJson());
    revision.value++;
  }
}
