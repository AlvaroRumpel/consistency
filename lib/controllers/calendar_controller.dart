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
        final eventListTemp = EventList<Event>(events: {});

        for (final item in _userData) {
          if (item.goals.isEmpty) continue;

          final totalPercent = item.goals
              .map((goal) => goal.percentCompleted)
              .reduce((a, b) => a + b);
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
    final current = state;
    if (current is! CalendarData) return;

    emit(
      CalendarData(
        eventList: current.eventList,
        selectedDaysGoals: _userData.cast<DateGoalModel?>().firstWhere(
              (e) => e?.date == date,
              orElse: () => null,
            ),
        selectedDay: date,
      ),
    );
  }
}
