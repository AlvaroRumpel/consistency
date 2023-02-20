import 'package:consistency/configs/local_data.dart';
import 'package:consistency/controllers/base_controller.dart';
import 'package:consistency/models/event_model.dart';
import 'package:flutter/material.dart';

class HomeController extends BaseController {
  late LocalData localData;
  ValueNotifier<String> nickname = ValueNotifier('User');
  EventModel? userData;

  bool hasMarketToday = false;

  @override
  void onDispose() {
    // TODO: implement onDispose
  }

  @override
  void onInit() async {
    localData = await LocalData.i;
    nickname.value = await localData.searchNickname() ?? 'User';
    userData = await localData.searchUserData();

    if (userData != null &&
        userData?.dates.last ==
            DateTime(
              DateTime.now().year,
              DateTime.now().month,
              DateTime.now().day,
            )) {
      hasMarketToday = true;
    }
  }

  Future<void> saveData() async {
    final currentDate = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );

    userData ??= EventModel(dates: [currentDate]);

    if (userData!.dates.last != currentDate) {
      userData!.dates.add(currentDate);
    }

    hasMarketToday = await localData.saveUserData(userData!);
  }
}
