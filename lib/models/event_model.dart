import 'dart:convert';

import 'package:flutter/material.dart';

class EventModel {
  List<DateTime> dates;
  List<Color> colors;
  List<double> percentCompleted;

  EventModel({
    required this.dates,
    required this.colors,
    required this.percentCompleted,
  });

  Map<String, dynamic> toMap() {
    return {
      'dates': dates.map((x) => x.millisecondsSinceEpoch).toList(),
      'colors': colors.map((x) => x.toString()).toList(),
      'percentCompleted': percentCompleted,
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
      percentCompleted: List<double>.from(map['percentCompleted']),
    );
  }

  String toJson() => json.encode(toMap());

  factory EventModel.fromJson(String source) =>
      EventModel.fromMap(json.decode(source));
}
