# Phase 7 — Export / Import + Onboarding Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The user can export a backup file, import one (replace or merge, with a confirmation that says what will happen), and a first-run onboarding collects the nickname and the first goal instead of dropping them on an empty Home.

**Architecture:** `BackupCodec` (pure: `AppData ↔ JSON string`, validation, `merge(a, b)` by `updatedAt`) has no plugins; `BackupService` does the platform I/O (`share_plus` for export, `file_picker` for import) behind an interface so widget tests use a fake. Onboarding is a normal route decided by `SettingsStore.onboardingDone` + whether any goal exists.

**Tech Stack:** Flutter 3.41, `provider`; new: `share_plus`, `file_picker`.

**Spec:** `docs/superpowers/specs/2026-08-15-consistency-v2-design.md` — Seção 4 (Export/import), Seção 3 (Home vazia/onboarding), fase 7. Design (approved): `settings-import.dc.html` (import dialog + delete-all confirm + undo snackbar), `home-empty.dc.html` (onboarding + empty home), project `b473eda8-1101-4699-a494-6390baa9a37e`.

## Global Constraints

- Backup file = exactly the on-disk `AppData` JSON (`schemaVersion: 2`), named `consistency-YYYY-MM-DD.json`.
- Import validates before touching anything: it must parse, carry `schemaVersion == 2`, and have `goals`/`entries` arrays. Anything else → error snackbar, nothing changes.
- **Replace** = `AppStore.replaceAll(imported)`. **Merge** = goals by `id` (higher `updatedAt` wins; unknown ids added), entries by `date` (higher `updatedAt` wins, whole entry, not per goal), result sorted; then `replaceAll(merged)`.
- Import dialog shows the file name and what it contains (`N goals · M days`) before the choice, per the design.
- Onboarding shows when `!settings.onboardingDone && store.data.goals.isEmpty`; it collects a nickname (optional, skippable) and one goal (name + type), then `setOnboardingDone(true)` and lands on Home. It must never show again after that.
- Platform I/O only inside `BackupService`; `BackupCodec` is pure and unit-tested; widget tests inject `FakeBackupService`.
- English strings; no hardcoded colours (guard test); lints; `flutter analyze` clean; `flutter test --concurrency=1 --reporter expanded` green; `dart format lib test`; Conventional Commits; `flutter build apk --debug` must still succeed at the end of Task 1.

---

### Task 1: deps + `BackupCodec` (pure)

**Files:**
- Modify: `pubspec.yaml` (`share_plus: ^10.1.2`, `file_picker: ^8.1.6`)
- Create: `lib/data/backup_codec.dart`
- Test: `test/backup_codec_test.dart`

**Interfaces (produced):**
```dart
class BackupSummary { final int goals; final int days; }
class BackupCodec {
  static String encode(AppData data);                 // pretty-ish JSON, schemaVersion 2
  static AppData decode(String json);                 // throws FormatException on anything invalid
  static BackupSummary summarize(AppData data);
  static AppData merge(AppData current, AppData incoming);
  static String fileName(DateTime day);               // 'consistency-2026-08-17.json'
}
```

- [ ] **Step 1: failing tests**

`test/backup_codec_test.dart`:
```dart
import 'package:consistency/data/backup_codec.dart';
import 'package:consistency/models/app_data.dart';
import 'package:consistency/models/date_key.dart';
import 'package:consistency/models/day_entry.dart';
import 'package:consistency/models/goal.dart';
import 'package:flutter_test/flutter_test.dart';

DateTime d(int day) => DateTime(2026, 8, day);
Goal goal(String id, {String name = 'G', DateTime? updated, int created = 1}) => Goal(
      id: id, name: name, type: GoalType.check, createdAt: d(created),
      archivedAt: null, updatedAt: updated ?? DateTime.utc(2026, 8, 1),
    );
DayEntry entry(int day, Map<String, double> v, {DateTime? updated}) =>
    DayEntry(date: d(day), values: v, updatedAt: updated ?? DateTime.utc(2026, 8, day));

void main() {
  test('encode → decode round-trips', () {
    final data = AppData(goals: [goal('a')], entries: [entry(3, {'a': 100})]);
    final back = BackupCodec.decode(BackupCodec.encode(data));
    expect(back.goals.single.id, 'a');
    expect(back.entries.single.values, {'a': 100.0});
  });

  test('decode rejects junk, wrong schema and wrong shape', () {
    expect(() => BackupCodec.decode('{not json'), throwsFormatException);
    expect(() => BackupCodec.decode('{"schemaVersion":1,"goals":[],"entries":[]}'), throwsFormatException);
    expect(() => BackupCodec.decode('{"schemaVersion":2}'), throwsFormatException);
    expect(() => BackupCodec.decode('[]'), throwsFormatException);
  });

  test('summarize counts goals and days', () {
    final s = BackupCodec.summarize(AppData(goals: [goal('a'), goal('b')], entries: [entry(1, {}), entry(2, {})]));
    expect(s.goals, 2);
    expect(s.days, 2);
  });

  test('fileName uses the calendar day', () {
    expect(BackupCodec.fileName(DateTime(2026, 8, 7, 23)), 'consistency-2026-08-07.json');
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
      final current = AppData(goals: [goal('a', name: 'mine', updated: DateTime.utc(2026, 8, 9))], entries: const []);
      final incoming = AppData(goals: [goal('a', name: 'theirs', updated: DateTime.utc(2026, 8, 2))], entries: const []);
      expect(BackupCodec.merge(current, incoming).goalById('a')!.name, 'mine');
    });

    test('entries merge by date, newest updatedAt wins the whole day', () {
      final current = AppData(goals: [goal('a')], entries: [
        entry(3, {'a': 50}, updated: DateTime.utc(2026, 8, 3, 10)),
        entry(4, {'a': 100}),
      ]);
      final incoming = AppData(goals: [goal('a')], entries: [
        entry(3, {'a': 100}, updated: DateTime.utc(2026, 8, 3, 20)),
        entry(5, {'a': 25}),
      ]);
      final m = BackupCodec.merge(current, incoming);
      expect(m.entries.map((e) => dateKey(e.date)), ['2026-08-03', '2026-08-04', '2026-08-05']);
      expect(m.entryOn(d(3))!.values['a'], 100);
      expect(m.entryOn(d(4))!.values['a'], 100);
      expect(m.entryOn(d(5))!.values['a'], 25);
    });

    test('merging with empty data is a no-op either way', () {
      final data = AppData(goals: [goal('a')], entries: [entry(1, {'a': 100})]);
      expect(BackupCodec.merge(data, AppData.empty).goals.length, 1);
      expect(BackupCodec.merge(AppData.empty, data).entries.length, 1);
    });
  });
}
```

- [ ] **Step 2: run → fails.** — [ ] **Step 3: deps** (`flutter pub get`) **+ implement `BackupCodec`** (reuse `AppData.toJson/fromJson`; `decode` wraps any error in `FormatException`). — [ ] **Step 4: `flutter analyze`, full tests, `flutter build apk --debug`** (the two new plugins must not break the Android build). — [ ] **Step 5: Commit** `feat: backup codec with validation and merge`.

---

### Task 2: `BackupService` (platform) + fake

**Files:**
- Create: `lib/data/backup_service.dart`, `lib/data/fake_backup_service.dart`
- Test: `test/fake_backup_service_test.dart`

**Interfaces:**
```dart
class PickedBackup { final String name; final String contents; }
abstract class BackupService {
  Future<void> exportBackup(String fileName, String contents);  // writes a temp file + share sheet
  Future<PickedBackup?> pickBackup();                            // null when the user cancels
}
class PlatformBackupService implements BackupService { ... }     // share_plus + file_picker
class FakeBackupService implements BackupService {
  PickedBackup? nextPick; String? lastExportName; String? lastExportContents; bool throwOnPick = false;
}
```
- `exportBackup`: write to `${(await getTemporaryDirectory()).path}/$fileName`, then `SharePlus.instance.share(ShareParams(files: [XFile(path)], fileNameOverrides: [fileName]))` — check the installed `share_plus` API before writing (v10 vs v11 differ; adapt and report).
- `pickBackup`: `FilePicker.platform.pickFiles(type: FileType.any, withData: true)`; return `PickedBackup(name: f.name, contents: utf8.decode(f.bytes!))`; `null` on cancel.

- [ ] **Step 1: fake test** (records export, returns the queued pick, throws when asked). — [ ] **Step 2–5:** run → fail, implement, green, commit `feat: backup service over share_plus and file_picker`.

---

### Task 3: Settings — export & import flows

**Files:**
- Modify: `lib/pages/settings_page.dart` (DATA section: `Export backup`, `Import backup`), `lib/main.dart` + `test/helpers.dart` (provide `BackupService`, inject the fake in tests)
- Create: `lib/widgets/import_dialog.dart`
- Test: `test/backup_flow_test.dart`

Flows:
- **Export**: build `BackupCodec.encode(store.data)` + `fileName(today)`, call `exportBackup`; snackbar `Backup ready to share.` on success, `Couldn't export the backup.` on failure.
- **Import**: `pickBackup()` → cancel = nothing; decode → on `FormatException` snackbar `That file isn't a Consistency backup.`; on success show `ImportDialog(fileName, summary)` per the design: title `Import backup`, body `<name> · N goals · M days`, two option tiles `Replace everything — deletes your current data` / `Merge — keeps both; the newest wins` (Merge preselected), actions `Cancel` / `Import`. Then `replaceAll(imported)` or `replaceAll(BackupCodec.merge(store.data, imported))`, snackbar `Backup imported.`
- Both rows live in the existing DATA section next to `Delete all data`.

- [ ] **Step 1: failing widget tests** — with a fake queued with a valid backup: Settings → `Import backup` → dialog shows `2 goals · 3 days` → choose Replace → store holds the imported data; queue an invalid file → error snackbar, store unchanged; tap `Export backup` → `lastExportName` matches `consistency-<today>.json` and the contents decode back to the store's data.
- [ ] **Step 2–5:** run → fail, implement, green, commit `feat: export and import backups from settings`.

---

### Task 4: Onboarding

**Files:**
- Create: `lib/pages/onboarding_page.dart`
- Modify: `lib/main.dart` (route `/onboarding`; splash decides where to go), `lib/pages/splash_page.dart`
- Test: `test/onboarding_test.dart`

Content (design `home-empty.dc.html`): title `Welcome to Consistency`, subtitle `Mark your goals every day and keep the streak.`, card with `What should we call you?` (text field, placeholder `Your name`), heading `YOUR FIRST GOAL`, field `Goal name` (placeholder `e.g. Run 5 km`), `SegmentedButton<GoalType>` `Done / not done` | `Percent 0–100` with a caption per type, and a primary `Start` button (disabled until the goal name is non-empty). `Start` → `settings.setNickname(name)` (skip when blank), `store.addGoal(goalName, type)`, `settings.setOnboardingDone(true)`, then `Navigator.pushReplacementNamed('/manager')`.
Splash: after the store is ready, go to `/onboarding` when `!settings.onboardingDone && store.data.goals.isEmpty`, else `/manager`. (A user who already has goals — e.g. after the v1 migration — must never see onboarding: mark `onboardingDone` true on the spot in that case.)

- [ ] **Step 1: failing tests** — fresh install (`prefs {}`, no data) lands on `OnboardingPage`; filling the name + goal and tapping `Start` creates the goal, stores the nickname, sets the flag and shows Home; an install that already has goals goes straight to Home and `onboardingDone` becomes true; a fresh install that has `onboardingDone: true` also goes to Home.
- [ ] **Step 2–5:** run → fail, implement, green, commit `feat: first-run onboarding collects the nickname and first goal`.

---

### Task 5: Smoke + tag

- [ ] Device: export → share sheet appears, file lands in Drive/Files with the right name; import that file on a fresh install → data appears (Replace) and again with Merge on top of existing data; import a random .txt → error snackbar, nothing lost; first run of a clean install shows onboarding once. `git tag phase-7-done`.

## Self-review

- Spec Seção 4 export/import: share ✔ (T2/T3), validate ✔ (T1/T3), replace|merge dialog ✔ (T3), merge rule `updatedAt` maior vence ✔ (T1), parse inválido → snackbar ✔ (T3). Seção 3 onboarding ✔ (T4), never again ✔ (flag + migration case).
- Names: `BackupCodec.{encode,decode,summarize,merge,fileName}`, `BackupSummary{goals,days}`, `BackupService.{exportBackup,pickBackup}`, `PickedBackup{name,contents}`, `FakeBackupService`, `ImportDialog`, `OnboardingPage`.
- Ruling to ledger: merge resolves whole days (not per-goal values) — simpler and matches "vence o mais recente" in the spec.
