import 'package:consistency/configs/colors.dart';
import 'package:consistency/configs/local_data.dart';
import 'package:consistency/controllers/base_controller.dart';
import 'package:consistency/models/event_model.dart';
import 'package:flutter/material.dart';

class HomeController extends BaseController {
  late LocalData localData;
  ValueNotifier<String> nickname = ValueNotifier('User');
  ValueNotifier<double> completePercent = ValueNotifier(100.0);
  EventModel? userData;

  ValueNotifier<bool> hasMarketToday = ValueNotifier(false);

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
      hasMarketToday.value = true;
      completePercent.value = userData!.percentCompleted.last;
    }
  }

  Future<void> saveData() async {
    final currentDate = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );

    userData ??= EventModel(
      dates: [currentDate],
      colors: [activeColor(completePercent.value)],
      percentCompleted: [completePercent.value],
    );

    if (userData!.dates.last != currentDate) {
      userData!.dates.add(currentDate);
      userData!.colors.add(activeColor(completePercent.value));
      userData!.percentCompleted.add(completePercent.value);
    }

    hasMarketToday.value = await localData.saveUserData(userData!);
  }

  Color activeColor(double value) {
    if (value > 75.0) {
      return AppColors.greenColor;
    }
    if (value == 75.0) {
      return AppColors.primaryColor;
    }
    if (value == 50.0) {
      return AppColors.redColor.shade50;
    }
    if (value == 25.0) {
      return AppColors.redColor;
    }
    if (value < 25.0) {
      return AppColors.redColor.shade900;
    }
    return AppColors.greenColor;
  }
}
