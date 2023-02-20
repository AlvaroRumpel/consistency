import 'dart:developer';

import 'package:consistency/configs/exceptions/local_data_exception.dart';
import 'package:consistency/models/event_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalData {
  final String _nickname = 'nickname';
  final String _userData = 'userData';

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

  Future<void> clearAllData() async {
    try {
      await sharedPreferences!.clear();
    } catch (e, s) {
      log(e.toString(), error: e, stackTrace: s);
      throw LocalDataException(
        message: 'Erro on clear all data',
        typeError: LocalDataErrorType.generic,
      );
    }
  }
}
