/// View model for the goal rows on Home and the calendar panel. The sliders
/// mutate [percentCompleted] in place; [goalId] ties a row back to the store.
class GoalModel {
  final String goalId;
  String name;
  double percentCompleted;

  GoalModel({
    required this.goalId,
    required this.name,
    required this.percentCompleted,
  });

  GoalModel copyWith({
    String? goalId,
    String? name,
    double? percentCompleted,
  }) {
    return GoalModel(
      goalId: goalId ?? this.goalId,
      name: name ?? this.name,
      percentCompleted: percentCompleted ?? this.percentCompleted,
    );
  }
}
