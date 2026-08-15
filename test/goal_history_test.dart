import 'dart:convert';

import 'package:consistency/controllers/home_controller.dart';
import 'package:consistency/models/date_goal_model.dart';
import 'package:consistency/models/goal_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One saved day, in the on-disk shape: an array of JSON strings.
String seededUserData() {
  final yesterday = DateGoalModel(
    date: DateTime(2026, 1, 1),
    goals: [GoalModel(name: 'Run', percentCompleted: 50)],
  );
  return '[${jsonEncode(yesterday.toJson())}]';
}

/// Spins the microtask queue until the controller's async onInit has settled.
Future<void> settle(HomeController controller) async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(Duration.zero);
    if (controller.state is HomeData) return;
  }
  fail('controller never reached HomeData; state was ${controller.state}');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'nickname': 'Alvaro',
      'userData': seededUserData(),
    });
  });

  test('editing today does not rewrite the saved day', () async {
    final controller = HomeController();
    await settle(controller);

    final live = (controller.state as HomeData).goals;
    expect(live.single.name, 'Run');

    // The user drags the slider and renames the goal.
    live.single.percentCompleted = 100;
    live.single.name = 'Sprint';

    final saved = controller.userData.single.goals.single;
    expect(saved.percentCompleted, 50, reason: 'history was rewritten');
    expect(saved.name, 'Run', reason: 'history was rewritten');

    controller.onDispose();
  });

  test('copyWith produces an independent instance', () {
    final original = GoalModel(name: 'Read', percentCompleted: 25);
    final copy = original.copyWith();

    copy.percentCompleted = 75;

    expect(original.percentCompleted, 25);
    expect(identical(original, copy), isFalse);
  });
}
