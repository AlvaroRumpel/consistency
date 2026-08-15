class GoalModel {
  String name;
  double percentCompleted;

  GoalModel({
    required this.name,
    required this.percentCompleted,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'percentCompleted': percentCompleted,
    };
  }

  factory GoalModel.fromMap(Map<String, dynamic> map) {
    return GoalModel(
      name: map['name'] ?? '',
      percentCompleted: map['percentCompleted']?.toDouble() ?? 0.0,
    );
  }

  GoalModel copyWith({
    String? name,
    double? percentCompleted,
  }) {
    return GoalModel(
      name: name ?? this.name,
      percentCompleted: percentCompleted ?? this.percentCompleted,
    );
  }
}
