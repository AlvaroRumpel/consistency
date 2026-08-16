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
}
