import 'package:consistency/configs/local_data.dart';
import 'package:consistency/configs/utilities.dart';
import 'package:consistency/controllers/base_controller.dart';
import 'package:consistency/enums/type_enum.dart';
import 'package:consistency/models/date_goal_model.dart';
import 'package:consistency/models/event_model.dart';
import 'package:consistency/models/goal_model.dart';
import 'package:flutter/material.dart';

class HomeController extends BaseController {
  late LocalData localData;
  ValueNotifier<String> nickname = ValueNotifier('User');
  ValueNotifier<double> completePercent = ValueNotifier(100.0);
  ValueNotifier<List<GoalModel>?> goals = ValueNotifier(null);
  ValueNotifier<TypeEnum> type = ValueNotifier(TypeEnum.slider);
  List<TextEditingController> goalsControllers = <TextEditingController>[];
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

      if (userData!.percentCompleted?.last != null) {
        completePercent.value = userData!.percentCompleted!.last;
        return;
      }

      if (userData!.goals != null &&
          userData!.goals!.last.date !=
              DateTime(
                DateTime.now().year,
                DateTime.now().month,
                DateTime.now().day,
              )) {
        goals.value = [...userData!.goals!.last.goals];
        setGoalsControllers();
        return;
      }
    }

    goals.value ??= userData != null && userData!.goals != null
        ? userData!.goals!.last.goals.map((e) => e.copyWith()).toList()
        : null;

    setGoalsControllers();
  }

  void setGoalsControllers() {
    if (goals.value != null) {
      for (var goal in goals.value!) {
        goalsControllers.add(TextEditingController(text: goal.name));
      }
    }
  }

  Future<void> saveData() async {
    final currentDate = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );

    var totalPercentCompleted = 0.0;
    for (var i = 0; i < goals.value!.length; i++) {
      goals.value![i].name = goalsControllers[i].text;
      totalPercentCompleted =
          goals.value![i].percentCompleted + totalPercentCompleted;
    }

    var avgPercentCompleted = totalPercentCompleted / goals.value!.length;

    userData ??= EventModel(
      dates: [currentDate],
      colors: [Utilities.activeColor(avgPercentCompleted)],
      goals: goals.value != null
          ? [
              DateGoalModel(date: currentDate, goals: [...goals.value!])
            ]
          : null,
    );

    if (userData!.dates.last != currentDate) {
      userData!.dates.add(currentDate);
      userData!.colors.add(Utilities.activeColor(avgPercentCompleted));
      userData!.goals = userData!.goals != null
          ? [
              ...?userData!.goals,
              DateGoalModel(date: currentDate, goals: [...goals.value!])
            ]
          : [
              DateGoalModel(date: currentDate, goals: [...goals.value!])
            ];
    }

    hasMarketToday.value = await localData.saveUserData(userData!);
  }

  void addNewGoal() {
    goals.value = goals.value != null
        ? [
            ...?goals.value,
            GoalModel(
              name: 'New Goal',
              percentCompleted: 0,
              type: TypeEnum.slider,
            )
          ]
        : [
            GoalModel(
              name: 'New Goal',
              percentCompleted: 0,
              type: TypeEnum.slider,
            ),
          ];
    setGoalsControllers();
  }

  void removeGoal(int index) {
    if (hasMarketToday.value) return;
    var goalsCopy = [...goals.value!];
    goalsCopy.removeAt(index);
    goals.value = goalsCopy;
    goalsControllers.removeAt(index);
  }
}
