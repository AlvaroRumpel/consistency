# Phase 3 — Consistency Engine Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A pure, heavily-tested `ConsistencyEngine` (day quality, global streak, per-goal streak, records, rates, heatmap) driven by the user's threshold; Home shows the global streak and per-goal streaks and colours the mark button from the engine; Settings exposes the threshold; the app notices a day rollover.

**Architecture:** `lib/engine/consistency_engine.dart` depends only on `lib/models/*` (no Flutter). Controllers build an engine per reload from `store.data`, `settings.threshold`, and an injectable `now`. UI additions are minimal placeholders (Phase 4 restyles them to the approved design).

**Tech Stack:** Flutter 3.41, `provider`. No new packages.

**Spec:** `docs/superpowers/specs/2026-08-15-consistency-v2-design.md` — Seção 2 (engine), fase 3.

## Global Constraints

- Rules (verbatim from spec): `isGoalDone(check, v) = v >= 100`; `isGoalDone(percent, v) = v >= threshold`. `dayAverage(d)` = mean over goals active on `d` of `(entry.values[id] ?? 0)`; **null** when no active goals OR no entry that day. `isDayConsistent(d) = avg != null && avg >= threshold`. Global streak at `today`: largest k with `today-1 … today-k` all consistent, **skipping days with no active goal** (they neither count nor break); +1 if `today` consistent. Per-goal streak: same over days the goal is active, using `isGoalDone(goal, entry?.values[id] ?? 0)`; a day with no entry is not done. Rates: `done / activeDays` over the last N calendar days ending today (0 if no active days). Heatmap: `date → dayAverage` for every day of the year up to today.
- Threshold: `SettingsStore.threshold` (int 0..100, default 50).
- No Flutter imports in `lib/engine/`.
- Lints `prefer_single_quotes`, `prefer_relative_imports` (lib); `flutter analyze` clean; `flutter test --concurrency=1 --reporter expanded` green; `dart format lib test`; Conventional Commit subjects.

---

### Task 1: `ConsistencyEngine` (pure) + tabled tests

**Files:**
- Create: `lib/engine/consistency_engine.dart`
- Test: `test/consistency_engine_test.dart`

**Interfaces (produced):**
```dart
class ConsistencyEngine {
  ConsistencyEngine({required AppData data, required int threshold, required DateTime today});
  final AppData data; final int threshold; final DateTime today; // today normalized to a calendar day
  bool isGoalDone(Goal g, double value);
  double? dayAverage(DateTime day);
  bool isDayConsistent(DateTime day);
  int globalStreak(); int globalBest();
  int goalStreak(Goal g); int goalBest(Goal g);
  double goalRate(Goal g, int lastNDays);      // 0..1
  Map<DateTime, double?> heatmap(int year);    // Jan 1 .. min(Dec 31, today)
}
```

- [ ] **Step 1: failing tests**

`test/consistency_engine_test.dart`:
```dart
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
      expect(eng([goal('x', GoalType.check, created: 8)], [entry(5, {})]).dayAverage(d(5)), isNull);
    });
    test('missing values count as 0; consistent at threshold', () {
      final e = eng([a, b], [entry(5, {'a': 100})]);
      expect(e.dayAverage(d(5)), 50);
      expect(e.isDayConsistent(d(5)), isTrue);
      expect(eng([a, b], [entry(5, {'a': 75})], threshold: 60).isDayConsistent(d(5)), isFalse);
    });
    test('archived goals are excluded from the day they are archived on', () {
      final e = eng([a, goal('b', GoalType.check, archived: 5)], [entry(5, {'a': 100})]);
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
      expect(eng([a], [entry(10, {'a': 100})]).globalStreak(), 1);
      expect(eng([a], [entry(10, {'a': 0})]).globalStreak(), 0);
    });
    test('yesterday..3 days consistent, today untouched → 3 (today does not break)', () {
      expect(eng([a], [entry(7, {'a': 100}), entry(8, {'a': 100}), entry(9, {'a': 100})]).globalStreak(), 3);
    });
    test('gap yesterday breaks even if earlier days were consistent', () {
      expect(eng([a], [entry(7, {'a': 100}), entry(8, {'a': 100}), entry(10, {'a': 100})]).globalStreak(), 1);
    });
    test('days before the first goal existed neither count nor break', () {
      final g = goal('g', GoalType.check, created: 8);
      expect(eng([g], [entry(8, {'g': 100}), entry(9, {'g': 100})]).globalStreak(), 2);
    });
    test('a day with no active goal in the middle is skipped, not broken', () {
      // g1 active 1..5 (archived on 6), g2 active from 7 → day 6 has no goals.
      final g1 = goal('g1', GoalType.check, archived: 6), g2 = goal('g2', GoalType.check, created: 7);
      final e = eng([g1, g2], [entry(4, {'g1': 100}), entry(5, {'g1': 100}), entry(7, {'g2': 100}), entry(8, {'g2': 100}), entry(9, {'g2': 100})]);
      expect(e.globalStreak(), 5);
    });
    test('threshold 100 needs everything done', () {
      final p = goal('p', GoalType.percent);
      expect(eng([p], [entry(9, {'p': 75})], threshold: 100).globalStreak(), 0);
      expect(eng([p], [entry(9, {'p': 100})], threshold: 100).globalStreak(), 1);
    });
  });

  group('globalBest', () {
    final a = goal('a', GoalType.check);
    test('best run anywhere in history, including a run ending today', () {
      final e = eng([a], [
        entry(1, {'a': 100}), entry(2, {'a': 100}), entry(3, {'a': 100}), // 3
        entry(5, {'a': 100}), // 1
        entry(9, {'a': 100}), entry(10, {'a': 100}), // 2 (current)
      ]);
      expect(e.globalBest(), 3);
      expect(e.globalStreak(), 2);
    });
    test('best is at least the current streak', () {
      expect(eng([a], [entry(9, {'a': 100}), entry(10, {'a': 100})]).globalBest(), 2);
    });
  });

  group('per-goal streak / best / rate', () {
    final c = goal('c', GoalType.check), p = goal('p', GoalType.percent);
    final e = eng([c, p], [
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
      final e2 = eng([late], [entry(9, {'l': 100})]);
      expect(e2.goalRate(late, 7), closeTo(1 / 2, 1e-9)); // active on 9,10; done on 9
      expect(eng([goal('z', GoalType.check, created: 12)], []).goalRate(goal('z', GoalType.check, created: 12), 7), 0);
    });
    test('archived goal streak freezes at archive date', () {
      final g = goal('g', GoalType.check, archived: 9);
      final e3 = eng([g], [entry(7, {'g': 100}), entry(8, {'g': 100})]);
      expect(e3.goalStreak(g), 2);
    });
  });

  group('heatmap', () {
    test('one key per day up to today, null where no data', () {
      final a = goal('a', GoalType.check);
      final e = eng([a], [entry(3, {'a': 100})]);
      final m = e.heatmap(2026);
      expect(m.length, DateTime(2026, 8, 10).difference(DateTime(2026, 1, 1)).inDays + 1);
      expect(m[DateTime(2026, 8, 3)], 100);
      expect(m[DateTime(2026, 8, 4)], isNull);
      expect(m.containsKey(DateTime(2026, 8, 11)), isFalse);
    });
  });
}
```

- [ ] **Step 2: run → fails** (`Target of URI doesn't exist`).

- [ ] **Step 3: `lib/engine/consistency_engine.dart`**
```dart
import '../models/app_data.dart';
import '../models/date_key.dart';
import '../models/day_entry.dart';
import '../models/goal.dart';

/// Pure rules for "how consistent am I". No Flutter, no I/O.
///
/// Rule B for streaks: yesterday backwards must be consistent; a day with
/// no entry breaks; today only adds. Days on which no goal is active are
/// skipped (they neither count nor break).
class ConsistencyEngine {
  final AppData data;
  final int threshold;
  final DateTime today;
  final Map<DateTime, DayEntry> _byDay;
  final DateTime? _firstDay; // earliest goal.createdAt, or null

  ConsistencyEngine({
    required this.data,
    required this.threshold,
    required DateTime today,
  })  : today = dateOnly(today),
        _byDay = {for (final e in data.entries) e.date: e},
        _firstDay = data.goals.isEmpty
            ? null
            : data.goals.map((g) => g.createdAt).reduce((a, b) => a.isBefore(b) ? a : b);

  bool isGoalDone(Goal g, double value) => switch (g.type) {
        GoalType.check => value >= 100,
        GoalType.percent => value >= threshold,
      };

  double? dayAverage(DateTime day) {
    final d = dateOnly(day);
    final entry = _byDay[d];
    if (entry == null) return null;
    final active = data.activeGoalsOn(d);
    if (active.isEmpty) return null;
    var sum = 0.0;
    for (final g in active) {
      sum += entry.values[g.id] ?? 0;
    }
    return sum / active.length;
  }

  bool isDayConsistent(DateTime day) {
    final avg = dayAverage(day);
    return avg != null && avg >= threshold;
  }

  bool _hasActiveGoals(DateTime d) => data.activeGoalsOn(d).isNotEmpty;

  /// Walks back from [from] while [ok] holds on days where [inUniverse] is
  /// true; days outside the universe are skipped. Stops before _firstDay.
  int _runBack(DateTime from, bool Function(DateTime) inUniverse, bool Function(DateTime) ok) {
    final first = _firstDay;
    if (first == null) return 0;
    var k = 0;
    var d = from;
    while (!d.isBefore(first)) {
      if (inUniverse(d)) {
        if (!ok(d)) break;
        k++;
      }
      d = DateTime(d.year, d.month, d.day - 1);
    }
    return k;
  }

  int _bestRun(bool Function(DateTime) inUniverse, bool Function(DateTime) ok) {
    final first = _firstDay;
    if (first == null) return 0;
    var best = 0, run = 0;
    for (var d = first; !d.isAfter(today); d = DateTime(d.year, d.month, d.day + 1)) {
      if (!inUniverse(d)) continue;
      if (ok(d)) {
        run++;
        if (run > best) best = run;
      } else {
        run = 0;
      }
    }
    return best;
  }

  int globalStreak() {
    final yesterday = DateTime(today.year, today.month, today.day - 1);
    final back = _runBack(yesterday, _hasActiveGoals, isDayConsistent);
    return back + (isDayConsistent(today) ? 1 : 0);
  }

  int globalBest() => _bestRun(_hasActiveGoals, isDayConsistent);

  bool _goalDoneOn(Goal g, DateTime d) => isGoalDone(g, _byDay[d]?.values[g.id] ?? 0);

  int goalStreak(Goal g) {
    // For an archived goal the streak freezes on its last active day.
    final end = g.archivedAt == null
        ? DateTime(today.year, today.month, today.day - 1)
        : DateTime(g.archivedAt!.year, g.archivedAt!.month, g.archivedAt!.day - 1);
    final back = _runBack(end, g.isActiveOn, (d) => _goalDoneOn(g, d));
    final todayCounts = g.isActiveOn(today) && _goalDoneOn(g, today);
    return back + (todayCounts ? 1 : 0);
  }

  int goalBest(Goal g) => _bestRun(g.isActiveOn, (d) => _goalDoneOn(g, d));

  double goalRate(Goal g, int lastNDays) {
    var active = 0, done = 0;
    for (var i = 0; i < lastNDays; i++) {
      final d = DateTime(today.year, today.month, today.day - i);
      if (!g.isActiveOn(d)) continue;
      active++;
      if (_goalDoneOn(g, d)) done++;
    }
    return active == 0 ? 0 : done / active;
  }

  Map<DateTime, double?> heatmap(int year) {
    final end = today.year > year ? DateTime(year, 12, 31) : today;
    final m = <DateTime, double?>{};
    for (var d = DateTime(year, 1, 1); !d.isAfter(end); d = DateTime(d.year, d.month, d.day + 1)) {
      m[d] = dayAverage(d);
    }
    return m;
  }
}
```

- [ ] **Step 4: run tests → green; analyze; format.** If a boundary case in the tests disagrees with the implementation, the **spec rules in Global Constraints win** — fix the implementation, not the test, unless the test contradicts the spec (then report it).
- [ ] **Step 5: Commit** — `git add lib/engine test/consistency_engine_test.dart && git commit -m "feat: ConsistencyEngine (day quality, streaks, records, rates, heatmap)"`

---

### Task 2: Home uses the engine (streaks, button colour, day rollover)

**Files:**
- Modify: `lib/controllers/home_controller.dart` (engine per reload; `HomeData` gains `streak`, `best`, `todayAverage`, `goalStreaks`; injectable `now`)
- Modify: `lib/pages/home_page.dart` (streak row under the question; button colour from tokens; `WidgetsBindingObserver` → reload on resume)
- Modify: `lib/widgets/goals_list_view.dart` (optional per-goal streak caption)
- Test: `test/goal_history_test.dart` (extend), `test/home_engine_test.dart` (new)

**Interfaces:**
- Consumes: `ConsistencyEngine` (Task 1), `SettingsStore.threshold`, `AppTokens.flameFor/qualityFor` (Phase 1).
- Produces: `HomeData({nickname, goals, hasMarkedToday, streak, best, todayAverage, goalStreaks})`; `HomeController(store, settings, {DateTime Function()? now})`.

- [ ] **Step 1: failing tests**

`test/home_engine_test.dart`:
```dart
import 'package:consistency/controllers/home_controller.dart';
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
  final today = DateTime(2026, 8, 10);
  DateTime d(int day) => DateTime(2026, 8, day);
  final u = DateTime.utc(2026);

  Future<(AppStore, SettingsStore, HomeController)> boot({int threshold = 50}) async {
    SharedPreferences.setMockInitialValues({'threshold': threshold});
    final prefs = await SharedPreferences.getInstance();
    final run = Goal(id: 'run', name: 'Run', type: GoalType.check, createdAt: d(1), archivedAt: null, updatedAt: u);
    final read = Goal(id: 'read', name: 'Read', type: GoalType.percent, createdAt: d(1), archivedAt: null, updatedAt: u);
    final store = AppStore(InMemoryGoalsRepository(AppData(goals: [run, read], entries: [
      DayEntry(date: d(8), values: {'run': 100, 'read': 50}, updatedAt: u),
      DayEntry(date: d(9), values: {'run': 100, 'read': 25}, updatedAt: u),
    ])));
    await store.load();
    final settings = SettingsStore(SettingsRepository(prefs));
    final c = HomeController(store, settings, now: () => DateTime(2026, 8, 10, 9, 30));
    return (store, settings, c);
  }

  test('HomeData carries global streak, best, per-goal streaks and today average', () async {
    final (_, _, c) = await boot();
    final s = c.state as HomeData;
    expect(s.streak, 2); // 8: avg 75, 9: avg 62.5 → both ≥ 50; today untouched
    expect(s.best, 2);
    expect(s.goalStreaks['run'], 2);
    expect(s.goalStreaks['read'], 0); // yesterday (9): 25 < 50 → not done
    expect(s.todayAverage, isNull); // no entry today
  });

  test('threshold change recomputes', () async {
    final (_, settings, c) = await boot();
    await settings.setThreshold(70);
    final s = c.state as HomeData;
    expect(s.streak, 0); // yesterday (9) avg 62.5 < 70 breaks; today has no entry
    expect(s.best, 1); // day 8 alone (avg 75)
  });

  test('saving today updates streak and todayAverage', () async {
    final (_, _, c) = await boot();
    for (final g in (c.state as HomeData).goals) {
      g.percentCompleted = 100;
    }
    await c.saveData();
    final s = c.state as HomeData;
    expect(s.streak, 3);
    expect(s.todayAverage, 100);
    expect(s.hasMarkedToday, isTrue);
  });
}
```
- [ ] **Step 2: run → fails** (`streak` undefined).

- [ ] **Step 3: `HomeController`**

Add fields to `HomeData` (all `required`; `HomeDataEmpty` passes `streak: 0, best: 0, todayAverage: null, goalStreaks: const {}`):
```dart
  final int streak;
  final int best;
  final double? todayAverage;
  final Map<String, int> goalStreaks;
```
Controller: `HomeController(this.store, this.settings, {DateTime Function()? now}) : _now = now ?? DateTime.now, super(HomeInitial());` with `final DateTime Function() _now;` and `DateTime get _today => dateOnly(_now());` (replace the static getter). In `reload()`, after computing `active`/`entry`, build:
```dart
    final engine = ConsistencyEngine(
      data: store.data, threshold: settings.threshold, today: today);
```
and pass `streak: engine.globalStreak(), best: engine.globalBest(), todayAverage: engine.dayAverage(today), goalStreaks: {for (final g in active) g.id: engine.goalStreak(g)}` into `HomeData` (and the empty variant gets `streak: engine.globalStreak(), best: engine.globalBest()` too — an empty Home can still show history). Remove `completePercent` (button colour now comes from `todayAverage`; grep callers: only `home_page.dart`).

- [ ] **Step 4: `home_page.dart`**
- Replace `color: Utilities.activeColor(_controller.completePercent)` with `color: context.tokens.qualityFor(state is HomeData ? state.todayAverage : null)` (import `../configs/app_tokens.dart`; drop `utilities.dart` import if unused).
- Under the `'Did you complete your goals today?'` text add a `ValueListenableBuilder` rendering, when `state is HomeData`:
```dart
Row(mainAxisAlignment: MainAxisAlignment.center, children: [
  Icon(Icons.local_fire_department, color: context.tokens.flameFor(state.streak), size: 20),
  const SizedBox(width: 4),
  Text('${state.streak} day streak · best ${state.best}', style: context.textStyles.normalText),
])
```
- Make `HomePageState` `with WidgetsBindingObserver`: `addObserver(this)` in `initState`, `removeObserver` in `dispose`, and
```dart
  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) _controller.reload();
  }
```
- `GoalsListView`: new optional `Map<String, int> streaks = const {}` param; under each slider row show `Text('${streaks[goal.goalId] ?? 0} days', style: context.textStyles.thinText.copyWith(fontSize: 12))` (uses `GoalModel.goalId`). Pass `streaks: state.goalStreaks` from `home_page.dart`.

- [ ] **Step 5: run tests + analyze + format → green.** Update `test/goal_history_test.dart` `boot` to pass `now: () => today` (keeps behaviour) — no assertion changes required.
- [ ] **Step 6: Commit** — `git add lib test && git commit -m "feat: home shows streaks from the engine; button colour from today's average; reload on resume"`

---

### Task 3: Threshold in Settings

**Files:**
- Modify: `lib/pages/settings_page.dart` (slider row above the theme segmented button)
- Test: `test/settings_threshold_test.dart` (widget test)

- [ ] **Step 1: failing widget test**

`test/settings_threshold_test.dart`:
```dart
import 'package:consistency/pages/settings_page.dart';
import 'package:consistency/state/settings_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'helpers.dart';

void main() {
  testWidgets('threshold slider shows and persists the value', (tester) async {
    final app = await buildApp(prefs: {'threshold': 50});
    await tester.pumpWidget(app);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    // Jump straight to the settings tab.
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Daily target: 50%'), findsOneWidget);

    final ctx = tester.element(find.byType(SettingsPage));
    await ctx.read<SettingsStore>().setThreshold(75);
    await tester.pump();
    expect(find.text('Daily target: 75%'), findsOneWidget);
  });
}
```
(If `pumpAndSettle` times out because of the mark button's looping animation, replace it with a 10×16 ms pump loop as the other tests do.)

- [ ] **Step 2: run → fails** (`Daily target` not found).

- [ ] **Step 3: slider row**

In `lib/pages/settings_page.dart`, insert **before** the `Padding(... SegmentedButton<ThemeMode> ...)` child:
```dart
                Builder(builder: (context) {
                  final t = context.watch<SettingsStore>().threshold;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('Daily target: $t%', style: context.textStyles.normalText),
                      Slider(
                        value: t.toDouble(),
                        min: 0,
                        max: 100,
                        divisions: 20,
                        label: '$t%',
                        onChanged: (v) =>
                            context.read<SettingsStore>().setThreshold(v.round()),
                      ),
                      Text(
                        'A day counts when the average of your goals reaches this. Changing it recalculates your history.',
                        style: context.textStyles.thinText.copyWith(fontSize: 12),
                        textAlign: TextAlign.end,
                      ),
                    ],
                  );
                }),
```

- [ ] **Step 4: run tests + analyze + format → green.**
- [ ] **Step 5: Commit** — `git add lib/pages/settings_page.dart test/settings_threshold_test.dart && git commit -m "feat: daily threshold setting"`

---

### Task 4: Manual smoke + tag

- [ ] Run on a device: Home shows "N day streak · best M" and per-goal "N days"; button colour follows today's average (grey before saving, then blue/green); Settings slider changes streak live; leave the app open past midnight (or change device date) and resume → Home shows the new day.
- [ ] `git tag phase-3-done`.

## Self-review

- Spec Seção 2 API: all methods present (Task 1); rule B incl. "dias sem meta ativa pulados"; threshold from settings (Task 2/3); Home shows global + per-goal streak (Task 2); button colour via engine (Task 2). Day rollover via `WidgetsBindingObserver` (spec Seção 4) (Task 2).
- Names consistent: `ConsistencyEngine(data:, threshold:, today:)`, `HomeData.streak/best/todayAverage/goalStreaks`, `HomeController(store, settings, {now})`, `GoalsListView.streaks`.
- Test values re-checked: boot data day 8 avg 75, day 9 avg 62.5; threshold 50 → streak 2, best 2; run 2; read 0. Threshold 70 → streak 0, best 1. Save today at 100 → streak 3, todayAverage 100.
