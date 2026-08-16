# Phase 2 — Data Core Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace "goals are strings inside the last saved day" with real entities (`Goal`, `DayEntry`) persisted as a versioned JSON file, behind a `GoalsRepository` interface, exposed to the UI through an `AppStore` (ChangeNotifier via `provider`); settings (nickname, theme, threshold, reminder, onboarding) behind `SettingsRepository`/`SettingsStore`; one-time migration of the installed v1 blob. UI stays visually identical (Phase 4 changes it).

**Architecture:** `lib/models/*` are immutable value types with `toJson/fromJson`; `lib/data/*` = repositories (file + SharedPreferences) and the legacy migration; `lib/state/*` = `AppStore` + `SettingsStore` (the only mutable state, notify on change); controllers become thin adapters from store state to the existing widgets. `LocalData`, `ThemeModel`, `RecoveryModel`, `DateGoalModel` (outside migration) are deleted at the end.

**Tech Stack:** Flutter 3.41, `provider`, `shared_preferences`, `path_provider`, `uuid`.

**Spec:** `docs/superpowers/specs/2026-08-15-consistency-v2-design.md` — Seção 1 (modelo, repositório, migração), fase 2.

## Global Constraints

- New packages: `path_provider`, `uuid` only.
- Dates in JSON: `"yyyy-MM-dd"` (local calendar day). `updatedAt`: ISO-8601 UTC. `schemaVersion: 2`.
- Meta ativa no dia D: `createdAt ≤ D && (archivedAt == null || D < archivedAt)` (dates compared as calendar days).
- File: `<appDocs>/consistency.json`; write = `.tmp` then rename, previous good copy kept as `.bak`; load falls back to `.bak` on parse failure. "Delete all" = rename to `.deleted`, `undoClear` renames back; purged on next save.
- SharedPreferences keys keep legacy names where they exist: `nickname` (String), `themeDark` (bool?, null = system). New keys: `threshold` (int, default 50), `notifEnabled` (bool, default false), `notifHour` (int, 20), `notifMinute` (int, 0), `onboardingDone` (bool, false).
- Migration runs once: when the file does not exist and prefs contain `userData`. After success removes `userData` and `beforeDelete`.
- Lints `prefer_single_quotes`, `prefer_relative_imports` (lib); `flutter analyze` clean, `flutter test --concurrency=1` green before every commit; Conventional Commit subjects; `dart format lib test` before commit.
- Test caveat: `SharedPreferences.setMockInitialValues({...})` per test is fine now — nothing caches the instance in a static anymore after Task 4 (until then, keep old tests as they are).

---

### Task 1: Models — `Goal`, `DayEntry`, `AppData`, date keys

**Files:**
- Create: `lib/models/date_key.dart`, `lib/models/goal.dart`, `lib/models/day_entry.dart`, `lib/models/app_data.dart`
- Modify: `pubspec.yaml` (add `uuid: ^4.4.0`, `path_provider: ^2.1.3`)
- Test: `test/models_test.dart`

**Interfaces (produced):**
```dart
DateTime dateOnly(DateTime d);            // local y/m/d, 00:00
String dateKey(DateTime d);               // 'yyyy-MM-dd'
DateTime parseDateKey(String s);
enum GoalType { check, percent }
class Goal { String id, name; GoalType type; DateTime createdAt; DateTime? archivedAt; DateTime updatedAt;
  bool isActiveOn(DateTime day); Goal copyWith({...}); Map<String,dynamic> toJson(); factory Goal.fromJson(Map); }
class DayEntry { DateTime date; Map<String,double> values; DateTime updatedAt; toJson/fromJson; copyWith }
class AppData { static const schemaVersion = 2; List<Goal> goals; List<DayEntry> entries;  // entries sorted by date
  static const empty; DayEntry? entryOn(DateTime day); Goal? goalById(String id); List<Goal> activeGoalsOn(DateTime day);
  AppData copyWith({goals, entries}); toJson/fromJson; }
```

- [ ] **Step 1: deps**

`pubspec.yaml` dependencies (after `provider: ^6.1.2`):
```yaml
  path_provider: ^2.1.3
  uuid: ^4.4.0
```
Run `flutter pub get`.

- [ ] **Step 2: failing tests**

`test/models_test.dart`:
```dart
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
    expect(g.copyWith(archivedAt: null).isActiveOn(DateTime(2027, 1, 1)), isTrue);
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
    expect(back.entries.map((e) => dateKey(e.date)), ['2026-08-02', '2026-08-03']);
    expect(back.entryOn(DateTime(2026, 8, 3, 9))!.values, {'g1': 100.0, 'g2': 25.0});
    expect(back.activeGoalsOn(DateTime(2026, 8, 3)).map((g) => g.id), ['g1', 'g2']);
    expect(back.activeGoalsOn(DateTime(2026, 8, 6)).map((g) => g.id), ['g1']);
    expect(back.entries.first.updatedAt.isUtc, isTrue);
  });

  test('AppData.fromJson rejects unknown schema versions', () {
    expect(() => AppData.fromJson({'schemaVersion': 99, 'goals': [], 'entries': []}),
        throwsFormatException);
  });
}
```

- [ ] **Step 3: run → fails** (`Target of URI doesn't exist`).

- [ ] **Step 4: `lib/models/date_key.dart`**
```dart
/// Calendar-day helpers. The app reasons in local calendar days; the JSON
/// stores them as 'yyyy-MM-dd' so DST/timezone shifts never move an entry.
DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

String dateKey(DateTime d) {
  final y = d.year.toString().padLeft(4, '0');
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '$y-$m-$day';
}

DateTime parseDateKey(String s) {
  final parts = s.split('-');
  if (parts.length != 3) throw FormatException('Bad date key: $s');
  return DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
}
```

- [ ] **Step 5: `lib/models/goal.dart`**
```dart
import 'date_key.dart';

enum GoalType { check, percent }

class Goal {
  final String id;
  final String name;
  final GoalType type;
  final DateTime createdAt; // calendar day; active from here
  final DateTime? archivedAt; // calendar day; null = active
  final DateTime updatedAt; // UTC instant, for merge/sync

  Goal({
    required this.id,
    required this.name,
    required this.type,
    required DateTime createdAt,
    required DateTime? archivedAt,
    required this.updatedAt,
  })  : createdAt = dateOnly(createdAt),
        archivedAt = archivedAt == null ? null : dateOnly(archivedAt);

  bool isActiveOn(DateTime day) {
    final d = dateOnly(day);
    if (d.isBefore(createdAt)) return false;
    final a = archivedAt;
    return a == null || d.isBefore(a);
  }

  bool get isArchived => archivedAt != null;

  Goal copyWith({
    String? name,
    GoalType? type,
    DateTime? createdAt,
    Object? archivedAt = _keep,
    DateTime? updatedAt,
  }) =>
      Goal(
        id: id,
        name: name ?? this.name,
        type: type ?? this.type,
        createdAt: createdAt ?? this.createdAt,
        archivedAt: identical(archivedAt, _keep)
            ? this.archivedAt
            : archivedAt as DateTime?,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type.name,
        'createdAt': dateKey(createdAt),
        'archivedAt': archivedAt == null ? null : dateKey(archivedAt!),
        'updatedAt': updatedAt.toUtc().toIso8601String(),
      };

  factory Goal.fromJson(Map<String, dynamic> j) => Goal(
        id: j['id'] as String,
        name: j['name'] as String,
        type: GoalType.values.byName(j['type'] as String),
        createdAt: parseDateKey(j['createdAt'] as String),
        archivedAt: j['archivedAt'] == null
            ? null
            : parseDateKey(j['archivedAt'] as String),
        updatedAt: DateTime.parse(j['updatedAt'] as String).toUtc(),
      );
}

const _keep = Object();
```

- [ ] **Step 6: `lib/models/day_entry.dart`**
```dart
import 'date_key.dart';

class DayEntry {
  final DateTime date; // calendar day
  final Map<String, double> values; // goalId -> 0..100 (check: 0 | 100)
  final DateTime updatedAt; // UTC instant

  DayEntry({
    required DateTime date,
    required Map<String, double> values,
    required this.updatedAt,
  })  : date = dateOnly(date),
        values = Map.unmodifiable(values);

  DayEntry copyWith({Map<String, double>? values, DateTime? updatedAt}) =>
      DayEntry(
        date: date,
        values: values ?? this.values,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, dynamic> toJson() => {
        'date': dateKey(date),
        'values': values,
        'updatedAt': updatedAt.toUtc().toIso8601String(),
      };

  factory DayEntry.fromJson(Map<String, dynamic> j) => DayEntry(
        date: parseDateKey(j['date'] as String),
        values: {
          for (final e in (j['values'] as Map).entries)
            e.key as String: (e.value as num).toDouble(),
        },
        updatedAt: DateTime.parse(j['updatedAt'] as String).toUtc(),
      );
}
```

- [ ] **Step 7: `lib/models/app_data.dart`**
```dart
import 'date_key.dart';
import 'day_entry.dart';
import 'goal.dart';

class AppData {
  static const int schemaVersion = 2;

  final List<Goal> goals;
  final List<DayEntry> entries; // always sorted by date ascending

  AppData({required List<Goal> goals, required List<DayEntry> entries})
      : goals = List.unmodifiable(goals),
        entries = List.unmodifiable(
          [...entries]..sort((a, b) => a.date.compareTo(b.date)),
        );

  static final empty = AppData(goals: const [], entries: const []);

  Goal? goalById(String id) {
    for (final g in goals) {
      if (g.id == id) return g;
    }
    return null;
  }

  DayEntry? entryOn(DateTime day) {
    final d = dateOnly(day);
    for (final e in entries) {
      if (e.date == d) return e;
    }
    return null;
  }

  List<Goal> activeGoalsOn(DateTime day) =>
      [for (final g in goals) if (g.isActiveOn(day)) g];

  AppData copyWith({List<Goal>? goals, List<DayEntry>? entries}) =>
      AppData(goals: goals ?? this.goals, entries: entries ?? this.entries);

  Map<String, dynamic> toJson() => {
        'schemaVersion': schemaVersion,
        'goals': [for (final g in goals) g.toJson()],
        'entries': [for (final e in entries) e.toJson()],
      };

  factory AppData.fromJson(Map<String, dynamic> j) {
    final v = j['schemaVersion'];
    if (v != schemaVersion) {
      throw FormatException('Unsupported schemaVersion: $v');
    }
    return AppData(
      goals: [
        for (final g in j['goals'] as List) Goal.fromJson(g as Map<String, dynamic>),
      ],
      entries: [
        for (final e in j['entries'] as List)
          DayEntry.fromJson(e as Map<String, dynamic>),
      ],
    );
  }
}
```

- [ ] **Step 8: run tests + analyze → green.**
- [ ] **Step 9: Commit** — `git add pubspec.yaml pubspec.lock lib/models test/models_test.dart && git commit -m "feat: Goal/DayEntry/AppData models with yyyy-MM-dd keys"`

---

### Task 2: `GoalsRepository` + `FileGoalsRepository` (atomic, .bak, undo) + in-memory fake

**Files:**
- Create: `lib/data/goals_repository.dart`, `lib/data/file_goals_repository.dart`, `lib/data/in_memory_goals_repository.dart`
- Test: `test/file_goals_repository_test.dart`

**Interfaces (produced):**
```dart
abstract class GoalsRepository {
  Future<bool> exists();
  Future<AppData> load();            // returns AppData.empty when nothing stored
  Future<void> save(AppData data);   // also purges any pending undo
  Future<void> moveToUndo();         // "delete all": data disappears, restorable
  Future<bool> restoreFromUndo();    // true if something was restored
  Future<void> purgeUndo();
}
class FileGoalsRepository implements GoalsRepository {
  FileGoalsRepository(Directory dir);                       // for tests
  static Future<FileGoalsRepository> open();                // path_provider docs dir
}
class InMemoryGoalsRepository implements GoalsRepository { AppData? stored; AppData? undo; int saves; }
```

- [ ] **Step 1: failing tests**

`test/file_goals_repository_test.dart`:
```dart
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

  test('moveToUndo hides data; restoreFromUndo brings it back; save purges undo',
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
```

- [ ] **Step 2: run → fails.**

- [ ] **Step 3: `lib/data/goals_repository.dart`**
```dart
import '../models/app_data.dart';

/// Persistence boundary. Swap the implementation (file today, cloud later)
/// without touching the store or the UI.
abstract class GoalsRepository {
  Future<bool> exists();
  Future<AppData> load();
  Future<void> save(AppData data);
  Future<void> moveToUndo();
  Future<bool> restoreFromUndo();
  Future<void> purgeUndo();
}
```

- [ ] **Step 4: `lib/data/file_goals_repository.dart`**
```dart
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/app_data.dart';
import 'goals_repository.dart';

class FileGoalsRepository implements GoalsRepository {
  final Directory dir;

  FileGoalsRepository(this.dir);

  static Future<FileGoalsRepository> open() async =>
      FileGoalsRepository(await getApplicationDocumentsDirectory());

  File get _main => File('${dir.path}/consistency.json');
  File get _tmp => File('${dir.path}/consistency.json.tmp');
  File get _bak => File('${dir.path}/consistency.json.bak');
  File get _deleted => File('${dir.path}/consistency.json.deleted');

  @override
  Future<bool> exists() => _main.exists();

  @override
  Future<AppData> load() async {
    final fromMain = await _tryRead(_main);
    if (fromMain != null) return fromMain;
    final fromBak = await _tryRead(_bak);
    if (fromBak != null) return fromBak;
    if (await _main.exists()) {
      throw const FormatException('consistency.json unreadable and no valid .bak');
    }
    return AppData.empty;
  }

  Future<AppData?> _tryRead(File f) async {
    if (!await f.exists()) return null;
    try {
      final j = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      return AppData.fromJson(j);
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  @override
  Future<void> save(AppData data) async {
    await dir.create(recursive: true);
    await _tmp.writeAsString(jsonEncode(data.toJson()), flush: true);
    if (await _main.exists()) {
      // Keep the last good file; overwrite any older backup.
      if (await _bak.exists()) await _bak.delete();
      await _main.rename(_bak.path);
    }
    await _tmp.rename(_main.path);
    await purgeUndo();
  }

  @override
  Future<void> moveToUndo() async {
    if (!await _main.exists()) return;
    if (await _deleted.exists()) await _deleted.delete();
    await _main.rename(_deleted.path);
    if (await _bak.exists()) await _bak.delete();
  }

  @override
  Future<bool> restoreFromUndo() async {
    if (!await _deleted.exists()) return false;
    await _deleted.rename(_main.path);
    return true;
  }

  @override
  Future<void> purgeUndo() async {
    if (await _deleted.exists()) await _deleted.delete();
  }
}
```

- [ ] **Step 5: `lib/data/in_memory_goals_repository.dart`**
```dart
import '../models/app_data.dart';
import 'goals_repository.dart';

/// Test double and a convenient seed for widget tests.
class InMemoryGoalsRepository implements GoalsRepository {
  AppData? stored;
  AppData? undo;
  int saves = 0;

  InMemoryGoalsRepository([this.stored]);

  @override
  Future<bool> exists() async => stored != null;
  @override
  Future<AppData> load() async => stored ?? AppData.empty;
  @override
  Future<void> save(AppData data) async {
    stored = data;
    saves++;
    undo = null;
  }

  @override
  Future<void> moveToUndo() async {
    undo = stored;
    stored = null;
  }

  @override
  Future<bool> restoreFromUndo() async {
    if (undo == null) return false;
    stored = undo;
    undo = null;
    return true;
  }

  @override
  Future<void> purgeUndo() async => undo = null;
}
```

- [ ] **Step 6: run tests + analyze → green.**
- [ ] **Step 7: Commit** — `git add lib/data test/file_goals_repository_test.dart && git commit -m "feat: GoalsRepository with atomic file store, .bak fallback and undo"`

---

### Task 3: Legacy v1 migration

**Files:**
- Create: `lib/data/legacy_migration.dart`
- Create: `test/fixtures/v1_userdata.json` (real on-disk shape)
- Test: `test/legacy_migration_test.dart`

**Interfaces (produced):**
```dart
class LegacyMigration {
  /// Pure: decode the v1 SharedPreferences `userData` string into AppData.
  static AppData convert(String userDataJson, {required String Function() newId});
  /// Side-effecting: if repo has no file and prefs hold `userData`, convert,
  /// save, and remove `userData` + `beforeDelete`. Returns true if migrated.
  static Future<bool> runIfNeeded(SharedPreferences prefs, GoalsRepository repo);
}
```

- [ ] **Step 1: fixture** `test/fixtures/v1_userdata.json` — exactly the v1 shape (array of JSON *strings*, dates as epoch ms local, `Run` renamed to `Sprint` on the last day so the "same name = same goal" rule and archiving are both exercised):
```json
["{\"date\":1754017200000,\"goals\":[{\"name\":\"Run\",\"percentCompleted\":50.0},{\"name\":\"Read\",\"percentCompleted\":100.0}]}","{\"date\":1754103600000,\"goals\":[{\"name\":\"Run\",\"percentCompleted\":75.0},{\"name\":\"Read\",\"percentCompleted\":25.0}]}","{\"date\":1754276400000,\"goals\":[{\"name\":\"Sprint\",\"percentCompleted\":100.0},{\"name\":\"Read\",\"percentCompleted\":0.0}]}"]
```
(1754017200000 = 2026-08-01 00:00 UTC-3; the three days are Aug 1, Aug 2, Aug 4 local. If your machine's TZ differs the test below derives expected days from `DateTime.fromMillisecondsSinceEpoch`, so it stays green anywhere.)

- [ ] **Step 2: failing tests**

`test/legacy_migration_test.dart`:
```dart
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

  test('convert: one Goal per distinct name, entries keyed by id, stale goals archived',
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
    expect(await LegacyMigration.runIfNeeded(prefs, InMemoryGoalsRepository()), isFalse);
  });
}
```

- [ ] **Step 3: run → fails.**

- [ ] **Step 4: `lib/data/legacy_migration.dart`**
```dart
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/app_data.dart';
import '../models/date_key.dart';
import '../models/day_entry.dart';
import '../models/goal.dart';
import 'goals_repository.dart';

/// v1 stored everything in SharedPreferences['userData'] as an array of JSON
/// strings: `{"date": epochMs, "goals": [{"name", "percentCompleted"}]}`.
class LegacyMigration {
  static const userDataKey = 'userData';
  static const beforeDeleteKey = 'beforeDelete';

  static AppData convert(String userDataJson, {String Function()? newId}) {
    final mkId = newId ?? const Uuid().v4;
    final raw = jsonDecode(userDataJson) as List;
    final days = <({DateTime date, List<(String, double)> goals})>[];
    for (final item in raw) {
      final m = jsonDecode(item as String) as Map<String, dynamic>;
      final date = dateOnly(
        DateTime.fromMillisecondsSinceEpoch(m['date'] as int),
      );
      final goals = <(String, double)>[
        for (final g in (m['goals'] as List? ?? const []))
          (
            (g['name'] as String? ?? '').trim(),
            ((g['percentCompleted'] as num?) ?? 0).toDouble(),
          ),
      ];
      days.add((date: date, goals: goals));
    }
    days.sort((a, b) => a.date.compareTo(b.date));

    final byName = <String, Goal>{};
    final lastSeen = <String, DateTime>{};
    final entries = <DayEntry>[];
    final now = DateTime.now().toUtc();

    for (final day in days) {
      final values = <String, double>{};
      for (final (name, pct) in day.goals) {
        final goal = byName.putIfAbsent(
          name,
          () => Goal(
            id: mkId(),
            name: name,
            type: GoalType.percent,
            createdAt: day.date,
            archivedAt: null,
            updatedAt: now,
          ),
        );
        values[goal.id] = pct;
        lastSeen[name] = day.date;
      }
      entries.add(DayEntry(date: day.date, values: values, updatedAt: now));
    }

    final lastDayNames = days.isEmpty
        ? const <String>{}
        : {for (final (n, _) in days.last.goals) n};
    final goals = [
      for (final g in byName.values)
        lastDayNames.contains(g.name)
            ? g
            : g.copyWith(
                archivedAt: lastSeen[g.name]!.add(const Duration(days: 1)),
              ),
    ];
    return AppData(goals: goals, entries: entries);
  }

  static Future<bool> runIfNeeded(
    SharedPreferences prefs,
    GoalsRepository repo,
  ) async {
    if (await repo.exists()) return false;
    final blob = prefs.getString(userDataKey);
    if (blob == null || blob.isEmpty) return false;
    await repo.save(convert(blob));
    await prefs.remove(userDataKey);
    await prefs.remove(beforeDeleteKey);
    return true;
  }
}
```

- [ ] **Step 5: run tests + analyze → green.**
- [ ] **Step 6: Commit** — `git add lib/data/legacy_migration.dart test/fixtures test/legacy_migration_test.dart && git commit -m "feat: one-time migration of the v1 userData blob"`

---

### Task 4: `SettingsRepository` + `SettingsStore` (absorbs `ThemeModel`)

**Files:**
- Create: `lib/data/settings_repository.dart`, `lib/state/settings_store.dart`
- Modify: `lib/configs/theme.dart` (delete `ThemeModel` and its `local_data.dart` import), `lib/main.dart`, `lib/pages/settings_page.dart` (theme segmented reads `SettingsStore`)
- Test: `test/settings_store_test.dart` (new); update `test/theme_mode_default_test.dart` (now tests `SettingsStore`), `test/theme_tokens_test.dart` + `test/theme_tokens_light_test.dart` (unchanged assertions; still seed `themeDark`)

**Interfaces (produced):**
```dart
class SettingsRepository {
  SettingsRepository(SharedPreferences prefs);
  String? get nickname; Future<void> setNickname(String?);
  ThemeMode get themeMode; Future<void> setThemeMode(ThemeMode);       // themeDark bool? key
  int get threshold; Future<void> setThreshold(int);                    // 0..100, default 50
  bool get notifEnabled; Future<void> setNotifEnabled(bool);
  (int hour, int minute) get notifTime; Future<void> setNotifTime(int hour, int minute);
  bool get onboardingDone; Future<void> setOnboardingDone(bool);
}
class SettingsStore extends ChangeNotifier {
  SettingsStore(SettingsRepository repo);
  // same getters; setters notify then persist
  String get nicknameOrDefault; // nickname ?? 'User'
}
```
`ThemeModel` is gone; `context.watch<SettingsStore>().themeMode` replaces `ThemeModel.themeMode`; `setThemeMode` replaces `setMode`.

- [ ] **Step 1: failing tests**

`test/settings_store_test.dart`:
```dart
import 'package:consistency/data/settings_repository.dart';
import 'package:consistency/state/settings_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('defaults on a fresh install', () async {
    SharedPreferences.setMockInitialValues({});
    final s = SettingsStore(SettingsRepository(await SharedPreferences.getInstance()));
    expect(s.themeMode, ThemeMode.system);
    expect(s.nickname, isNull);
    expect(s.nicknameOrDefault, 'User');
    expect(s.threshold, 50);
    expect(s.notifEnabled, isFalse);
    expect(s.notifTime, (20, 0));
    expect(s.onboardingDone, isFalse);
  });

  test('reads legacy keys and persists on the same keys', () async {
    SharedPreferences.setMockInitialValues({'themeDark': true, 'nickname': 'Alvaro'});
    final prefs = await SharedPreferences.getInstance();
    final s = SettingsStore(SettingsRepository(prefs));
    expect(s.themeMode, ThemeMode.dark);
    expect(s.nickname, 'Alvaro');

    var notified = 0;
    s.addListener(() => notified++);
    await s.setThemeMode(ThemeMode.light);
    expect(prefs.getBool('themeDark'), isFalse);
    await s.setThemeMode(ThemeMode.system);
    expect(prefs.containsKey('themeDark'), isFalse);
    await s.setThreshold(75);
    expect(prefs.getInt('threshold'), 75);
    await s.setNotifTime(7, 30);
    expect(s.notifTime, (7, 30));
    await s.setNickname('  ');
    expect(s.nickname, isNull);
    expect(notified, 5);
  });

  test('threshold is clamped to 0..100', () async {
    SharedPreferences.setMockInitialValues({});
    final s = SettingsStore(SettingsRepository(await SharedPreferences.getInstance()));
    await s.setThreshold(140);
    expect(s.threshold, 100);
    await s.setThreshold(-5);
    expect(s.threshold, 0);
  });
}
```
Rewrite `test/theme_mode_default_test.dart` entirely:
```dart
import 'package:consistency/data/settings_repository.dart';
import 'package:consistency/state/settings_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('theme resolves to system when the user never picked one', () async {
    SharedPreferences.setMockInitialValues({});
    final s = SettingsStore(SettingsRepository(await SharedPreferences.getInstance()));
    expect(s.themeMode, ThemeMode.system);
  });
}
```

- [ ] **Step 2: run → fails.**

- [ ] **Step 3: `lib/data/settings_repository.dart`**
```dart
import 'package:flutter/material.dart' show ThemeMode;
import 'package:shared_preferences/shared_preferences.dart';

/// Small typed facade over SharedPreferences. Legacy keys are kept so
/// installed apps keep their nickname and theme.
class SettingsRepository {
  final SharedPreferences _p;
  SettingsRepository(this._p);

  static const _nickname = 'nickname';
  static const _themeDark = 'themeDark';
  static const _threshold = 'threshold';
  static const _notifEnabled = 'notifEnabled';
  static const _notifHour = 'notifHour';
  static const _notifMinute = 'notifMinute';
  static const _onboardingDone = 'onboardingDone';

  String? get nickname {
    final n = _p.getString(_nickname)?.trim();
    return (n == null || n.isEmpty) ? null : n;
  }

  Future<void> setNickname(String? v) {
    final n = v?.trim();
    return (n == null || n.isEmpty)
        ? _p.remove(_nickname)
        : _p.setString(_nickname, n);
  }

  ThemeMode get themeMode => switch (_p.getBool(_themeDark)) {
        null => ThemeMode.system,
        true => ThemeMode.dark,
        false => ThemeMode.light,
      };

  Future<void> setThemeMode(ThemeMode m) => switch (m) {
        ThemeMode.system => _p.remove(_themeDark),
        ThemeMode.dark => _p.setBool(_themeDark, true),
        ThemeMode.light => _p.setBool(_themeDark, false),
      };

  int get threshold => (_p.getInt(_threshold) ?? 50).clamp(0, 100);
  Future<void> setThreshold(int v) => _p.setInt(_threshold, v.clamp(0, 100));

  bool get notifEnabled => _p.getBool(_notifEnabled) ?? false;
  Future<void> setNotifEnabled(bool v) => _p.setBool(_notifEnabled, v);

  (int, int) get notifTime =>
      (_p.getInt(_notifHour) ?? 20, _p.getInt(_notifMinute) ?? 0);
  Future<void> setNotifTime(int hour, int minute) async {
    await _p.setInt(_notifHour, hour);
    await _p.setInt(_notifMinute, minute);
  }

  bool get onboardingDone => _p.getBool(_onboardingDone) ?? false;
  Future<void> setOnboardingDone(bool v) => _p.setBool(_onboardingDone, v);
}
```

- [ ] **Step 4: `lib/state/settings_store.dart`**
```dart
import 'package:flutter/material.dart';

import '../data/settings_repository.dart';

class SettingsStore extends ChangeNotifier {
  final SettingsRepository _repo;
  SettingsStore(this._repo);

  String? get nickname => _repo.nickname;
  String get nicknameOrDefault => nickname ?? 'User';
  ThemeMode get themeMode => _repo.themeMode;
  int get threshold => _repo.threshold;
  bool get notifEnabled => _repo.notifEnabled;
  (int, int) get notifTime => _repo.notifTime;
  bool get onboardingDone => _repo.onboardingDone;

  Future<void> _apply(Future<void> Function() write) async {
    await write();
    notifyListeners();
  }

  Future<void> setNickname(String? v) => _apply(() => _repo.setNickname(v));
  Future<void> setThemeMode(ThemeMode m) => _apply(() => _repo.setThemeMode(m));
  Future<void> setThreshold(int v) => _apply(() => _repo.setThreshold(v));
  Future<void> setNotifEnabled(bool v) => _apply(() => _repo.setNotifEnabled(v));
  Future<void> setNotifTime(int h, int m) => _apply(() => _repo.setNotifTime(h, m));
  Future<void> setOnboardingDone(bool v) => _apply(() => _repo.setOnboardingDone(v));
}
```

- [ ] **Step 5: `main.dart` — async bootstrap, providers**

`lib/main.dart` full content:
```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'configs/theme.dart';
import 'data/settings_repository.dart';
import 'pages/skeleton_page.dart';
import 'pages/splash_page.dart';
import 'state/settings_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(ConsistencyApp(settings: SettingsStore(SettingsRepository(prefs))));
}

class ConsistencyApp extends StatelessWidget {
  final SettingsStore settings;
  const ConsistencyApp({super.key, required this.settings});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: settings,
      child: Builder(
        builder: (context) => MaterialApp(
          title: 'Consistency',
          debugShowCheckedModeBanner: false,
          theme: themeLight,
          darkTheme: themeDark,
          themeMode: context.watch<SettingsStore>().themeMode,
          initialRoute: '/',
          routes: {
            '/': (context) => const SplashPage(),
            '/manager': (context) => const SkelentonPage(),
          },
        ),
      ),
    );
  }
}
```
(Task 5 adds `AppStore` next to it.) Update the two smoke tests to build the app the same way:
```dart
      SharedPreferences.setMockInitialValues({'themeDark': true});
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ConsistencyApp(settings: SettingsStore(SettingsRepository(prefs))),
      );
```
(imports: `package:consistency/data/settings_repository.dart`, `package:consistency/state/settings_store.dart`). The `theme_tokens_light_test.dart` file gets the same shape with `false`. Keep the frame loop + brightness assertions.

- [ ] **Step 6: delete `ThemeModel`; settings page uses `SettingsStore`**

`lib/configs/theme.dart`: delete the `ThemeModel` class and `import 'local_data.dart';`. `lib/pages/settings_page.dart`: `context.watch<ThemeModel>().themeMode` → `context.watch<SettingsStore>().themeMode`; `context.read<ThemeModel>().setMode(s.first)` → `context.read<SettingsStore>().setThemeMode(s.first)`; import `../state/settings_store.dart` instead of `../configs/theme.dart` (keep theme import only if still used). Grep: no `ThemeModel` left anywhere.

- [ ] **Step 7: run tests + analyze → green.** (`goal_history_test`, `recovery_expiry_test` still use `LocalData` — untouched until Task 6.)
- [ ] **Step 8: Commit** — `git add -A lib test && git commit -m "feat: SettingsRepository/SettingsStore replace ThemeModel"`

---

### Task 5: `AppStore` — in-memory `AppData` + mutations + persistence + undo

**Files:**
- Create: `lib/state/app_store.dart`
- Test: `test/app_store_test.dart`

**Interfaces (produced):**
```dart
class AppStore extends ChangeNotifier {
  AppStore(GoalsRepository repo, {String Function()? newId, DateTime Function()? now});
  AppData get data; bool get loaded; Object? get loadError;
  Future<void> load();                                   // sets loaded, notifies; on failure sets loadError
  Future<Goal> addGoal(String name, GoalType type, {DateTime? createdAt});
  Future<void> renameGoal(String id, String name);
  Future<void> setGoalType(String id, GoalType type);
  Future<void> archiveGoal(String id, {DateTime? on});   // archivedAt = today (or on)
  Future<void> restoreGoal(String id);
  Future<void> saveDay(DateTime day, Map<String, double> values); // upsert; values filtered to goals active that day
  Future<void> replaceAll(AppData data);
  Future<void> clearAll();  Future<bool> undoClear();
}
```

- [ ] **Step 1: failing tests**

`test/app_store_test.dart`:
```dart
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
    store = AppStore(repo, newId: () => 'g${n++}', now: () => DateTime.utc(2026, 8, 16, 12));
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

  test('saveDay upserts and drops values for goals not active that day', () async {
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

  test('clearAll hides everything; undoClear restores; a save after clear makes undo impossible',
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
```

- [ ] **Step 2: run → fails.**

- [ ] **Step 3: `lib/state/app_store.dart`**
```dart
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../data/goals_repository.dart';
import '../models/app_data.dart';
import '../models/date_key.dart';
import '../models/day_entry.dart';
import '../models/goal.dart';

/// The single in-memory copy of the user's data. Every mutation persists
/// through the repository and notifies listeners.
class AppStore extends ChangeNotifier {
  final GoalsRepository _repo;
  final String Function() _newId;
  final DateTime Function() _now;

  AppData _data = AppData.empty;
  bool _loaded = false;
  Object? _loadError;

  AppStore(
    this._repo, {
    String Function()? newId,
    DateTime Function()? now,
  })  : _newId = newId ?? const Uuid().v4,
        _now = now ?? () => DateTime.now().toUtc();

  AppData get data => _data;
  bool get loaded => _loaded;
  Object? get loadError => _loadError;

  Future<void> load() async {
    try {
      _data = await _repo.load();
      _loaded = true;
      _loadError = null;
    } catch (e, s) {
      debugPrint('AppStore.load failed: $e\n$s');
      _loadError = e;
      _loaded = false;
    }
    notifyListeners();
  }

  Future<void> _commit(AppData next) async {
    _data = next;
    notifyListeners();
    await _repo.save(next);
  }

  Future<Goal> addGoal(String name, GoalType type, {DateTime? createdAt}) async {
    final goal = Goal(
      id: _newId(),
      name: name.trim(),
      type: type,
      createdAt: createdAt ?? dateOnly(DateTime.now()),
      archivedAt: null,
      updatedAt: _now(),
    );
    await _commit(_data.copyWith(goals: [..._data.goals, goal]));
    return goal;
  }

  Future<void> _updateGoal(String id, Goal Function(Goal) f) => _commit(
        _data.copyWith(goals: [
          for (final g in _data.goals) g.id == id ? f(g).copyWith(updatedAt: _now()) : g,
        ]),
      );

  Future<void> renameGoal(String id, String name) =>
      _updateGoal(id, (g) => g.copyWith(name: name.trim()));

  Future<void> setGoalType(String id, GoalType type) =>
      _updateGoal(id, (g) => g.copyWith(type: type));

  Future<void> archiveGoal(String id, {DateTime? on}) =>
      _updateGoal(id, (g) => g.copyWith(archivedAt: on ?? dateOnly(DateTime.now())));

  Future<void> restoreGoal(String id) =>
      _updateGoal(id, (g) => g.copyWith(archivedAt: null));

  Future<void> saveDay(DateTime day, Map<String, double> values) async {
    final d = dateOnly(day);
    final active = {for (final g in _data.activeGoalsOn(d)) g.id};
    final clean = {
      for (final e in values.entries)
        if (active.contains(e.key)) e.key: e.value.clamp(0, 100).toDouble(),
    };
    final entry = DayEntry(date: d, values: clean, updatedAt: _now());
    final others = [for (final e in _data.entries) if (e.date != d) e];
    await _commit(_data.copyWith(entries: [...others, entry]));
  }

  Future<void> replaceAll(AppData data) => _commit(data);

  Future<void> clearAll() async {
    await _repo.moveToUndo();
    _data = AppData.empty;
    notifyListeners();
  }

  Future<bool> undoClear() async {
    if (!await _repo.restoreFromUndo()) return false;
    _data = await _repo.load();
    notifyListeners();
    return true;
  }
}
```

- [ ] **Step 4: run tests + analyze → green.**
- [ ] **Step 5: Commit** — `git add lib/state/app_store.dart test/app_store_test.dart && git commit -m "feat: AppStore holds AppData with persisted mutations and undo"`

---

### Task 6: Wire the app to the stores; delete `LocalData`

**Files:**
- Modify: `lib/main.dart` (bootstrap: prefs → migration → `AppStore.load()`; `MultiProvider`)
- Modify: `lib/pages/splash_page.dart` (wait for `AppStore.loaded || loadError`)
- Modify: `lib/controllers/home_controller.dart`, `lib/controllers/calendar_controller.dart`, `lib/controllers/settings_controller.dart`
- Modify: `lib/pages/home_page.dart`, `lib/pages/calendar_page.dart`, `lib/pages/settings_page.dart` (controllers receive stores from `context.read`)
- Delete: `lib/configs/local_data.dart`, `lib/models/recovery_model.dart`, `lib/models/date_goal_model.dart` (its decode logic now lives in `LegacyMigration.convert`)
- Keep: `lib/models/goal_model.dart` (view model for the existing widgets; add a `goalId` field)
- Test: rewrite `test/goal_history_test.dart` against `AppStore`+`HomeController`; delete `test/recovery_expiry_test.dart` (covered by `app_store_test`); `test/splash_navigation_test.dart`, `test/theme_tokens*_test.dart` build the app via the new constructor.

**Interfaces (consumed):** everything from Tasks 1–5.

- [ ] **Step 1: `GoalModel` gains `goalId`**

`lib/models/goal_model.dart`: add `final String goalId;` (required, first ctor param), keep `name`, `percentCompleted` mutable, keep `copyWith` (with `goalId` carried), drop `toMap/fromMap` (unused after LocalData dies — verify with grep; if `goals_done_list_view`/`goals_list_view` only read `.name/.percentCompleted` they compile unchanged).

- [ ] **Step 2: bootstrap in `main.dart`**

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final repo = await FileGoalsRepository.open();
  await LegacyMigration.runIfNeeded(prefs, repo);
  final store = AppStore(repo);
  unawaited(store.load()); // splash waits on it
  runApp(ConsistencyApp(
    settings: SettingsStore(SettingsRepository(prefs)),
    store: store,
  ));
}

class ConsistencyApp extends StatelessWidget {
  final SettingsStore settings;
  final AppStore store;
  const ConsistencyApp({super.key, required this.settings, required this.store});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider.value(value: store),
      ],
      child: Builder(builder: (context) => MaterialApp(/* unchanged */)),
    );
  }
}
```
(`import 'dart:async' show unawaited;` plus the data/state imports.) Widget tests build `ConsistencyApp(settings: ..., store: AppStore(InMemoryGoalsRepository())..load())` — write a tiny helper in `test/helpers.dart`:
```dart
import 'package:consistency/data/in_memory_goals_repository.dart';
import 'package:consistency/data/settings_repository.dart';
import 'package:consistency/main.dart';
import 'package:consistency/models/app_data.dart';
import 'package:consistency/state/app_store.dart';
import 'package:consistency/state/settings_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ConsistencyApp> buildApp({
  Map<String, Object> prefs = const {},
  AppData? data,
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final p = await SharedPreferences.getInstance();
  final store = AppStore(InMemoryGoalsRepository(data));
  await store.load();
  return ConsistencyApp(
    settings: SettingsStore(SettingsRepository(p)),
    store: store,
  );
}
```
and use it in `splash_navigation_test.dart`, `theme_tokens_test.dart`, `theme_tokens_light_test.dart` (`await tester.pumpWidget(await buildApp(prefs: {'themeDark': true}))`).

- [ ] **Step 3: splash waits for the store**

`lib/pages/splash_page.dart` `initState`:
```dart
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final store = context.read<AppStore>();
      if (!store.loaded && store.loadError == null) {
        final c = Completer<void>();
        void l() {
          if (store.loaded || store.loadError != null) c.complete();
        }
        store.addListener(l);
        await c.future;
        store.removeListener(l);
      }
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/manager', (_) => false);
      }
    });
```
(imports `dart:async`, `provider`, `../state/app_store.dart`; drop `dart:developer` + `local_data.dart`).

- [ ] **Step 4: `HomeController` over `AppStore`**

Rewrite `lib/controllers/home_controller.dart` keeping the state classes (`HomeInitial/Loading/Error/Data/DataEmpty`) and the widget-facing API (`goalsControllers`, `completePercent`, `saveData`, `addNewGoal`, `removeGoal`, `reload`, `onDispose`):
```dart
class HomeController extends BaseController<HomeState> {
  final AppStore store;
  final SettingsStore settings;
  List<TextEditingController> goalsControllers = [];
  bool _saving = false;

  HomeController(this.store, this.settings) : super(HomeInitial());

  static DateTime get _today => dateOnly(DateTime.now());

  double get completePercent { /* unchanged */ }

  @override
  void onInit() {
    store.addListener(reload);
    settings.addListener(reload);
    reload();
  }

  void reload() {
    if (store.loadError != null) {
      emit(HomeError(message: store.loadError.toString()));
      return;
    }
    if (!store.loaded) {
      emit(HomeLoading());
      return;
    }
    final nickname = settings.nicknameOrDefault;
    final today = _today;
    final active = store.data.activeGoalsOn(today);
    final entry = store.data.entryOn(today);
    if (active.isEmpty) {
      setGoalsControllers(const []);
      emit(HomeDataEmpty(nickname: nickname, hasMarkedToday: entry != null));
      return;
    }
    final goals = [
      for (final g in active)
        GoalModel(
          goalId: g.id,
          name: g.name,
          percentCompleted: entry?.values[g.id] ?? 0,
        ),
    ];
    setGoalsControllers(goals);
    emit(HomeData(nickname: nickname, goals: goals, hasMarkedToday: entry != null));
  }

  void setGoalsControllers(List<GoalModel> goals) { /* unchanged: dispose + rebuild */ }

  Future<void> saveData() async {
    final current = state;
    if (_saving || current is! HomeData || current.hasMarkedToday || current.goals.isEmpty) return;
    _saving = true;
    try {
      // Names typed inline are committed together with the day.
      for (var i = 0; i < current.goals.length; i++) {
        final typed = goalsControllers[i].text.trim();
        if (typed.isNotEmpty && typed != current.goals[i].name) {
          await store.renameGoal(current.goals[i].goalId, typed);
        }
      }
      await store.saveDay(_today, {
        for (final g in current.goals) g.goalId: g.percentCompleted,
      });
      // store notifies → reload() emits HomeData(hasMarkedToday: true)
    } finally {
      _saving = false;
    }
  }

  Future<void> addNewGoal() async {
    final current = state;
    if (current is! HomeData) return;
    // Preserve in-progress renames before the store-triggered rebuild.
    for (var i = 0; i < current.goals.length; i++) {
      final typed = goalsControllers[i].text.trim();
      if (typed.isNotEmpty && typed != current.goals[i].name) {
        await store.renameGoal(current.goals[i].goalId, typed);
      }
    }
    await store.addGoal('New Goal', GoalType.percent, createdAt: _today);
  }

  Future<void> removeGoal(int index) async {
    final current = state;
    if (current is! HomeData || current.hasMarkedToday) return;
    await store.archiveGoal(current.goals[index].goalId, on: _today);
  }

  @override
  void onDispose() {
    store.removeListener(reload);
    settings.removeListener(reload);
    for (final c in goalsControllers) c.dispose();
    goalsControllers = [];
    super.onDispose();
  }
}
```
Note the slider mutates `GoalModel.percentCompleted` in place; because `reload()` rebuilds `GoalModel`s from the store on every store change, a slider drag is not lost — the store only notifies on persisted mutations, not on drags. `HomePage`: `_controller = HomeController(context.read<AppStore>(), context.read<SettingsStore>());` in `initState` (allowed: `read` in initState).

- [ ] **Step 5: `CalendarController` over `AppStore`**

```dart
class CalendarController extends BaseController<CalendarState> {
  final AppStore store;
  CalendarController(this.store, super.initialState);

  @override
  void onInit() { store.addListener(reload); reload(); }

  void reload() {
    if (store.loadError != null) { emit(CalendarError(message: store.loadError.toString())); return; }
    if (!store.loaded) { emit(CalendarLoading()); return; }
    final eventList = EventList<Event>(events: {});
    for (final e in store.data.entries) {
      final active = store.data.activeGoalsOn(e.date);
      if (active.isEmpty) continue;
      final avg = active.map((g) => e.values[g.id] ?? 0).reduce((a, b) => a + b) / active.length;
      eventList.add(e.date, Event(date: e.date, dot: Container(/* unchanged, color: Utilities.activeColor(avg) */)));
    }
    final old = state;
    final selectedDay = old is CalendarData ? old.selectedDay : DateTime.now();
    emit(CalendarData(eventList: eventList, selectedDaysGoals: _goalsOn(selectedDay), selectedDay: selectedDay));
  }

  DateGoalsView? _goalsOn(DateTime day) {
    final e = store.data.entryOn(day);
    if (e == null) return null;
    return DateGoalsView(date: e.date, goals: [
      for (final g in store.data.activeGoalsOn(e.date))
        GoalModel(goalId: g.id, name: g.name, percentCompleted: e.values[g.id] ?? 0),
    ]);
  }

  void selectDay(DateTime date) {
    final current = state;
    if (current is! CalendarData) return;
    emit(CalendarData(eventList: current.eventList, selectedDaysGoals: _goalsOn(date), selectedDay: date));
  }

  @override
  void onDispose() { store.removeListener(reload); super.onDispose(); }
}

/// What the calendar panel shows for one day (replaces the old DateGoalModel).
class DateGoalsView {
  final DateTime date;
  final List<GoalModel> goals;
  const DateGoalsView({required this.date, required this.goals});
}
```
`CalendarData.selectedDaysGoals` type becomes `DateGoalsView?`; `calendar_page.dart` reads `.date`/`.goals` exactly as before. `CalendarPage.initState`: `CalendarController(context.read<AppStore>(), CalendarLoading())`.

- [ ] **Step 6: `SettingsController` over the stores**

```dart
class SettingsController extends BaseController<SettingState> {
  final AppStore store;
  final SettingsStore settings;
  SettingsController(this.store, this.settings) : super(SettingLoading());

  @override
  void onInit() { settings.addListener(reload); reload(); }
  void reload() => emit(SettingData(nickname: settings.nicknameOrDefault));

  Future<void> clearAllData() => store.clearAll();
  Future<bool> undoClearAllData() => store.undoClear();

  Future<bool> saveNickname(String? newNickname) async {
    final n = newNickname?.trim();
    if (n == null || n.isEmpty || n == settings.nickname) return true;
    await settings.setNickname(n);
    return true;
  }

  @override
  void onDispose() { settings.removeListener(reload); super.onDispose(); }
}
```
`SettingsPage.initState`: `SettingsController(context.read<AppStore>(), context.read<SettingsStore>())`. The `ErrorView` branch for `SettingError` stays (state class kept, now unreachable — fine).

- [ ] **Step 7: delete legacy**

`git rm lib/configs/local_data.dart lib/models/recovery_model.dart lib/models/date_goal_model.dart test/recovery_expiry_test.dart`. Grep `LocalData|RecoveryModel|DateGoalModel` → zero hits in lib/ and test/.

- [ ] **Step 8: rewrite `test/goal_history_test.dart`**

```dart
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

  Future<(AppStore, HomeController)> boot({List<DayEntry> entries = const []}) async {
    SharedPreferences.setMockInitialValues({'nickname': 'Alvaro'});
    final prefs = await SharedPreferences.getInstance();
    final run = Goal(id: 'run', name: 'Run', type: GoalType.percent,
        createdAt: yesterday, archivedAt: null, updatedAt: DateTime.utc(2026));
    final store = AppStore(InMemoryGoalsRepository(AppData(goals: [run], entries: entries)));
    await store.load();
    final c = HomeController(store, SettingsStore(SettingsRepository(prefs)));
    return (store, c);
  }

  test('editing today does not rewrite yesterday', () async {
    final (store, c) = await boot(entries: [
      DayEntry(date: yesterday, values: {'run': 50}, updatedAt: DateTime.utc(2026)),
    ]);
    final live = (c.state as HomeData).goals.single;
    expect(live.percentCompleted, 0); // today has no entry yet
    live.percentCompleted = 100;
    c.goalsControllers.single.text = 'Sprint';
    await c.saveData();
    expect(store.data.entryOn(yesterday)!.values['run'], 50);
    expect(store.data.entryOn(today)!.values['run'], 100);
    expect(store.data.goalById('run')!.name, 'Sprint');
    expect((c.state as HomeData).hasMarkedToday, isTrue);
  });

  test('double tap saves once', () async {
    final (store, c) = await boot();
    (c.state as HomeData).goals.single.percentCompleted = 25;
    await Future.wait([c.saveData(), c.saveData()]);
    expect(store.data.entries.length, 1);
  });

  test('archive removes from today but keeps history', () async {
    final (store, c) = await boot(entries: [
      DayEntry(date: yesterday, values: {'run': 50}, updatedAt: DateTime.utc(2026)),
    ]);
    await c.removeGoal(0);
    expect(c.state, isA<HomeDataEmpty>());
    expect(store.data.entryOn(yesterday)!.values['run'], 50);
    expect(store.data.goalById('run')!.isArchived, isTrue);
  });

  test('clearAll then undo restores the goal list', () async {
    final (store, c) = await boot();
    await store.clearAll();
    expect(c.state, isA<HomeDataEmpty>());
    await store.undoClear();
    expect((c.state as HomeData).goals.single.name, 'Run');
  });
}
```

- [ ] **Step 9: run tests + analyze → green.** Fix imports/`dart format`.
- [ ] **Step 10: Commit** — `git add -A lib test && git commit -m "refactor: controllers read AppStore/SettingsStore; LocalData removed"`

---

### Task 7: Manual migration smoke + tag

- [ ] **Step 1:** Install the previous release build (or run `master~N` with seeded data), create a few days of history, then run this branch: goals appear on Home, calendar shows history, Settings keeps nickname/theme; `adb shell run-as com.acr.consistency ls files/` (or app docs dir) shows `consistency.json` and no `userData` in prefs.
- [ ] **Step 2:** Delete all → undo works; delete all → add goal → snackbar undo tap does nothing.
- [ ] **Step 3:** `git tag phase-2-done`.

## Self-review

- Spec Seção 1: models ✔ (T1), rules for active goals ✔ (`Goal.isActiveOn`), yyyy-MM-dd ✔, upsert ✔ (`saveDay`), `GoalsRepository`/File impl with tmp+rename+.bak ✔ (T2), `SettingsRepository` keys ✔ (T4), `AppStore` mutations list ✔ (T5: `addGoal, renameGoal, setGoalType, archiveGoal, restoreGoal, saveDay, replaceAll, clearAll, undoClear`; `merge` deferred to Phase 7 import as spec places it there), migration steps 1–6 ✔ (T3; nickname/theme "migrate" = same keys reused), delete-all as `.deleted` + undo ✔, splash waits for load ✔, `LocalData.revision` replaced by store listeners ✔.
- Interfaces consistent across tasks: `store.data`, `activeGoalsOn`, `entryOn`, `goalById`, `nicknameOrDefault`, `GoalModel(goalId:…)`, `DateGoalsView`.
- Ruling to surface: "delete all" no longer wipes the nickname (profile ≠ data). Ledger it.
