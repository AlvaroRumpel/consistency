import 'dart:convert';

import 'goal_model.dart';

class DateGoalModel {
  DateTime date;
  List<GoalModel> goals;
  DateGoalModel({
    required this.date,
    required this.goals,
  });

  Map<String, dynamic> toMap() {
    return {
      'date': date.millisecondsSinceEpoch,
      'goals': goals.map((x) => x.toMap()).toList(),
    };
  }

  factory DateGoalModel.fromMap(Map<String, dynamic> map) {
    return DateGoalModel(
      date: DateTime.fromMillisecondsSinceEpoch(map['date']),
      goals:
          List<GoalModel>.from(map['goals']?.map((x) => GoalModel.fromMap(x))),
    );
  }

  String toJson() => json.encode(toMap());

  factory DateGoalModel.fromJson(String source) =>
      DateGoalModel.fromMap(json.decode(source));
}
