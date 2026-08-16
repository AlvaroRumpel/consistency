import 'package:consistency/controllers/home_controller.dart';
import 'package:consistency/data/in_memory_goals_repository.dart';
import 'package:consistency/data/settings_repository.dart';
import 'package:consistency/models/app_data.dart';
import 'package:consistency/models/date_key.dart';
import 'package:consistency/models/day_entry.dart';
import 'package:consistency/models/goal.dart';
import 'package:consistency/state/app_store.dart';
import 'package:consistency/state/settings_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final today = dateOnly(DateTime.now());
  final yesterday = today.subtract(const Duration(days: 1));

  late InMemoryGoalsRepository repo;
  late SettingsStore settings;

  Goal goal(String id, String name) => Goal(
        id: id,
        name: name,
        type: GoalType.percent,
        createdAt: yesterday,
        archivedAt: null,
        updatedAt: DateTime.utc(2026),
      );

  Future<(AppStore, HomeController)> boot({
    List<DayEntry> entries = const [],
    List<Goal>? goals,
  }) async {
    SharedPreferences.setMockInitialValues({'nickname': 'Alvaro'});
    final prefs = await SharedPreferences.getInstance();
    repo = InMemoryGoalsRepository(
      AppData(goals: goals ?? [goal('run', 'Run')], entries: entries),
    );
    final store = AppStore(repo);
    await store.load();
    settings = SettingsStore(SettingsRepository(prefs));
    final controller = HomeController(store, settings);
    return (store, controller);
  }

  test('editing today does not rewrite yesterday', () async {
    final (store, controller) = await boot(
      entries: [
        DayEntry(
          date: yesterday,
          values: {'run': 50},
          updatedAt: DateTime.utc(2026),
        ),
      ],
    );

    final live = (controller.state as HomeData).goals.single;
    expect(live.percentCompleted, 0); // today has no entry yet
    live.percentCompleted = 100;
    controller.goalsControllers.single.text = 'Sprint';

    await controller.saveData();

    expect(store.data.entryOn(yesterday)!.values['run'], 50);
    expect(store.data.entryOn(today)!.values['run'], 100);
    expect(store.data.goalById('run')!.name, 'Sprint');
    expect((controller.state as HomeData).hasMarkedToday, isTrue);

    controller.onDispose();
  });

  test('double tap saves once', () async {
    final (store, controller) = await boot();

    (controller.state as HomeData).goals.single.percentCompleted = 25;
    await Future.wait([controller.saveData(), controller.saveData()]);

    expect(store.data.entries.length, 1);
    // saveDay upserts, so the entry count alone would pass without the guard.
    expect(repo.saves, 1, reason: 'today was written twice');

    controller.onDispose();
  });

  test('every typed rename survives the save, not just the first', () async {
    // Each rename notifies the store, which rebuilds goalsControllers; reading
    // a field after that point would read the store's name back, not the
    // user's.
    final (store, controller) = await boot(
      goals: [goal('run', 'Run'), goal('read', 'Read')],
    );

    controller.goalsControllers[0].text = 'Sprint';
    controller.goalsControllers[1].text = 'Study';
    await controller.saveData();

    expect(store.data.goalById('run')!.name, 'Sprint');
    expect(store.data.goalById('read')!.name, 'Study');

    controller.onDispose();
  });

  test('adding a goal keeps the values already dragged today', () async {
    final (store, controller) = await boot();

    (controller.state as HomeData).goals.single.percentCompleted = 75;
    await store.addGoal('B', GoalType.check, createdAt: today);

    final goals = (controller.state as HomeData).goals;
    expect(goals.length, 2);
    expect(goals.first.percentCompleted, 75, reason: 'slider was zeroed');
    expect(goals.last.percentCompleted, 0);

    controller.onDispose();
  });

  test('a settings change does not reset the text fields', () async {
    final (_, controller) = await boot();

    final before = controller.goalsControllers.first;
    before.text = 'Sprint';
    await settings.setNickname('X');

    expect(identical(before, controller.goalsControllers.first), isTrue,
        reason: 'typing was thrown away by an unrelated reload');
    expect((controller.state as HomeData).nickname, 'X');

    controller.onDispose();
  });

  test('archive removes from today but keeps history', () async {
    final (store, controller) = await boot(
      entries: [
        DayEntry(
          date: yesterday,
          values: {'run': 50},
          updatedAt: DateTime.utc(2026),
        ),
      ],
    );

    await controller.removeGoal(0);

    expect(controller.state, isA<HomeDataEmpty>());
    expect(store.data.entryOn(yesterday)!.values['run'], 50);
    expect(store.data.goalById('run')!.isArchived, isTrue);

    controller.onDispose();
  });

  test('clearAll then undo restores the goal list', () async {
    final (store, controller) = await boot();

    await store.clearAll();
    expect(controller.state, isA<HomeDataEmpty>());
    expect(controller.goalsControllers, isEmpty,
        reason: 'orphan controller survived the wipe');

    await store.undoClear();
    expect((controller.state as HomeData).goals.single.name, 'Run');

    controller.onDispose();
  });
}
