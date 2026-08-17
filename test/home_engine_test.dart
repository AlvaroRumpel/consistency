import 'package:consistency/controllers/home_controller.dart';
import 'package:consistency/data/in_memory_goals_repository.dart';
import 'package:consistency/data/settings_repository.dart';
import 'package:consistency/models/app_data.dart';
import 'package:consistency/models/day_entry.dart';
import 'package:consistency/models/goal.dart';
import 'package:consistency/state/app_store.dart';
import 'package:consistency/state/settings_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  DateTime d(int day) => DateTime(2026, 8, day);
  final u = DateTime.utc(2026);

  Future<(AppStore, SettingsStore, HomeController)> boot(
      {int threshold = 50}) async {
    SharedPreferences.setMockInitialValues({'threshold': threshold});
    final prefs = await SharedPreferences.getInstance();
    final run = Goal(
        id: 'run',
        name: 'Run',
        type: GoalType.check,
        createdAt: d(1),
        archivedAt: null,
        updatedAt: u);
    final read = Goal(
        id: 'read',
        name: 'Read',
        type: GoalType.percent,
        createdAt: d(1),
        archivedAt: null,
        updatedAt: u);
    final store = AppStore(InMemoryGoalsRepository(AppData(goals: [
      run,
      read
    ], entries: [
      DayEntry(date: d(8), values: {'run': 100, 'read': 50}, updatedAt: u),
      DayEntry(date: d(9), values: {'run': 100, 'read': 25}, updatedAt: u),
    ])));
    await store.load();
    final settings = SettingsStore(SettingsRepository(prefs));
    final c = HomeController(store, settings,
        now: () => DateTime(2026, 8, 10, 9, 30));
    return (store, settings, c);
  }

  test(
      'HomeData carries global streak, best, per-goal streaks and today average',
      () async {
    final (_, _, c) = await boot();
    final s = c.state as HomeData;
    expect(s.streak, 2); // 8: avg 75, 9: avg 62.5 → both ≥ 50; today untouched
    expect(s.best, 2);
    expect(s.goalStreaks['run'], 2);
    expect(s.goalStreaks['read'], 0); // yesterday (9): 25 < 50 → not done
    expect(s.todayAverage, isNull); // no entry today
  });

  test('threshold change recomputes', () async {
    final (_, settings, c) = await boot();
    await settings.setThreshold(70);
    final s = c.state as HomeData;
    expect(
        s.streak, 0); // yesterday (9) avg 62.5 < 70 breaks; today has no entry
    expect(s.best, 1); // day 8 alone (avg 75)
  });

  test('saving today updates streak and todayAverage', () async {
    final (_, _, c) = await boot();
    for (final g in (c.state as HomeData).goals) {
      g.percentCompleted = 100;
    }
    await c.saveData();
    final s = c.state as HomeData;
    expect(s.streak, 3);
    expect(s.todayAverage, 100);
    expect(s.hasMarkedToday, isTrue);
  });
}
