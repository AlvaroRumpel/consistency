import 'dart:convert';
import 'dart:developer';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/date_goal_model.dart';
import '../models/recovery_model.dart';
import 'exceptions/local_data_exception.dart';

class LocalData {
  final String _nickname = 'nickname';
  final String _userData = 'userData';
  final String _themeDark = 'themeDark';
  final String _recoveryData = 'beforeDelete';

  static SharedPreferences? _sharedPreferences;

  static LocalData? _instance;

  LocalData._();
  static Future<LocalData> get i async {
    await _initSharedPreferences();
    return _instance ??= LocalData._();
  }

  static Future<void> _initSharedPreferences() async {
    _sharedPreferences ??= await SharedPreferences.getInstance();
  }

  Future<bool> saveNickname(String nickname) async {
    try {
      return await _sharedPreferences!.setString(_nickname, nickname);
    } catch (e, s) {
      log(e.toString(), error: e, stackTrace: s);
      throw LocalDataException(
        message: 'Error on save your nickname',
        typeError: LocalDataErrorType.save,
      );
    }
  }

  Future<String?> searchNickname() async {
    try {
      return _sharedPreferences!.getString(_nickname);
    } catch (e, s) {
      log(e.toString(), error: e, stackTrace: s);
      throw LocalDataException(
        message: 'Erro on search your nickname',
        typeError: LocalDataErrorType.search,
      );
    }
  }

  Future<bool> saveUserData(List<DateGoalModel> goalsModel) async {
    try {
      final goals = jsonEncode(goalsModel);
      return await _sharedPreferences!.setString(_userData, goals);
    } catch (e, s) {
      log(e.toString(), error: e, stackTrace: s);
      throw LocalDataException(
        message: 'Error on save your data',
        typeError: LocalDataErrorType.save,
      );
    }
  }

  Future<List<DateGoalModel>?> searchUserData() async {
    try {
      final userDataJson = _sharedPreferences!.getString(_userData);
      if (userDataJson != null) {
        final userDataList = jsonDecode(userDataJson);
        final userData = <DateGoalModel>[];
        for (final data in userDataList) {
          userData.add(DateGoalModel.fromJson(data));
        }

        return userData;
      }
    } catch (e, s) {
      log(e.toString(), error: e, stackTrace: s);
      throw LocalDataException(
        message: 'Erro on search your data',
        typeError: LocalDataErrorType.search,
      );
    }
    return null;
  }

  Future<bool> saveTheme(bool value) async {
    try {
      return await _sharedPreferences!.setBool(_themeDark, value);
    } catch (e, s) {
      log(e.toString(), error: e, stackTrace: s);
      throw LocalDataException(
        message: 'Error on save your theme',
        typeError: LocalDataErrorType.save,
      );
    }
  }

  bool searchTheme() {
    try {
      return _sharedPreferences?.getBool(_themeDark) ?? false;
    } catch (e, s) {
      log(e.toString(), error: e, stackTrace: s);
      throw LocalDataException(
        message: 'Erro on search your theme',
        typeError: LocalDataErrorType.search,
      );
    }
  }

  Future<RecoveryModel> _saveRecoveryData() async {
    try {
      var nickname = await searchNickname();
      var userData = await searchUserData();
      return RecoveryModel(
        nickname: nickname,
        userData: userData,
      );
    } catch (e, s) {
      log(e.toString(), error: e, stackTrace: s);
      throw LocalDataException(
        message: 'Error on save your theme',
        typeError: LocalDataErrorType.save,
      );
    }
  }

  Future<bool> undoRecoveryData() async {
    try {
      var recoveryModelString = _sharedPreferences!.getString(_recoveryData);

      if (recoveryModelString != null && recoveryModelString.isNotEmpty) {
        var recoveryModel = RecoveryModel.fromJson(recoveryModelString);

        if (recoveryModel.nickname != null) {
          await saveNickname(recoveryModel.nickname!);
        }

        if (recoveryModel.userData != null) {
          await saveUserData(recoveryModel.userData!);
        }
      }

      return recoveryModelString != null && recoveryModelString.isNotEmpty;
    } catch (e, s) {
      log(e.toString(), error: e, stackTrace: s);
      throw LocalDataException(
        message: 'Erro on search your recovery data',
        typeError: LocalDataErrorType.search,
      );
    }
  }

  Future<void> clearAllData() async {
    try {
      var theme = searchTheme();
      var recoveryModel = await _saveRecoveryData();
      await _sharedPreferences!.clear();
      await saveTheme(theme);
      await _sharedPreferences!.setString(
        _recoveryData,
        recoveryModel.toJson(),
      );
    } catch (e, s) {
      log(e.toString(), error: e, stackTrace: s);
      throw LocalDataException(
        message: 'Erro on clear all data',
        typeError: LocalDataErrorType.generic,
      );
    }
  }
}
