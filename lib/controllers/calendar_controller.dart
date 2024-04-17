import 'package:consistency/configs/local_data.dart';
import 'package:consistency/controllers/base_controller.dart';
import 'package:consistency/models/date_goal_model.dart';
import 'package:consistency/models/event_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_calendar_carousel/classes/event.dart';
import 'package:flutter_calendar_carousel/flutter_calendar_carousel.dart';

class CalendarController extends BaseController {
  late LocalData localData;
  EventModel? userData;
  ValueNotifier<EventList<Event>> eventList =
      ValueNotifier(EventList(events: {}));
  ValueNotifier<DateGoalModel?> selectedDay = ValueNotifier(null);

  @override
  void onDispose() {
    // TODO: implement onDispose
  }

  @override
  void onInit() async {
    localData = await LocalData.i;
    userData = await localData.searchUserData();
    treatData();
  }

  void treatData() {
    EventList<Event> eventListTemp = EventList(events: {});
    if (userData != null) {
      for (var i = 0; i < userData!.dates.length; i++) {
        eventListTemp.add(
          userData!.dates[i],
          Event(
            date: userData!.dates[i],
            dot: Container(
              decoration: BoxDecoration(
                shape: BoxShape.rectangle,
                color: userData!.colors[i],
                borderRadius: BorderRadius.circular(10),
              ),
              height: 2.0,
              width: 16.0,
            ),
          ),
        );
      }
      eventList.value = eventListTemp;
    }
  }

  void selectDay(DateTime date) {
    if (userData != null &&
        userData!.goals != null &&
        userData!.goals!.any((element) => element.date == date)) {
      selectedDay.value =
          userData!.goals!.firstWhere((element) => element.date == date);
      return;
    }

    selectedDay.value = null;
  }
}
