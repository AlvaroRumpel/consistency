import 'package:consistency/engine/consistency_engine.dart';
import 'package:consistency/models/app_data.dart';
import 'package:consistency/models/day_entry.dart';
import 'package:consistency/models/goal.dart';
import 'package:flutter_test/flutter_test.dart';

final _u = DateTime.utc(2026, 1, 1);
DateTime d(int day) => DateTime(2026, 8, day);
Goal goal(String id, GoalType t, {int created = 1, int? archived}) => Goal(
      id: id,
      name: id,
      type: t,
      createdAt: d(created),
      archivedAt: archived == null ? null : d(archived),
      updatedAt: _u,
    );
DayEntry entry(int day, Map<String, double> v) =>
    DayEntry(date: d(day), values: v, updatedAt: _u);
ConsistencyEngine eng(List<Goal> goals, List<DayEntry> entries,
        {int threshold = 50, int today = 10}) =>
    ConsistencyEngine(
      data: AppData(goals: goals, entries: entries),
      threshold: threshold,
      today: d(today),
    );

void main() {
  group('isGoalDone', () {
    final e = eng([], []);
    test('check needs 100', () {
      expect(e.isGoalDone(goal('c', GoalType.check), 99), isFalse);
      expect(e.isGoalDone(goal('c', GoalType.check), 100), isTrue);
    });
    test('percent uses threshold', () {
      expect(e.isGoalDone(goal('p', GoalType.percent), 49), isFalse);
      expect(e.isGoalDone(goal('p', GoalType.percent), 50), isTrue);
    });
  });

  group('dayAverage / isDayConsistent', () {
    final a = goal('a', GoalType.percent), b = goal('b', GoalType.check);
    test('null without entry or without active goals', () {
      expect(eng([a, b], []).dayAverage(d(5)), isNull);
      expect(
          eng([goal('x', GoalType.check, created: 8)], [entry(5, {})])
              .dayAverage(d(5)),
          isNull);
    });
    test('missing values count as 0; consistent at threshold', () {
      final e = eng([
        a,
        b
      ], [
        entry(5, {'a': 100})
      ]);
      expect(e.dayAverage(d(5)), 50);
      expect(e.isDayConsistent(d(5)), isTrue);
      expect(
          eng([
            a,
            b
          ], [
            entry(5, {'a': 75})
          ], threshold: 60)
              .isDayConsistent(d(5)),
          isFalse);
    });
    test('archived goals are excluded from the day they are archived on', () {
      final e = eng([
        a,
        goal('b', GoalType.check, archived: 5)
      ], [
        entry(5, {'a': 100})
      ]);
      expect(e.dayAverage(d(5)), 100);
    });
  });

  group('globalStreak (rule B)', () {
    final a = goal('a', GoalType.check);
    test('empty data → 0', () {
      expect(eng([], []).globalStreak(), 0);
      expect(eng([a], []).globalStreak(), 0);
    });
    test('only today consistent → 1; only today, not consistent → 0', () {
      expect(
          eng([
            a
          ], [
            entry(10, {'a': 100})
          ]).globalStreak(),
          1);
      expect(
          eng([
            a
          ], [
            entry(10, {'a': 0})
          ]).globalStreak(),
          0);
    });
    test(
        'yesterday..3 days consistent, today untouched → 3 (today does not break)',
        () {
      expect(
          eng([
            a
          ], [
            entry(7, {'a': 100}),
            entry(8, {'a': 100}),
            entry(9, {'a': 100})
          ]).globalStreak(),
          3);
    });
    test('gap yesterday breaks even if earlier days were consistent', () {
      expect(
          eng([
            a
          ], [
            entry(7, {'a': 100}),
            entry(8, {'a': 100}),
            entry(10, {'a': 100})
          ]).globalStreak(),
          1);
    });
    test('days before the first goal existed neither count nor break', () {
      final g = goal('g', GoalType.check, created: 8);
      expect(
          eng([
            g
          ], [
            entry(8, {'g': 100}),
            entry(9, {'g': 100})
          ]).globalStreak(),
          2);
    });
    test('a day with no active goal in the middle is skipped, not broken', () {
      // g1 active 1..5 (archived on 6), g2 active from 7 → day 6 has no goals.
      final g1 = goal('g1', GoalType.check, archived: 6),
          g2 = goal('g2', GoalType.check, created: 7);
      final e = eng([
        g1,
        g2
      ], [
        entry(4, {'g1': 100}),
        entry(5, {'g1': 100}),
        entry(7, {'g2': 100}),
        entry(8, {'g2': 100}),
        entry(9, {'g2': 100})
      ]);
      expect(e.globalStreak(), 5);
    });
    test('threshold 100 needs everything done', () {
      final p = goal('p', GoalType.percent);
      expect(
          eng([
            p
          ], [
            entry(9, {'p': 75})
          ], threshold: 100)
              .globalStreak(),
          0);
      expect(
          eng([
            p
          ], [
            entry(9, {'p': 100})
          ], threshold: 100)
              .globalStreak(),
          1);
    });
  });

  group('globalBest', () {
    final a = goal('a', GoalType.check);
    test('best run anywhere in history, including a run ending today', () {
      final e = eng([
        a
      ], [
        entry(1, {'a': 100}), entry(2, {'a': 100}), entry(3, {'a': 100}), // 3
        entry(5, {'a': 100}), // 1
        entry(9, {'a': 100}), entry(10, {'a': 100}), // 2 (current)
      ]);
      expect(e.globalBest(), 3);
      expect(e.globalStreak(), 2);
    });
    test('best is at least the current streak', () {
      expect(
          eng([
            a
          ], [
            entry(9, {'a': 100}),
            entry(10, {'a': 100})
          ]).globalBest(),
          2);
    });
  });

  group('per-goal streak / best / rate', () {
    final c = goal('c', GoalType.check), p = goal('p', GoalType.percent);
    final e = eng([
      c,
      p
    ], [
      entry(6, {'c': 100, 'p': 25}),
      entry(7, {'c': 100, 'p': 50}),
      entry(8, {'c': 0, 'p': 100}),
      entry(9, {'c': 100, 'p': 75}),
      // day 10 (today) untouched
    ]);
    test('goalStreak counts back from yesterday; today does not break', () {
      expect(e.goalStreak(c), 1); // 9 done, 8 not
      expect(e.goalStreak(p), 3); // 9,8,7 done (>=50), 6 not
    });
    test('goalBest', () {
      expect(e.goalBest(c), 2); // 6,7
      expect(e.goalBest(p), 3);
    });
    test('goalRate over the last 7 days (4..10): done / active days', () {
      expect(e.goalRate(c, 7), closeTo(3 / 7, 1e-9));
      expect(e.goalRate(p, 7), closeTo(3 / 7, 1e-9));
    });
    test('goalRate only counts days the goal was active', () {
      final late = goal('l', GoalType.check, created: 9);
      final e2 = eng([
        late
      ], [
        entry(9, {'l': 100})
      ]);
      expect(e2.goalRate(late, 7),
          closeTo(1 / 2, 1e-9)); // active on 9,10; done on 9
      expect(
          eng([goal('z', GoalType.check, created: 12)], [])
              .goalRate(goal('z', GoalType.check, created: 12), 7),
          0);
    });
    test('archived goal streak freezes at archive date', () {
      final g = goal('g', GoalType.check, archived: 9);
      final e3 = eng([
        g
      ], [
        entry(7, {'g': 100}),
        entry(8, {'g': 100})
      ]);
      expect(e3.goalStreak(g), 2);
    });
    test('archive date in the future is clamped to yesterday', () {
      final g = goal('g', GoalType.check, archived: 12); // today = 10
      final e4 = eng([
        g
      ], [
        entry(8, {'g': 100}),
        entry(9, {'g': 100})
      ]);
      expect(e4.goalStreak(g), 2);
    });
  });

  group('heatmap', () {
    test('one key per day up to today, null where no data', () {
      final a = goal('a', GoalType.check);
      final e = eng([
        a
      ], [
        entry(3, {'a': 100})
      ]);
      final m = e.heatmap(2026);
      expect(m.length, 222); // Jan 1 .. Aug 10 2026 inclusive
      expect(m[DateTime(2026, 8, 3)], 100);
      expect(m[DateTime(2026, 8, 4)], isNull);
      expect(m.containsKey(DateTime(2026, 8, 11)), isFalse);
      expect(e.heatmap(2025).length, 365);
      expect(e.heatmap(2027), isEmpty);
    });
  });
}
