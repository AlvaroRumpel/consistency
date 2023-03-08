import 'dart:developer';

import 'package:consistency/configs/exceptions/local_data_exception.dart';
import 'package:consistency/models/event_model.dart';
import 'package:consistency/models/recovery_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalData {
  final String _nickname = 'nickname';
  final String _userData = 'userData';
  final String _themeDark = 'themeDark';
  final String _recoveryData = 'beforeDelete';

  static SharedPreferences? sharedPreferences;

  static LocalData? _instance;

  LocalData._();
  static Future<LocalData> get i async {
    await _initSharedPreferences();
    return _instance ??= LocalData._();
  }

  static Future<void> _initSharedPreferences() async {
    sharedPreferences ??= await SharedPreferences.getInstance();
  }

  Future<bool> saveNickname(String nickname) async {
    try {
      return await sharedPreferences!.setString(_nickname, nickname);
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
      return sharedPreferences!.getString(_nickname);
    } catch (e, s) {
      log(e.toString(), error: e, stackTrace: s);
      throw LocalDataException(
        message: 'Erro on search your nickname',
        typeError: LocalDataErrorType.search,
      );
    }
  }

  Future<bool> saveUserData(EventModel eventModel) async {
    try {
      return await sharedPreferences!.setString(_userData, eventModel.toJson());
    } catch (e, s) {
      log(e.toString(), error: e, stackTrace: s);
      throw LocalDataException(
        message: 'Error on save your data',
        typeError: LocalDataErrorType.save,
      );
    }
  }

  Future<EventModel?> searchUserData() async {
    try {
      final userData = sharedPreferences!.getString(_userData);
      if (userData != null) return EventModel.fromJson(userData);
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
      return await sharedPreferences!.setBool(_themeDark, value);
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
      return sharedPreferences?.getBool(_themeDark) ?? false;
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
      var recoveryModelString = sharedPreferences!.getString(_recoveryData);

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
      await sharedPreferences!.clear();
      await saveTheme(theme);
      await sharedPreferences!.setString(_recoveryData, recoveryModel.toJson());
    } catch (e, s) {
      log(e.toString(), error: e, stackTrace: s);
      throw LocalDataException(
        message: 'Erro on clear all data',
        typeError: LocalDataErrorType.generic,
      );
    }
  }
}
