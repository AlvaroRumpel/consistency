import 'package:flutter/material.dart';
import 'package:flutter_calendar_carousel/classes/event.dart';
import 'package:flutter_calendar_carousel/flutter_calendar_carousel.dart';

import '../configs/local_data.dart';
import '../configs/utilities.dart';
import '../models/date_goal_model.dart';
import 'base_controller.dart';

sealed class CalendarState {}

class CalendarLoading extends CalendarState {}

class CalendarData extends CalendarState {
  final EventList<Event> eventList;
  final DateGoalModel? selectedDaysGoals;
  final DateTime selectedDay;

  CalendarData({
    required this.eventList,
    required this.selectedDaysGoals,
    required this.selectedDay,
  });
}

class CalendarError extends CalendarState {
  final String message;

  CalendarError({required this.message});
}

class CalendarController extends BaseController<CalendarState> {
  late LocalData _localData;
  final _userData = <DateGoalModel>[];

  CalendarController(super.initialState);

  @override
  void onInit() async {
    _localData = await LocalData.i;
    _userData.addAll((await _localData.searchUserData() ?? []));
    treatData();
  }

  void treatData() {
    emitGuard(
      loadingState: CalendarLoading(),
      newState: (oldState) {
        EventList<Event> eventListTemp = EventList(events: {});
        if (_userData.isNotEmpty) {
          for (final item in _userData) {
            var totalPercent = 0.0;

            for (final goal in item.goals) {
              totalPercent += goal.percentCompleted;
            }

            final avgPercent = totalPercent / item.goals.length;

            eventListTemp.add(
              item.date,
              Event(
                date: item.date,
                dot: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.rectangle,
                    color: Utilities.activeColor(avgPercent),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  height: 2.0,
                  width: 16.0,
                ),
              ),
            );
          }
        }

        return CalendarData(
          eventList: eventListTemp,
          selectedDaysGoals:
              oldState is CalendarData ? oldState.selectedDaysGoals : null,
          selectedDay: oldState is CalendarData
              ? oldState.selectedDaysGoals?.date ?? DateTime.now()
              : DateTime.now(),
        );
      },
      errorState: (e) => CalendarError(message: e.toString()),
    );
  }

  void selectDay(DateTime date) {
    final oldState = state as CalendarData;
    if (_userData.isNotEmpty && _userData.any((e) => e.date == date)) {
      emit(CalendarData(
        eventList: oldState.eventList,
        selectedDaysGoals: _userData.firstWhere((e) => e.date == date),
        selectedDay: date,
      ));
      return;
    }

    emit(CalendarData(
      eventList: oldState.eventList,
      selectedDaysGoals: null,
      selectedDay: date,
    ));
  }
}
