import 'package:flutter/material.dart';
import 'package:flutter_calendar_carousel/classes/event.dart';
import 'package:flutter_calendar_carousel/flutter_calendar_carousel.dart';

import '../configs/utilities.dart';
import '../state/app_store.dart';
import 'base_controller.dart';

sealed class CalendarState {}

class CalendarLoading extends CalendarState {}

class CalendarData extends CalendarState {
  final EventList<Event> eventList;
  final DateTime selectedDay;

  CalendarData({required this.eventList, required this.selectedDay});
}

class CalendarError extends CalendarState {
  final String message;

  CalendarError({required this.message});
}

class CalendarController extends BaseController<CalendarState> {
  final AppStore store;

  CalendarController(this.store, super.initialState);

  @override
  void onInit() {
    store.addListener(reload);
    reload();
  }

  void reload() {
    final error = store.loadError;
    if (error != null) {
      emit(CalendarError(message: error.toString()));
      return;
    }
    if (!store.loaded) {
      emit(CalendarLoading());
      return;
    }

    final eventList = EventList<Event>(events: {});
    for (final entry in store.data.entries) {
      final active = store.data.activeGoalsOn(entry.date);
      if (active.isEmpty) continue;

      final avgPercent = active
              .map((goal) => entry.values[goal.id] ?? 0)
              .reduce((a, b) => a + b) /
          active.length;

      eventList.add(
        entry.date,
        Event(
          date: entry.date,
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

    final old = state;
    final selectedDay = old is CalendarData ? old.selectedDay : DateTime.now();

    emit(CalendarData(eventList: eventList, selectedDay: selectedDay));
  }

  void selectDay(DateTime date) {
    final current = state;
    if (current is! CalendarData) return;

    emit(CalendarData(eventList: current.eventList, selectedDay: date));
  }

  @override
  void onDispose() {
    store.removeListener(reload);
    super.onDispose();
  }
}
