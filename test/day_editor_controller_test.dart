import 'package:consistency/controllers/day_editor_controller.dart';
import 'package:consistency/data/in_memory_goals_repository.dart';
import 'package:consistency/data/settings_repository.dart';
import 'package:consistency/models/app_data.dart';
import 'package:consistency/models/day_entry.dart';
import 'package:consistency/models/goal.dart';
import 'package:consistency/state/app_store.dart';
import 'package:consistency/state/settings_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  DateTime d(int day) => DateTime(2026, 8, day);
  final u = DateTime.utc(2026);
  var now = DateTime(2026, 8, 10, 9);

  Future<(AppStore, SettingsStore, InMemoryGoalsRepository)> boot(
      {List<DayEntry> entries = const [], bool failSaves = false}) async {
    SharedPreferences.setMockInitialValues({'nickname': 'Alvaro'});
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
    final data = AppData(goals: [run, read], entries: entries);
    final repo =
        failSaves ? SaveThrowsRepository(data) : InMemoryGoalsRepository(data);
    final store = AppStore(repo);
    await store.load();
    return (store, SettingsStore(SettingsRepository(prefs)), repo);
  }

  DayView view(DayEditorController c) => (c.state as DayEditorReady).view;

  setUp(() => now = DateTime(2026, 8, 10, 9));

  test(
      'today: editable, unsaved, dirty=false until touched, average of on-screen values',
      () async {
    final (s, st, _) = await boot();
    final c = DayEditorController(s, st, now: () => now);
    final v = view(c);
    expect(v.editable, isTrue);
    expect(v.saved, isFalse);
    expect(v.dirty, isFalse);
    expect(v.average, 0);
    expect(v.goals.map((g) => g.goalId), ['run', 'read']);
    expect(v.nickname, 'Alvaro');
  });

  test(
      'setValue/toggle mark dirty and update the live average; save upserts and clears dirty',
      () async {
    final (s, st, repo) = await boot();
    final c = DayEditorController(s, st, now: () => now);
    c.toggle('run');
    c.setValue('read', 50);
    expect(view(c).dirty, isTrue);
    expect(view(c).average, 75);
    await c.save();
    expect(view(c).saved, isTrue);
    expect(view(c).dirty, isFalse);
    expect(s.data.entryOn(d(10))!.values, {'run': 100.0, 'read': 50.0});
    c.setValue('read', 100);
    expect(view(c).dirty, isTrue);
    await c.save();
    expect(s.data.entries.length, 1);
    expect(repo.saves, 2);
  });

  test('double tap saves once', () async {
    final (s, st, repo) = await boot();
    final c = DayEditorController(s, st, now: () => now);
    c.toggle('run');
    await Future.wait([c.save(), c.save()]);
    expect(repo.saves, 1);
    expect(s.data.entries.length, 1);
  });

  test('a store change keeps in-progress values by goal id', () async {
    final (s, st, _) = await boot();
    final c = DayEditorController(s, st, now: () => now);
    c.setValue('read', 75);
    await s.addGoal('B', GoalType.check, createdAt: d(10));
    expect(view(c).goals.length, 3);
    expect(view(c).goals.firstWhere((g) => g.goalId == 'read').value, 75);
  });

  test('fixed past day inside the window is editable and saves to that day',
      () async {
    final (s, st, _) = await boot();
    final c = DayEditorController(s, st, day: d(5), now: () => now);
    expect(view(c).editable, isTrue);
    c.toggle('run');
    await c.save();
    expect(s.data.entryOn(d(5))!.values['run'], 100);
    expect(s.data.entryOn(d(10)), isNull);
  });

  test('day older than 7 days is read-only; setValue/save are no-ops',
      () async {
    final (s, st, repo) = await boot();
    final c =
        DayEditorController(s, st, day: d(2), now: () => now); // 8 days back
    expect(view(c).editable, isFalse);
    c.toggle('run');
    await c.save();
    expect(view(c).goals.first.value, 0);
    expect(repo.saves, 0);
    expect(DayEditorController(s, st, day: d(3), now: () => now).state,
        isA<DayEditorReady>());
    expect(view(DayEditorController(s, st, day: d(3), now: () => now)).editable,
        isTrue); // exactly 7 back
  });

  test('day rollover on reload', () async {
    final (s, st, _) = await boot();
    now = DateTime(2026, 8, 10, 23, 59);
    final c = DayEditorController(s, st, now: () => now);
    c.toggle('run');
    c.setValue('read', 100);
    await c.save();
    expect(view(c).streak, 1);
    now = DateTime(2026, 8, 11, 0, 1);
    c.reload();
    expect(view(c).day, d(11));
    expect(view(c).saved, isFalse);
    expect(view(c).streak, 1);
    expect(view(c).average, 0);
  });

  test(
      'archived goals disappear from today but a fixed past day still shows them',
      () async {
    final (s, st, _) = await boot(entries: [
      DayEntry(date: d(5), values: {'run': 100}, updatedAt: u)
    ]);
    await s.archiveGoal('run', on: d(10));
    expect(
        view(DayEditorController(s, st, now: () => now))
            .goals
            .map((g) => g.goalId),
        ['read']);
    expect(
        view(DayEditorController(s, st, day: d(5), now: () => now))
            .goals
            .map((g) => g.goalId),
        ['run', 'read']);
  });

  test('a failed save keeps the day dirty and shows what the user typed',
      () async {
    final (s, st, _) = await boot(failSaves: true);
    final c = DayEditorController(s, st, now: () => now);
    c.toggle('run');
    await c.save();
    expect(view(c).saveFailed, isTrue);
    expect(view(c).dirty, isTrue);
    expect(view(c).goals.firstWhere((g) => g.goalId == 'run').value, 100);
  });

  test('a disposed controller ignores a late reload', () async {
    final (s, st, _) = await boot();
    final c = DayEditorController(s, st, now: () => now);
    c.onDispose();
    expect(c.reload, returnsNormally);
  });

  test('load error surfaces', () async {
    final (_, st, _) = await boot();
    final bad = AppStore(_Throwing());
    await bad.load();
    expect(DayEditorController(bad, st, now: () => now).state,
        isA<DayEditorError>());
  });
}

class _Throwing extends InMemoryGoalsRepository {
  @override
  Future<AppData> load() async => throw const FormatException('boom');
}
