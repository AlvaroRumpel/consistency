import 'package:consistency/data/in_memory_goals_repository.dart';
import 'package:consistency/models/app_data.dart';
import 'package:consistency/models/goal.dart';
import 'package:consistency/state/app_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late InMemoryGoalsRepository repo;
  late AppStore store;
  final today = DateTime(2026, 8, 16);
  var n = 0;

  setUp(() async {
    repo = InMemoryGoalsRepository();
    n = 0;
    store = AppStore(repo,
        newId: () => 'g${n++}', now: () => DateTime.utc(2026, 8, 16, 12));
    await store.load();
  });

  test('load on empty repo → loaded, empty', () {
    expect(store.loaded, isTrue);
    expect(store.data.goals, isEmpty);
  });

  test('addGoal persists and notifies', () async {
    var notified = 0;
    store.addListener(() => notified++);
    final g = await store.addGoal('Run', GoalType.check, createdAt: today);
    expect(g.id, 'g0');
    expect(store.data.goals.single.name, 'Run');
    expect(repo.stored!.goals.single.id, 'g0');
    expect(repo.saves, 1);
    expect(notified, 1);
  });

  test('rename/type/archive/restore', () async {
    final g = await store.addGoal('Run', GoalType.check, createdAt: today);
    await store.renameGoal(g.id, 'Sprint');
    await store.setGoalType(g.id, GoalType.percent);
    expect(store.data.goalById(g.id)!.name, 'Sprint');
    expect(store.data.goalById(g.id)!.type, GoalType.percent);
    await store.archiveGoal(g.id, on: DateTime(2026, 8, 20));
    expect(store.data.goalById(g.id)!.archivedAt, DateTime(2026, 8, 20));
    expect(store.data.activeGoalsOn(DateTime(2026, 8, 20)), isEmpty);
    expect(store.data.activeGoalsOn(DateTime(2026, 8, 19)).length, 1);
    await store.restoreGoal(g.id);
    expect(store.data.goalById(g.id)!.archivedAt, isNull);
  });

  test('saveDay upserts and drops values for goals not active that day',
      () async {
    final a = await store.addGoal('A', GoalType.percent, createdAt: today);
    final b = await store.addGoal('B', GoalType.check,
        createdAt: today.add(const Duration(days: 1)));
    await store.saveDay(today, {a.id: 50, b.id: 100, 'ghost': 1});
    expect(store.data.entryOn(today)!.values, {a.id: 50.0});
    await store.saveDay(today, {a.id: 75});
    expect(store.data.entries.length, 1);
    expect(store.data.entryOn(today)!.values, {a.id: 75.0});
    expect(store.data.entryOn(today)!.updatedAt, DateTime.utc(2026, 8, 16, 12));
  });

  test(
      'clearAll hides everything; undoClear restores; a save after clear makes undo impossible',
      () async {
    await store.addGoal('Run', GoalType.check, createdAt: today);
    await store.clearAll();
    expect(store.data.goals, isEmpty);
    expect(await store.undoClear(), isTrue);
    expect(store.data.goals.single.name, 'Run');

    await store.clearAll();
    await store.addGoal('Fresh', GoalType.check, createdAt: today);
    expect(await store.undoClear(), isFalse);
    expect(store.data.goals.single.name, 'Fresh');
  });

  test('replaceAll swaps the whole dataset', () async {
    await store.replaceAll(AppData(goals: const [], entries: const []));
    expect(repo.saves, 1);
  });

  test('load failure is exposed, not thrown', () async {
    final bad = _ThrowingRepo();
    final s = AppStore(bad);
    await s.load();
    expect(s.loaded, isFalse);
    expect(s.loadError, isNotNull);
  });
}

class _ThrowingRepo extends InMemoryGoalsRepository {
  @override
  Future<AppData> load() async => throw const FormatException('boom');
}
