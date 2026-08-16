import 'dart:convert';
import 'dart:io';

import 'package:consistency/data/in_memory_goals_repository.dart';
import 'package:consistency/data/legacy_migration.dart';
import 'package:consistency/models/date_key.dart';
import 'package:consistency/models/goal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final fixture = File('test/fixtures/v1_userdata.json').readAsStringSync();
  final d1 = dateOnly(DateTime.fromMillisecondsSinceEpoch(1754017200000));
  final d2 = dateOnly(DateTime.fromMillisecondsSinceEpoch(1754103600000));
  final d3 = dateOnly(DateTime.fromMillisecondsSinceEpoch(1754276400000));

  test(
      'convert: one Goal per distinct name, entries keyed by id, stale goals archived',
      () {
    var n = 0;
    final data = LegacyMigration.convert(fixture, newId: () => 'id${n++}');

    expect(data.goals.map((g) => g.name).toList(), ['Run', 'Read', 'Sprint']);
    final run = data.goals[0], read = data.goals[1], sprint = data.goals[2];
    expect(run.type, GoalType.percent);
    expect(run.createdAt, d1);
    expect(sprint.createdAt, d3);
    // Run does not appear on the last day → archived the day after its last use.
    expect(run.archivedAt, d2.add(const Duration(days: 1)));
    expect(read.archivedAt, isNull);
    expect(sprint.archivedAt, isNull);

    expect(data.entries.length, 3);
    expect(data.entries[0].date, d1);
    expect(data.entries[0].values, {run.id: 50.0, read.id: 100.0});
    expect(data.entries[2].values, {sprint.id: 100.0, read.id: 0.0});
  });

  test('runIfNeeded migrates once and cleans the old keys', () async {
    SharedPreferences.setMockInitialValues({
      'userData': fixture,
      'beforeDelete': '{"nickname":"x"}',
      'nickname': 'Alvaro',
    });
    final prefs = await SharedPreferences.getInstance();
    final repo = InMemoryGoalsRepository();

    expect(await LegacyMigration.runIfNeeded(prefs, repo), isTrue);
    expect(repo.stored!.goals.length, 3);
    expect(prefs.containsKey('userData'), isFalse);
    expect(prefs.containsKey('beforeDelete'), isFalse);
    expect(prefs.getString('nickname'), 'Alvaro');

    // Second run: file exists → no-op.
    expect(await LegacyMigration.runIfNeeded(prefs, repo), isFalse);
  });

  test('runIfNeeded is a no-op on a fresh install', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    expect(await LegacyMigration.runIfNeeded(prefs, InMemoryGoalsRepository()),
        isFalse);
  });

  test('convert merges two same-day items, later values win', () {
    const d = 1754017200000; // same epoch day for both items
    final blob = jsonEncode([
      jsonEncode({
        'date': d,
        'goals': [
          {'name': 'Run', 'percentCompleted': 25.0},
        ],
      }),
      jsonEncode({
        'date': d,
        'goals': [
          {'name': 'Run', 'percentCompleted': 75.0},
          {'name': 'Read', 'percentCompleted': 100.0},
        ],
      }),
    ]);

    final data = LegacyMigration.convert(blob, newId: () => 'x');

    expect(data.entries.length, 1);
    final run = data.goals.firstWhere((g) => g.name == 'Run');
    final read = data.goals.firstWhere((g) => g.name == 'Read');
    expect(data.entries[0].values, {run.id: 75.0, read.id: 100.0});
    expect(run.archivedAt, isNull);
    expect(read.archivedAt, isNull);
  });

  test('runIfNeeded returns false and keeps the blob on malformed JSON',
      () async {
    SharedPreferences.setMockInitialValues({'userData': '{not json'});
    final prefs = await SharedPreferences.getInstance();
    final repo = InMemoryGoalsRepository();

    expect(await LegacyMigration.runIfNeeded(prefs, repo), isFalse);
    expect(prefs.getString('userData'), '{not json');
    expect(repo.stored, isNull);
  });
}
