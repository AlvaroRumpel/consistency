# Phase 4 — Free Editing, Goal Detail, Nav Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the approved Home (2a), goal sheet, goal detail, archived-goals list and a clean 3-tab nav; remove the "marked today" lock (today is always editable, save = upsert); allow editing any day in the last 7 days from the calendar panel; goal type (check / percent) everywhere.

**Architecture:** One reusable `DayEditorController` (store + settings + a day) drives both Home (day = today, live) and the calendar day panel (fixed day). Views are dumb: `ProgressRing`, `GoalCard`, `DayEditor` (list of cards + save/status), `GoalSheet` (bottom sheet), `GoalDetailPage`, `ArchivedGoalsPage`. Strings stay English (Phase 8 extracts to arb + PT-BR). Visuals follow the approved mocks (see Design links) using `AppTokens`/`ThemeData` only.

**Tech Stack:** Flutter 3.41 M3, `provider`. No new packages.

**Spec:** `docs/superpowers/specs/2026-08-15-consistency-v2-design.md` — Seção 3 (Home, Detalhe de meta, Settings→metas arquivadas, Navegação), fase 4. Design (approved): `home.dc.html` frames 2a, `goal-sheet.dc.html`, `goal-detail.dc.html`, `settings-archived.dc.html`, `calendar-month.dc.html` (panel only), project `b473eda8-1101-4699-a494-6390baa9a37e`; tokens `docs/superpowers/specs/2026-08-15-design-tokens.md`.

## Global Constraints

- Today is always editable; saving upserts (`AppStore.saveDay`). Past days editable iff `today-7 ≤ day ≤ today`; older = read-only.
- `check` goals store 0 or 100; `percent` goals store 0/25/50/75/100 (segmented control).
- Ring colour = `tokens.qualityFor(liveAverage)` where liveAverage = mean of on-screen values (null when no goals); centre text `NN%` + subtitle `TAP TO SAVE` (dirty or never saved) / `SAVED · TAP TO EDIT` (saved and clean). Streak badge colour = `tokens.flameFor(streak)`.
- Removing a goal = `archiveGoal` (soft). Restoring = `restoreGoal`.
- Nav: `NavigationBar` with 3 destinations Calendar · Home · Settings, Home initial, `IndexedStack` body (no PageView, no FAB).
- All new colours/text styles from `Theme.of(context)` / `context.tokens` / `context.textStyles`; no hardcoded hex; guard test `no_isdark_test` stays green.
- Lints; `flutter analyze` clean; `flutter test --concurrency=1 --reporter expanded` green; `dart format lib test`; Conventional Commits.
- Test helper `test/helpers.dart` `buildApp({prefs, data})` exists; add `pumpFrames(tester, [n])` helper (10×16 ms) there in Task 1.

---

### Task 1: `DayEditorController` (replaces `HomeController`)

**Files:**
- Create: `lib/controllers/day_editor_controller.dart`
- Delete: `lib/controllers/home_controller.dart`, `lib/models/goal_model.dart` (its 3 readers are rewritten in Tasks 3/7)
- Modify: `test/helpers.dart` (add `pumpFrames`)
- Test: `test/day_editor_controller_test.dart` (new); delete `test/goal_history_test.dart`, `test/home_engine_test.dart` (superseded — every scenario reappears below)
- Note: `lib/pages/home_page.dart`, `lib/pages/calendar_page.dart`, `lib/widgets/goals_list_view.dart`, `lib/widgets/goals_done_list_view.dart` will not compile until Task 3/7 — **this task must leave the tree compiling**, so also do the minimal edit: `home_page.dart` and `calendar_page.dart`/`goals_*_list_view.dart` are rewritten in Task 3/7; to keep Task 1 green, replace `lib/pages/home_page.dart` body with a placeholder `Center(child: Text('Home'))` and stub `calendar_controller.dart`'s `DateGoalsView.goals` as `List<GoalRow>` (see interface) — the calendar page reads `.name`/`.percentCompleted` from goals_done_list_view; change those two accessors to `.name`/`.value`. Delete `goals_list_view.dart` now (only home used it).

**Interfaces (produced):**
```dart
enum DayEditorStatus { loading, error, ready }
class GoalRow { final String goalId; final String name; final GoalType type; final double value; final int streak; }
class DayView {
  final DateTime day; final String nickname; final List<GoalRow> goals;
  final bool editable;          // within the 7-day window (always true for today)
  final bool saved;             // an entry exists for `day`
  final bool dirty;             // on-screen values differ from the saved entry (or unsaved)
  final double? average;        // mean of on-screen values, null if no goals
  final int streak, best;       // global, computed at real today
}
class DayEditorController extends BaseController<DayEditorState> {
  DayEditorController(AppStore store, SettingsStore settings, {DateTime? day, DateTime Function()? now});
  // day == null → live today (re-evaluated on every reload); day != null → fixed day
  DayEditorState get state; // sealed: DayEditorLoading | DayEditorError(message) | DayEditorReady(DayView view)
  void reload();
  void setValue(String goalId, double v);   // clamps 0..100, marks dirty, emits
  void toggle(String goalId);               // check goals: 0 <-> 100
  Future<void> save();                       // saveDay(day, values); no-op if !editable or empty; guarded against double tap
  void onDispose();
}
```

- [ ] **Step 1: failing tests**

`test/helpers.dart` — append:
```dart
import 'package:flutter_test/flutter_test.dart';

Future<void> pumpFrames(WidgetTester tester, [int n = 10]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}
```

`test/day_editor_controller_test.dart`:
```dart
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  DateTime d(int day) => DateTime(2026, 8, day);
  final u = DateTime.utc(2026);
  var now = DateTime(2026, 8, 10, 9);

  Future<(AppStore, SettingsStore, InMemoryGoalsRepository)> boot({List<DayEntry> entries = const []}) async {
    SharedPreferences.setMockInitialValues({'nickname': 'Alvaro'});
    final prefs = await SharedPreferences.getInstance();
    final run = Goal(id: 'run', name: 'Run', type: GoalType.check, createdAt: d(1), archivedAt: null, updatedAt: u);
    final read = Goal(id: 'read', name: 'Read', type: GoalType.percent, createdAt: d(1), archivedAt: null, updatedAt: u);
    final repo = InMemoryGoalsRepository(AppData(goals: [run, read], entries: entries));
    final store = AppStore(repo);
    await store.load();
    return (store, SettingsStore(SettingsRepository(prefs)), repo);
  }

  DayView view(DayEditorController c) => (c.state as DayEditorReady).view;

  setUp(() => now = DateTime(2026, 8, 10, 9));

  test('today: editable, unsaved, dirty=false until touched, average of on-screen values', () async {
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

  test('setValue/toggle mark dirty and update the live average; save upserts and clears dirty', () async {
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

  test('fixed past day inside the window is editable and saves to that day', () async {
    final (s, st, _) = await boot();
    final c = DayEditorController(s, st, day: d(5), now: () => now);
    expect(view(c).editable, isTrue);
    c.toggle('run');
    await c.save();
    expect(s.data.entryOn(d(5))!.values['run'], 100);
    expect(s.data.entryOn(d(10)), isNull);
  });

  test('day older than 7 days is read-only; setValue/save are no-ops', () async {
    final (s, st, repo) = await boot();
    final c = DayEditorController(s, st, day: d(2), now: () => now); // 8 days back
    expect(view(c).editable, isFalse);
    c.toggle('run');
    await c.save();
    expect(view(c).goals.first.value, 0);
    expect(repo.saves, 0);
    expect(DayEditorController(s, st, day: d(3), now: () => now).state, isA<DayEditorReady>());
    expect(view(DayEditorController(s, st, day: d(3), now: () => now)).editable, isTrue); // exactly 7 back
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

  test('archived goals disappear from today but a fixed past day still shows them', () async {
    final (s, st, _) = await boot(entries: [DayEntry(date: d(5), values: {'run': 100}, updatedAt: u)]);
    await s.archiveGoal('run', on: d(10));
    expect(view(DayEditorController(s, st, now: () => now)).goals.map((g) => g.goalId), ['read']);
    expect(view(DayEditorController(s, st, day: d(5), now: () => now)).goals.map((g) => g.goalId), ['run', 'read']);
  });

  test('load error surfaces', () async {
    final (_, st, _) = await boot();
    final bad = AppStore(_Throwing());
    await bad.load();
    expect(DayEditorController(bad, st, now: () => now).state, isA<DayEditorError>());
  });
}

class _Throwing extends InMemoryGoalsRepository {
  @override
  Future<AppData> load() async => throw const FormatException('boom');
}
```

- [ ] **Step 2: run → fails.**

- [ ] **Step 3: `lib/controllers/day_editor_controller.dart`**
```dart
import 'package:flutter/foundation.dart';

import '../engine/consistency_engine.dart';
import '../models/date_key.dart';
import '../models/goal.dart';
import '../state/app_store.dart';
import '../state/settings_store.dart';
import 'base_controller.dart';

const kEditWindowDays = 7;

class GoalRow {
  final String goalId;
  final String name;
  final GoalType type;
  final double value;
  final int streak;
  const GoalRow({required this.goalId, required this.name, required this.type, required this.value, required this.streak});
  GoalRow withValue(double v) => GoalRow(goalId: goalId, name: name, type: type, value: v, streak: streak);
}

class DayView {
  final DateTime day;
  final String nickname;
  final List<GoalRow> goals;
  final bool editable;
  final bool saved;
  final bool dirty;
  final double? average;
  final int streak;
  final int best;
  const DayView({
    required this.day, required this.nickname, required this.goals, required this.editable,
    required this.saved, required this.dirty, required this.average, required this.streak, required this.best,
  });
}

sealed class DayEditorState {}
class DayEditorLoading extends DayEditorState {}
class DayEditorError extends DayEditorState { final String message; DayEditorError(this.message); }
class DayEditorReady extends DayEditorState { final DayView view; DayEditorReady(this.view); }

/// Edits the values of one calendar day. `day == null` means "today", which is
/// re-evaluated on every reload so an open app rolls over at midnight.
class DayEditorController extends BaseController<DayEditorState> {
  final AppStore store;
  final SettingsStore settings;
  final DateTime? _fixedDay;
  final DateTime Function() _now;
  final Map<String, double> _draft = {}; // goalId -> unsaved value
  bool _saving = false;

  DayEditorController(this.store, this.settings, {DateTime? day, DateTime Function()? now})
      : _fixedDay = day == null ? null : dateOnly(day),
        _now = now ?? DateTime.now,
        super(DayEditorLoading());

  DateTime get today => dateOnly(_now());
  DateTime get day => _fixedDay ?? today;

  bool _isEditable(DateTime d) {
    final t = today;
    if (d.isAfter(t)) return false;
    final earliest = DateTime(t.year, t.month, t.day - kEditWindowDays);
    return !d.isBefore(earliest);
  }

  @override
  void onInit() {
    store.addListener(reload);
    settings.addListener(reload);
    reload();
  }

  void reload() {
    final err = store.loadError;
    if (err != null) { emit(DayEditorError(err.toString())); return; }
    if (!store.loaded) { emit(DayEditorLoading()); return; }

    final d = day;
    final t = today;
    if (_fixedDay == null && state is DayEditorReady && (state as DayEditorReady).view.day != d) {
      _draft.clear(); // midnight rolled over: yesterday's unsaved edits don't belong to today
    }
    final entry = store.data.entryOn(d);
    final active = store.data.activeGoalsOn(d);
    final engine = ConsistencyEngine(data: store.data, threshold: settings.threshold, today: t);

    final goals = [
      for (final g in active)
        GoalRow(
          goalId: g.id,
          name: g.name,
          type: g.type,
          value: _draft[g.id] ?? entry?.values[g.id] ?? 0,
          streak: engine.goalStreak(g),
        ),
    ];
    final dirty = entry == null
        ? _draft.isNotEmpty
        : goals.any((g) => (entry.values[g.goalId] ?? 0) != g.value);
    final avg = goals.isEmpty ? null : goals.map((g) => g.value).reduce((a, b) => a + b) / goals.length;

    emit(DayEditorReady(DayView(
      day: d,
      nickname: settings.nicknameOrDefault,
      goals: goals,
      editable: _isEditable(d),
      saved: entry != null,
      dirty: dirty,
      average: avg,
      streak: engine.globalStreak(),
      best: engine.globalBest(),
    )));
  }

  void setValue(String goalId, double v) {
    final s = state;
    if (s is! DayEditorReady || !s.view.editable) return;
    if (!s.view.goals.any((g) => g.goalId == goalId)) return;
    _draft[goalId] = v.clamp(0, 100).toDouble();
    reload();
  }

  void toggle(String goalId) {
    final s = state;
    if (s is! DayEditorReady) return;
    final row = s.view.goals.where((g) => g.goalId == goalId).firstOrNull;
    if (row == null) return;
    setValue(goalId, row.value >= 100 ? 0 : 100);
  }

  Future<void> save() async {
    final s = state;
    if (_saving || s is! DayEditorReady || !s.view.editable || s.view.goals.isEmpty) return;
    _saving = true;
    try {
      await store.saveDay(s.view.day, {for (final g in s.view.goals) g.goalId: g.value});
      _draft.clear();
      reload();
    } finally {
      _saving = false;
    }
  }

  @override
  void onDispose() {
    store.removeListener(reload);
    settings.removeListener(reload);
    super.onDispose();
  }
}
```
(`firstOrNull` needs `package:collection` — it's re-exported by Flutter's `foundation`? No: use `import 'package:collection/collection.dart';` — `collection` is already a transitive dependency of Flutter; if `flutter analyze` complains about depending on a transitive package, replace with a small loop.)

- [ ] **Step 4: keep the tree compiling** — delete `home_controller.dart`, `goal_model.dart`, `goals_list_view.dart`, the two old tests; `home_page.dart` → temporary `Center(child: Text('Home'))` (keep the class name `HomePage`); `calendar_controller.dart` `DateGoalsView.goals` → `List<GoalRow>` built with `GoalRow(goalId: g.id, name: g.name, type: g.type, value: e.values[g.id] ?? 0, streak: 0)`; `goals_done_list_view.dart` reads `.name` / `.value` (import `../controllers/day_editor_controller.dart`).
- [ ] **Step 5: run tests + analyze + format → green.**
- [ ] **Step 6: Commit** — `git add -A lib test && git commit -m "refactor: DayEditorController drives today and any past day; HomeController removed"`

---

### Task 2: Nav shell — 3 real tabs, no FAB, no PageView

**Files:**
- Modify: `lib/pages/skeleton_page.dart` (rewrite), delete `lib/controllers/skeleton_controller.dart`
- Test: `test/nav_test.dart`

- [ ] **Step 1: failing test**
```dart
import 'package:consistency/pages/calendar_page.dart';
import 'package:consistency/pages/home_page.dart';
import 'package:consistency/pages/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  testWidgets('three tabs, home first, no FAB', (tester) async {
    await tester.pumpWidget(await buildApp());
    await pumpFrames(tester);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.byType(HomePage), findsOneWidget);
    await tester.tap(find.text('Calendar'));
    await pumpFrames(tester);
    expect(find.byType(CalendarPage), findsOneWidget);
    await tester.tap(find.text('Settings'));
    await pumpFrames(tester);
    expect(find.byType(SettingsPage), findsOneWidget);
    expect(find.byType(NavigationDestination), findsNWidgets(3));
  });
}
```
- [ ] **Step 2: run → fails** (finds 0/… or FAB present).
- [ ] **Step 3: `lib/pages/skeleton_page.dart`** — full content:
```dart
import 'package:flutter/material.dart';

import 'calendar_page.dart';
import 'home_page.dart';
import 'settings_page.dart';

class SkelentonPage extends StatefulWidget {
  const SkelentonPage({super.key});
  @override
  State<SkelentonPage> createState() => _SkelentonPageState();
}

class _SkelentonPageState extends State<SkelentonPage> {
  int _index = 1;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: _index,
          children: const [CalendarPage(), HomePage(), SettingsPage()],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.calendar_month_outlined), selectedIcon: Icon(Icons.calendar_month), label: 'Calendar'),
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}
```
Delete `lib/controllers/skeleton_controller.dart`. Grep for `SkelentonPage` users (main.dart, splash) — unchanged.
- [ ] **Step 4: tests + analyze + format → green** (`settings_threshold_test` taps 'Settings' — still works; `splash_navigation_test` finds `SkelentonPage`).
- [ ] **Step 5: Commit** — `git commit -am "feat: clean 3-tab NavigationBar shell (no FAB, no PageView)"` (add the deleted file with `git add -A lib test`).

---

### Task 3: Home per design 2a — `ProgressRing`, `GoalCard`, `DayEditor`

**Files:**
- Create: `lib/widgets/progress_ring.dart`, `lib/widgets/goal_card.dart`, `lib/widgets/day_editor.dart`, `lib/widgets/streak_badge.dart`
- Rewrite: `lib/pages/home_page.dart`
- Delete: `lib/widgets/add_day_button.dart`, `lib/configs/messages_mixin.dart` if unused (grep), keep `error_view.dart`
- Test: `test/home_page_test.dart`

**Interfaces (produced):**
```dart
class ProgressRing extends StatelessWidget { ProgressRing({required double? average, required bool saved, required bool dirty, required VoidCallback? onTap, double size = 200}); }
class StreakBadge extends StatelessWidget { StreakBadge({required int streak}); }   // flame icon (tier colour) + number
class GoalCard extends StatelessWidget { GoalCard({required GoalRow row, required bool enabled, required VoidCallback? onTapName, required ValueChanged<double> onChanged}); }
class DayEditor extends StatelessWidget { DayEditor({required DayEditorController controller, required Widget Function(BuildContext, DayView) header, Widget? footer, void Function(GoalRow)? onGoalTap}); }
```
- `GoalCard`: rounded 28 container `colorScheme.surfaceContainer` (no border), name (tap → `onTapName`), caption `'$streak days'` (or `'$streak day'` when 1), control: `check` → 28px circular check (`Icons.check` on primary when 100); `percent` → `SegmentedButton<int>` with segments 0/25/50/75/100, `showSelectedIcon: false`, selected fill = `tokens.qualityFor(value)` for value>0 (via `WidgetStateProperty`), disabled when `!enabled`.
- `ProgressRing`: `CustomPaint` arc: track `surfaceContainerLow` 14px stroke, progress `tokens.qualityFor(average)` sweep = average/100 (0 when null), centre `'${average?.round() ?? 0}%'` (44/700) + subtitle caption uppercase: `!saved || dirty ? 'TAP TO SAVE' : 'SAVED · TAP TO EDIT'`; `InkWell` circle → onTap. Semantics label `'Save today'`.
- `DayEditor`: `ValueListenableBuilder` on `controller.stateNotifier`; loading → `CircularProgressIndicator`; error → `ErrorView(onRetry: controller.reload)`; ready → `ListView`/`Column` of `header(context, view)`, section label `'TODAY'S GOALS'` (or `'GOALS'` for a fixed day) and one `GoalCard` per row (`enabled: view.editable`, `onChanged: (v) => controller.setValue(row.goalId, v)`; check → `controller.toggle`), then `footer`.

- [ ] **Step 1: failing widget test**

`test/home_page_test.dart`:
```dart
import 'package:consistency/models/app_data.dart';
import 'package:consistency/models/goal.dart';
import 'package:consistency/widgets/goal_card.dart';
import 'package:consistency/widgets/progress_ring.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  final u = DateTime.utc(2026);
  final today = DateTime.now();
  AppData seed() => AppData(goals: [
        Goal(id: 'run', name: 'Run', type: GoalType.check, createdAt: today, archivedAt: null, updatedAt: u),
        Goal(id: 'read', name: 'Read', type: GoalType.percent, createdAt: today, archivedAt: null, updatedAt: u),
      ], entries: const []);

  testWidgets('home renders ring, greeting, cards; toggling and saving flips the ring subtitle', (tester) async {
    await tester.pumpWidget(await buildApp(prefs: {'nickname': 'Alvaro'}, data: seed()));
    await pumpFrames(tester);
    expect(find.textContaining('Alvaro'), findsOneWidget);
    expect(find.byType(ProgressRing), findsOneWidget);
    expect(find.byType(GoalCard), findsNWidgets(2));
    expect(find.text('TAP TO SAVE'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('check-run')));
    await pumpFrames(tester);
    expect(find.text('50%'), findsOneWidget);

    await tester.tap(find.byType(ProgressRing));
    await pumpFrames(tester);
    expect(find.text('SAVED · TAP TO EDIT'), findsOneWidget);

    await tester.tap(find.text('75').last);
    await pumpFrames(tester);
    expect(find.text('TAP TO SAVE'), findsOneWidget); // dirty again
    expect(find.text('88%'), findsOneWidget); // (100+75)/2 = 87.5 → 88
  });

  testWidgets('empty home shows a "New goal" pill', (tester) async {
    await tester.pumpWidget(await buildApp());
    await pumpFrames(tester);
    expect(find.text('New goal'), findsOneWidget);
    expect(find.byType(GoalCard), findsNothing);
  });
}
```

- [ ] **Step 2: run → fails.**
- [ ] **Step 3: widgets** — implement `progress_ring.dart` (CustomPainter drawing background arc + `sweepAngle = 2π·(average??0)/100` starting at -π/2, `StrokeCap.round`), `streak_badge.dart` (`Icon(Icons.local_fire_department, color: context.tokens.flameFor(streak))` + `Text('$streak')`), `goal_card.dart` (check control gets `key: ValueKey('check-${row.goalId}')`), `day_editor.dart` per interface. Keep each file < 150 lines.
- [ ] **Step 4: `home_page.dart`** — `HomePageState` creates `DayEditorController(context.read<AppStore>(), context.read<SettingsStore>())`, keeps the `WidgetsBindingObserver` resume→reload; body = `Padding(24) → DayEditor(controller, header: (ctx, v) => Column[ Row[ Text('Hi, ' + nickname big) , Spacer, StreakBadge(v.streak) ], ProgressRing(average: v.average, saved: v.saved, dirty: v.dirty, onTap: v.editable ? controller.save : null), Text('BEST ${v.best} DAYS' caption centred) ], footer: OutlinedButton.icon(Icons.add, 'New goal', onPressed: () => showGoalSheet(context)) )`. Until Task 4 exists, `showGoalSheet` is a stub in `lib/widgets/goal_sheet.dart` that returns immediately (Task 4 fills it) — create the file now with the signature `Future<void> showGoalSheet(BuildContext context, {Goal? goal}) async {}`.
- [ ] **Step 5: delete `add_day_button.dart` (+ `messages_mixin.dart` only if grep shows no user; settings still uses it for the undo snackbar — keep).**
- [ ] **Step 6: tests + analyze + format → green.**
- [ ] **Step 7: Commit** — `git add -A lib test && git commit -m "feat: home per design — progress ring, goal cards, live editing of today"`

---

### Task 4: `GoalSheet` — new / edit / archive

**Files:**
- Modify: `lib/widgets/goal_sheet.dart` (real implementation)
- Test: `test/goal_sheet_test.dart`

**Interfaces:** `Future<void> showGoalSheet(BuildContext context, {Goal? goal})` — modal bottom sheet (rounded top 28, `surfaceContainer`), title `'New goal'` / `'Edit goal'`, `TextFormField` name (max 50, required), `SegmentedButton<GoalType>` "Done / not done" | "Percent 0–100", caption per type, primary `FilledButton` `'Add goal'` / `'Save changes'`; edit mode adds `TextButton` `'Archive goal'` in `colorScheme.error` (confirm dialog → `store.archiveGoal(id)`, pop). Uses `context.read<AppStore>()`.

- [ ] **Step 1: failing widget test**
```dart
testWidgets('new goal via sheet appears as a card; edit renames and changes type', (tester) async {
  await tester.pumpWidget(await buildApp());
  await pumpFrames(tester);
  await tester.tap(find.text('New goal'));
  await pumpFrames(tester);
  await tester.enterText(find.byType(TextFormField), 'Meditate');
  await tester.tap(find.text('Percent 0–100'));
  await tester.tap(find.text('Add goal'));
  await pumpFrames(tester);
  expect(find.text('Meditate'), findsOneWidget);
  expect(find.text('25'), findsOneWidget); // segmented control present → percent type
});
```
(second test: open sheet for the goal (via `showGoalSheet(ctx, goal: g)` on the app's context obtained with `tester.element(find.text('Meditate'))`), rename to 'Breathe', tap 'Save changes' → 'Breathe' visible; tap 'Archive goal' → confirm → card gone.)
- [ ] **Step 2: run → fails.** — [ ] **Step 3: implement.** — [ ] **Step 4: green.** — [ ] **Step 5: Commit** `feat: goal sheet (create, edit, archive)`.

---

### Task 5: `GoalDetailPage`

**Files:**
- Create: `lib/pages/goal_detail_page.dart`
- Modify: `lib/pages/home_page.dart` (`onGoalTap` → `Navigator.push(GoalDetailPage(goalId))`)
- Test: `test/goal_detail_test.dart`

**Content (design `goal-detail.dc.html`):** AppBar back + name + edit icon (→ `showGoalSheet(goal)`); 2×2 stat tiles (`surfaceContainer`, radius 28): "Current streak · N days" (flame in tier colour), "Record · N days", "Last 7 days · NN%", "Last 30 days · NN%" (from `ConsistencyEngine(goalStreak/goalBest/goalRate(7)/goalRate(30))`); section `'LAST 30 DAYS'` + 30 squares (14×14, 4 gap, 10 per row) coloured `tokens.qualityFor(value)` (null when no entry / not active) + legend; card `'Type · Percent 0–100'` with the segmented control shown disabled + caption `'Change it with the edit button'`; bottom: archived ? `FilledButton.icon(unarchive, 'Restore goal')` : `OutlinedButton.icon(archive, 'Archive goal', error colour)` + caption. Archived variant shows a top banner `'Archived on dd/MM/yyyy'`. Page watches `context.watch<AppStore>()` and `SettingsStore` for live values; if the goal id disappears (shouldn't) pop.
- [ ] **Step 1: failing test** — seed a percent goal with 3 entries; pump `GoalDetailPage(goalId)` inside `buildApp`'s providers (push it via a `Navigator` in the test, or expose `MaterialApp(home: ...)` with the same providers using a small `wrap()` helper added to `test/helpers.dart`); expect `'Current streak'`, `'Record'`, `'Last 7 days'`, `'Last 30 days'` texts, 30 squares (`find.byKey(ValueKey('hm-<i>'))` count 30), tap `'Archive goal'` → confirm → `'Restore goal'` visible.
- [ ] **Step 2–5:** run → fail, implement, green, commit `feat: goal detail page (stats, 30-day strip, archive/restore)`.

---

### Task 6: Archived goals in Settings

**Files:**
- Create: `lib/pages/archived_goals_page.dart`
- Modify: `lib/pages/settings_page.dart` (row `'Archived goals'` with count → push)
- Test: `test/archived_goals_test.dart`

Page per `settings-archived.dc.html`: AppBar `'Archived goals'`; list of `surfaceContainer` cards: name, caption `'archived on dd/MM/yyyy · record N days'`, trailing `OutlinedButton('Restore')` → `store.restoreGoal(id)`; empty state icon `Icons.inventory_2_outlined` + `'No archived goals'` + caption. Test: seed one archived goal → row shows; tap Restore → list empty state; store goal `archivedAt == null`.
- Commit `feat: archived goals list with restore`.

---

### Task 7: Calendar day panel — edit last 7 days

**Files:**
- Modify: `lib/controllers/calendar_controller.dart` (drop `DateGoalsView`; expose `selectedDay` only), `lib/pages/calendar_page.dart` (panel = `DayEditor` for the selected day), delete `lib/widgets/goals_done_list_view.dart`
- Test: `test/calendar_panel_test.dart`

Panel: `DayEditorController(store, settings, day: selectedDay)` recreated when the selected day changes (keyed `StatefulWidget` `_DayPanel(day)`); header = `Text(DateFormat-less: '${weekdayName}, ${d.day} ${monthName}')` + caption `average != null ? '${avg}% · ${consistent ? 'consistent day' : 'below target'}' : 'no entry'`; footer: `editable ? FilledButton('Save dd/MM')` : caption `'Read-only — only the last 7 days can be edited'`. Cards disabled when `!editable`. Keep the existing `CalendarCarousel` grid (Phase 5 replaces it). Test: seed entry 3 days ago; open Calendar; controller.selectDay(that day) via `tester.state` or tap; expect cards + `'Save '` button; select a day 10 days back → read-only caption, no button.
- Commit `feat: edit any of the last 7 days from the calendar panel`.

---

### Task 8: Smoke + tag

- [ ] Device: Home 2a look in light/dark; ring tap saves & flips subtitle; edit after save; add goal (sheet), rename/type change, archive (detail + sheet), restore (settings); calendar panel edits a day 3 back, refuses 10 back; nav tabs keep state (IndexedStack). `git tag phase-4-done`.

## Self-review

- Spec fase 4: trava removida (T1/T3), tipo de meta (T3/T4), arquivar/restaurar (T4/T5/T6), detalhe (T5), nav limpa (T2), edição ≤7d (T7). Design frames all mapped (2a, sheet, detail, archived, calendar panel).
- Names: `DayEditorController(store, settings, {day, now})`, `DayView`, `GoalRow`, `DayEditor(controller, header, footer, onGoalTap)`, `showGoalSheet(context, {goal})`, `GoalDetailPage(goalId)`, `ArchivedGoalsPage`. Tests use `pumpFrames` + `buildApp`.
- Ruling to ledger: strings in English until Phase 8; `Utilities.activeColor` remains only for the calendar dots (Phase 5 deletes).
