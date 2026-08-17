import 'dart:convert';

import 'package:consistency/models/app_data.dart';
import 'package:consistency/models/date_key.dart';
import 'package:consistency/models/day_entry.dart';
import 'package:consistency/models/goal.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('dateKey round-trips a local calendar day', () {
    final d = DateTime(2026, 8, 3, 23, 15);
    expect(dateKey(d), '2026-08-03');
    expect(parseDateKey('2026-08-03'), DateTime(2026, 8, 3));
    expect(dateOnly(d), DateTime(2026, 8, 3));
  });

  test('Goal.isActiveOn honours createdAt and archivedAt as calendar days', () {
    final g = Goal(
      id: 'a',
      name: 'Run',
      type: GoalType.check,
      createdAt: DateTime(2026, 8, 10),
      archivedAt: DateTime(2026, 8, 15),
      updatedAt: DateTime.utc(2026, 8, 10),
    );
    expect(g.isActiveOn(DateTime(2026, 8, 9)), isFalse);
    expect(g.isActiveOn(DateTime(2026, 8, 10)), isTrue);
    expect(g.isActiveOn(DateTime(2026, 8, 14, 23)), isTrue);
    expect(g.isActiveOn(DateTime(2026, 8, 15)), isFalse);
    expect(
        g.copyWith(archivedAt: null).isActiveOn(DateTime(2027, 1, 1)), isTrue);
  });

  test('AppData JSON round-trip keeps ids, types, values and order', () {
    final data = AppData(
      goals: [
        Goal(
          id: 'g1',
          name: 'Run',
          type: GoalType.check,
          createdAt: DateTime(2026, 8, 1),
          archivedAt: null,
          updatedAt: DateTime.utc(2026, 8, 1, 12),
        ),
        Goal(
          id: 'g2',
          name: 'Read',
          type: GoalType.percent,
          createdAt: DateTime(2026, 8, 2),
          archivedAt: DateTime(2026, 8, 5),
          updatedAt: DateTime.utc(2026, 8, 5, 8),
        ),
      ],
      entries: [
        DayEntry(
          date: DateTime(2026, 8, 3),
          values: {'g1': 100, 'g2': 25},
          updatedAt: DateTime.utc(2026, 8, 3, 20),
        ),
        DayEntry(
          date: DateTime(2026, 8, 2),
          values: {'g1': 0},
          updatedAt: DateTime.utc(2026, 8, 2, 20),
        ),
      ],
    );
    final json = jsonDecode(jsonEncode(data.toJson())) as Map<String, dynamic>;
    expect(json['schemaVersion'], 2);
    expect(json['entries'][0]['date'], '2026-08-02'); // sorted on construction
    expect(json['goals'][1]['type'], 'percent');
    expect(json['goals'][1]['archivedAt'], '2026-08-05');

    final back = AppData.fromJson(json);
    expect(back.goals.length, 2);
    expect(back.goalById('g2')!.type, GoalType.percent);
    expect(back.goalById('g2')!.archivedAt, DateTime(2026, 8, 5));
    expect(
        back.entries.map((e) => dateKey(e.date)), ['2026-08-02', '2026-08-03']);
    expect(back.entryOn(DateTime(2026, 8, 3, 9))!.values,
        {'g1': 100.0, 'g2': 25.0});
    expect(back.activeGoalsOn(DateTime(2026, 8, 3)).map((g) => g.id),
        ['g1', 'g2']);
    expect(back.activeGoalsOn(DateTime(2026, 8, 6)).map((g) => g.id), ['g1']);
    expect(back.entries.first.updatedAt.isUtc, isTrue);
  });

  test('AppData dedupes entries by date, last one wins', () {
    final data = AppData(
      goals: const [],
      entries: [
        DayEntry(
          date: DateTime(2026, 8, 3),
          values: {'g1': 10},
          updatedAt: DateTime.utc(2026, 8, 3, 8),
        ),
        DayEntry(
          date: DateTime(2026, 8, 3),
          values: {'g1': 90},
          updatedAt: DateTime.utc(2026, 8, 3, 20),
        ),
      ],
    );
    expect(data.entries.length, 1);
    expect(data.entries.single.values, {'g1': 90.0});
  });

  test('AppData.fromJson rejects unknown schema versions', () {
    expect(
        () =>
            AppData.fromJson({'schemaVersion': 99, 'goals': [], 'entries': []}),
        throwsFormatException);
  });
}
