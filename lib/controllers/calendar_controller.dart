import 'package:consistency/configs/local_data.dart';
import 'package:consistency/controllers/base_controller.dart';
import 'package:consistency/models/event_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_calendar_carousel/classes/event.dart';
import 'package:flutter_calendar_carousel/flutter_calendar_carousel.dart';

class CalendarController extends BaseController {
  late LocalData localData;
  EventModel? userData;
  ValueNotifier<EventList<Event>> eventList =
      ValueNotifier(EventList(events: {}));

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
                shape: BoxShape.circle,
                color: userData!.colors[i],
              ),
              height: 8.0,
              width: 8.0,
            ),
          ),
        );
      }
      eventList.value = eventListTemp;
    }
  }
}
