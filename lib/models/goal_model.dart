import 'dart:convert';

import 'package:consistency/enums/type_enum.dart';

class GoalModel {
  String name;
  double percentCompleted;
  TypeEnum type;

  GoalModel({
    required this.name,
    required this.percentCompleted,
    required this.type,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'percentCompleted': percentCompleted,
      'type': type.index,
    };
  }

  factory GoalModel.fromMap(Map<String, dynamic> map) {
    return GoalModel(
      name: map['name'] ?? '',
      percentCompleted: map['percentCompleted']?.toDouble() ?? 0.0,
      type: TypeEnum.values[map['type']],
    );
  }

  String toJson() => json.encode(toMap());

  factory GoalModel.fromJson(String source) =>
      GoalModel.fromMap(json.decode(source));

  GoalModel copyWith({
    String? name,
    double? percentCompleted,
    TypeEnum? type,
  }) {
    return GoalModel(
      name: name ?? this.name,
      percentCompleted: percentCompleted ?? this.percentCompleted,
      type: type ?? this.type,
    );
  }
}
