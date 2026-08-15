import 'dart:convert';

import 'package:consistency/configs/local_data.dart';
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

/// Like [settle], but waits specifically for the empty state: after a wipe,
/// state briefly passes through HomeLoading and lands on HomeDataEmpty, which
/// is itself a HomeData — so `settle`'s `is HomeData` check would return
/// immediately on the pre-wipe state instead of waiting for the reload.
Future<void> settleEmpty(HomeController controller) async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(Duration.zero);
    if (controller.state is HomeDataEmpty) return;
  }
  fail('controller never reached HomeDataEmpty; state was ${controller.state}');
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

  test('a double tap only marks today once', () async {
    final controller = HomeController();
    await settle(controller);

    // Two taps landing before the first save resolves.
    final first = controller.saveData();
    final second = controller.saveData();
    await Future.wait([first, second]);

    expect(controller.userData.length, 2, reason: 'today was marked twice');

    controller.onDispose();
  });

  test('a data wipe reloads Home and drops stale goal controllers', () async {
    final controller = HomeController();
    await settle(controller);

    expect(controller.goalsControllers.single.text, 'Run');

    // Settings' "Delete all data", from another live page.
    final localData = await LocalData.i;
    await localData.clearAllData();
    await settleEmpty(controller);

    expect(controller.state, isA<HomeDataEmpty>());
    expect(controller.goalsControllers, isEmpty,
        reason: 'orphan controller survived the reload');

    // The user-visible symptom: a new goal must not inherit the old name.
    controller.addNewGoal();
    final goals = (controller.state as HomeData).goals;
    expect(goals.single.name, 'New Goal');
    expect(goals.any((goal) => goal.name == 'Run'), isFalse);

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
