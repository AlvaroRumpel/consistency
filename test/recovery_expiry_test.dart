import 'package:consistency/configs/local_data.dart';
import 'package:consistency/models/date_goal_model.dart';
import 'package:consistency/models/goal_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a new save after clearAllData invalidates the undo snapshot', () async {
    SharedPreferences.setMockInitialValues({});
    final localData = await LocalData.i;
    await localData.saveNickname('Alvaro');
    await localData.saveUserData([
      DateGoalModel(
        date: DateTime(2026, 1, 1),
        goals: [GoalModel(name: 'Run', percentCompleted: 100)],
      ),
    ]);

    await localData.clearAllData();
    expect(await localData.searchUserData(), isNull);

    // User starts fresh: this write must make the old snapshot unrecoverable.
    await localData.saveUserData([
      DateGoalModel(
        date: DateTime(2026, 2, 2),
        goals: [GoalModel(name: 'Read', percentCompleted: 50)],
      ),
    ]);

    expect(await localData.undoRecoveryData(), isFalse);
    final data = await localData.searchUserData();
    expect(data!.single.goals.single.name, 'Read');
  });

  test('undo still works when nothing was written after the wipe', () async {
    final localData = await LocalData.i;
    await localData.saveNickname('Alvaro');
    await localData.saveUserData([
      DateGoalModel(
        date: DateTime(2026, 1, 1),
        goals: [GoalModel(name: 'Run', percentCompleted: 100)],
      ),
    ]);
    await localData.clearAllData();
    expect(await localData.undoRecoveryData(), isTrue);
    expect(await localData.searchNickname(), 'Alvaro');
    expect((await localData.searchUserData())!.single.goals.single.name, 'Run');
  });
}
