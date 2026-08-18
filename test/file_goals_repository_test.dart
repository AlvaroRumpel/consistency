import 'dart:convert';
import 'dart:io';

import 'package:consistency/data/file_goals_repository.dart';
import 'package:consistency/models/app_data.dart';
import 'package:consistency/models/goal.dart';
import 'package:flutter_test/flutter_test.dart';

AppData sample(String name) => AppData(
      goals: [
        Goal(
          id: 'g1',
          name: name,
          type: GoalType.check,
          createdAt: DateTime(2026, 8, 1),
          archivedAt: null,
          updatedAt: DateTime.utc(2026, 8, 1),
        ),
      ],
      entries: const [],
    );

void main() {
  late Directory dir;
  late FileGoalsRepository repo;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('consistency_repo_');
    repo = FileGoalsRepository(dir);
  });
  tearDown(() => dir.deleteSync(recursive: true));

  test('empty dir → not exists, load gives empty data', () async {
    expect(await repo.exists(), isFalse);
    expect((await repo.load()).goals, isEmpty);
  });

  test('save then load round-trips and keeps a .bak of the previous good file',
      () async {
    await repo.save(sample('Run'));
    await repo.save(sample('Sprint'));
    expect((await repo.load()).goals.single.name, 'Sprint');
    expect(File('${dir.path}/consistency.json.bak').existsSync(), isTrue);
    expect(File('${dir.path}/consistency.json.tmp').existsSync(), isFalse);
  });

  test('corrupt main file falls back to .bak', () async {
    await repo.save(sample('Run'));
    await repo.save(sample('Sprint'));
    File('${dir.path}/consistency.json').writeAsStringSync('{not json');
    expect((await repo.load()).goals.single.name, 'Run');
  });

  test('main file with valid JSON but unknown enum value falls back to .bak',
      () async {
    await repo.save(sample('Run'));
    await repo.save(sample('Sprint'));
    File('${dir.path}/consistency.json').writeAsStringSync('''
{"schemaVersion":2,"goals":[{"id":"x","name":"n","type":"bogus","createdAt":"2026-08-01","archivedAt":null,"updatedAt":"2026-08-01T00:00:00.000Z"}],"entries":[]}
''');
    expect((await repo.load()).goals.single.name, 'Run');
  });

  test(
      'moveToUndo hides data; restoreFromUndo brings it back; save purges undo',
      () async {
    await repo.save(sample('Run'));
    await repo.moveToUndo();
    expect(await repo.exists(), isFalse);
    expect((await repo.load()).goals, isEmpty);

    expect(await repo.restoreFromUndo(), isTrue);
    expect((await repo.load()).goals.single.name, 'Run');

    await repo.moveToUndo();
    await repo.save(sample('Fresh'));
    expect(await repo.restoreFromUndo(), isFalse);
    expect((await repo.load()).goals.single.name, 'Fresh');
  });

  test('concurrent saves are serialized, not interleaved', () async {
    await Future.wait([
      repo.save(sample('A')),
      repo.save(sample('B')),
      repo.save(sample('C')),
    ]);

    expect((await repo.load()).goals.single.name, 'C');
    expect(await repo.exists(), isTrue);
  });

  test('a failed write does not poison later saves', () async {
    // consistency.json.tmp as a directory makes the tmp write throw.
    final blocker = Directory('${dir.path}/consistency.json.tmp');
    await blocker.create(recursive: true);

    await expectLater(repo.save(sample('A')), throwsA(anything));

    await blocker.delete();
    await repo.save(sample('B'));
    expect((await repo.load()).goals.single.name, 'B');
  });

  test('readRaw on empty dir gives null', () async {
    expect(await repo.readRaw(), isNull);
  });

  test('readRaw after a save decodes to the saved data', () async {
    await repo.save(sample('Run'));
    final raw = await repo.readRaw();
    expect(raw, isNotNull);
    expect(AppData.fromJson(jsonDecode(raw!)).goals.single.name, 'Run');
  });

  test('readRaw rescues a corrupt main file unaltered, even with a valid .bak',
      () async {
    await repo.save(sample('Run'));
    await repo.save(sample('Sprint'));
    File('${dir.path}/consistency.json').writeAsStringSync('{not json');
    expect(await repo.readRaw(), '{not json');
  });

  test('readRaw falls back to .bak when main is missing', () async {
    await repo.save(sample('Run'));
    await repo.save(sample('Sprint'));
    File('${dir.path}/consistency.json').deleteSync();
    final raw = await repo.readRaw();
    expect(raw, isNotNull);
    expect(AppData.fromJson(jsonDecode(raw!)).goals.single.name, 'Run');
  });

  test('readRaw gives null after moveToUndo', () async {
    await repo.save(sample('Run'));
    await repo.moveToUndo();
    expect(await repo.readRaw(), isNull);
  });
}
