import 'dart:convert';

import 'package:consistency/models/date_goal_model.dart';
import 'package:flutter/material.dart';

class EventModel {
  List<DateTime> dates;
  List<Color> colors;
  List<double>? percentCompleted;
  List<DateGoalModel>? goals;

  EventModel({
    required this.dates,
    required this.colors,
    this.percentCompleted,
    this.goals,
  });

  Map<String, dynamic> toMap() {
    return {
      'dates': dates.map((x) => x.millisecondsSinceEpoch).toList(),
      'colors': colors.map((x) => x.toString()).toList(),
      'percentCompleted': percentCompleted,
      'goals': goals?.map((x) => x.toMap()).toList(),
    };
  }

  factory EventModel.fromMap(Map<String, dynamic> map) {
    return EventModel(
      dates: List<DateTime>.from(
        map['dates']?.map(
          (x) => DateTime.fromMillisecondsSinceEpoch(x),
        ),
      ),
      colors: List<Color>.from(
        map['colors']?.map(
          (x) => Color(
            int.parse(x.split('(0x')[1].split(')')[0], radix: 16),
          ),
        ),
      ),
      percentCompleted: map['percentCompleted'] != null
          ? List<double>.from(map['percentCompleted'])
          : null,
      goals: map['goals'] != null
          ? List<DateGoalModel>.from(
              map['goals'].map(
                (x) => DateGoalModel.fromMap(x),
              ),
            )
          : null,
    );
  }

  String toJson() => json.encode(toMap());

  factory EventModel.fromJson(String source) =>
      EventModel.fromMap(json.decode(source));
}
