import 'package:consistency/data/backup_codec.dart';
import 'package:consistency/models/app_data.dart';
import 'package:consistency/models/date_key.dart';
import 'package:consistency/models/day_entry.dart';
import 'package:consistency/models/goal.dart';
import 'package:flutter_test/flutter_test.dart';

DateTime d(int day) => DateTime(2026, 8, day);
Goal goal(String id, {String name = 'G', DateTime? updated, int created = 1}) =>
    Goal(
      id: id,
      name: name,
      type: GoalType.check,
      createdAt: d(created),
      archivedAt: null,
      updatedAt: updated ?? DateTime.utc(2026, 8, 1),
    );
DayEntry entry(int day, Map<String, double> v, {DateTime? updated}) => DayEntry(
    date: d(day), values: v, updatedAt: updated ?? DateTime.utc(2026, 8, day));

void main() {
  test('encode → decode round-trips', () {
    final data = AppData(goals: [
      goal('a')
    ], entries: [
      entry(3, {'a': 100})
    ]);
    final back = BackupCodec.decode(BackupCodec.encode(data));
    expect(back.goals.single.id, 'a');
    expect(back.entries.single.values, {'a': 100.0});
  });

  test('decode rejects junk, wrong schema and wrong shape', () {
    expect(() => BackupCodec.decode('{not json'), throwsFormatException);
    expect(
        () => BackupCodec.decode('{"schemaVersion":1,"goals":[],"entries":[]}'),
        throwsFormatException);
    expect(
        () => BackupCodec.decode('{"schemaVersion":2}'), throwsFormatException);
    expect(() => BackupCodec.decode('[]'), throwsFormatException);
  });

  test('summarize counts goals and days', () {
    final s = BackupCodec.summarize(AppData(
        goals: [goal('a'), goal('b')], entries: [entry(1, {}), entry(2, {})]));
    expect(s.goals, 2);
    expect(s.days, 2);
  });

  test('fileName uses the calendar day', () {
    expect(BackupCodec.fileName(DateTime(2026, 8, 7, 23)),
        'consistency-2026-08-07.json');
  });

  group('merge', () {
    test('adds unknown goals and keeps the newer version of known ones', () {
      final current = AppData(goals: [
        goal('a', name: 'old', updated: DateTime.utc(2026, 8, 1)),
        goal('b', name: 'mine'),
      ], entries: const []);
      final incoming = AppData(goals: [
        goal('a', name: 'new', updated: DateTime.utc(2026, 8, 5)),
        goal('c', name: 'theirs'),
      ], entries: const []);

      final m = BackupCodec.merge(current, incoming);
      expect(m.goals.map((g) => g.id).toSet(), {'a', 'b', 'c'});
      expect(m.goalById('a')!.name, 'new');
      expect(m.goalById('b')!.name, 'mine');
    });

    test('older incoming goal does not overwrite', () {
      final current = AppData(
          goals: [goal('a', name: 'mine', updated: DateTime.utc(2026, 8, 9))],
          entries: const []);
      final incoming = AppData(
          goals: [goal('a', name: 'theirs', updated: DateTime.utc(2026, 8, 2))],
          entries: const []);
      expect(BackupCodec.merge(current, incoming).goalById('a')!.name, 'mine');
    });

    test('entries merge by date, newest updatedAt wins the whole day', () {
      final current = AppData(goals: [
        goal('a')
      ], entries: [
        entry(3, {'a': 50}, updated: DateTime.utc(2026, 8, 3, 10)),
        entry(4, {'a': 100}),
      ]);
      final incoming = AppData(goals: [
        goal('a')
      ], entries: [
        entry(3, {'a': 100}, updated: DateTime.utc(2026, 8, 3, 20)),
        entry(5, {'a': 25}),
      ]);
      final m = BackupCodec.merge(current, incoming);
      expect(m.entries.map((e) => dateKey(e.date)),
          ['2026-08-03', '2026-08-04', '2026-08-05']);
      expect(m.entryOn(d(3))!.values['a'], 100);
      expect(m.entryOn(d(4))!.values['a'], 100);
      expect(m.entryOn(d(5))!.values['a'], 25);
    });

    test('merging with empty data is a no-op either way', () {
      final data = AppData(goals: [
        goal('a')
      ], entries: [
        entry(1, {'a': 100})
      ]);
      expect(BackupCodec.merge(data, AppData.empty).goals.length, 1);
      expect(BackupCodec.merge(AppData.empty, data).entries.length, 1);
    });
  });
}
