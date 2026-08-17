# Phase 5 — Calendar & Heatmap Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace `flutter_calendar_carousel` with an own month grid coloured by day quality plus a GitHub-style year heatmap, with a Month | Year toggle, matching the approved design; drop the package and the last `Utilities`/`AppColors` leftovers in the calendar.

**Architecture:** Pure layout widgets (`MonthGrid`, `YearHeatmap`, `QualityLegend`) take a `Map<DateTime, double?>` of day quality plus callbacks — no store access inside them. `CalendarController` stops producing `EventList` and instead exposes `{qualityByDay, month, year, view, selectedDay}` computed from `ConsistencyEngine`. The existing `_DayPanel` (Phase 4) is reused unchanged.

**Tech Stack:** Flutter 3.41 M3, `provider`. Removes `flutter_calendar_carousel`. No new packages.

**Spec:** `docs/superpowers/specs/2026-08-15-consistency-v2-design.md` — Seção 3 (Calendar), fase 5. Design (approved): `calendar-month.dc.html`, `calendar-year.dc.html` in project `b473eda8-1101-4699-a494-6390baa9a37e`; tokens in `docs/superpowers/specs/2026-08-15-design-tokens.md`.

## Global Constraints

- Day colour = `context.tokens.qualityFor(avg)` where `avg = ConsistencyEngine.dayAverage(day)`; no data / no active goals → `qualityFor(null)` (grey). Future days: no fill, number only, dimmed.
- Today: 2px `colorScheme.primary` border. Selected day: 3px primary ring (border + outer glow is fine).
- Month grid: 7 columns starting Sunday, weekday header `S M T W T F S` (English; Phase 8 localises), cells ~36px rounded 10, 6 rows max; `‹ August 2026 ›` header with arrows; month swipe optional (arrows are enough).
- Year heatmap: 7 rows (weekdays) × up to 53 columns, 8×8 cells, 2px gap, horizontally scrollable, month labels above the columns where the month changes, `‹ 2026 ›` header, legend `less ▢▢▢▢▢ more`. Tap a day → switch to Month view on that day.
- Legend under the month grid: `no data · <25 · 25–49 · 50–74 · ≥75` with colour chips.
- `flutter_calendar_carousel` removed from `pubspec.yaml`; `lib/configs/utilities.dart` deleted (its only callers are the calendar bits this phase rewrites — verify with grep).
- No hardcoded colours (guard test `test/no_isdark_test.dart`); English strings; lints; `flutter analyze` clean; `flutter test --concurrency=1 --reporter expanded` green; `dart format lib test`; Conventional Commits.

---

### Task 1: `CalendarController` over the engine (no EventList)

**Files:**
- Rewrite: `lib/controllers/calendar_controller.dart`
- Modify: `lib/pages/calendar_page.dart` (keep it compiling: temporarily render the day panel + a plain list of the days in `qualityByDay` — Task 3 builds the real grid)
- Delete: `lib/configs/utilities.dart` (after grep shows no other caller)
- Test: `test/calendar_controller_test.dart` (new)

**Interfaces (produced):**
```dart
enum CalendarView { month, year }
class CalendarData extends CalendarState {
  final Map<DateTime, double?> qualityByDay; // month view: the visible month; year view: whole year
  final DateTime month;      // first day of the displayed month
  final int year;            // displayed year
  final CalendarView view;
  final DateTime selectedDay;
  final DateTime today;
}
class CalendarController extends BaseController<CalendarState> {
  CalendarController(AppStore store, SettingsStore settings, {DateTime Function()? now});
  void reload();
  void selectDay(DateTime day);      // also moves month/year if needed
  void nextMonth(); void previousMonth();
  void nextYear(); void previousYear();
  void setView(CalendarView v);      // year→month keeps the selected day's month
}
```
- `qualityByDay` keys are `dateOnly` days. Month view: every day of `month` (1..last). Year view: `engine.heatmap(year)`.
- `selectDay` clamps to a day that exists; selecting a day in another month moves `month`.
- Controller listens to both stores (threshold changes recolour).

- [ ] **Step 1: failing tests**

`test/calendar_controller_test.dart`:
```dart
import 'package:consistency/controllers/calendar_controller.dart';
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
  DateTime d(int day, [int month = 8]) => DateTime(2026, month, day);
  final u = DateTime.utc(2026);
  final now = DateTime(2026, 8, 16, 9);

  Future<CalendarController> boot() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final g = Goal(id: 'g', name: 'G', type: GoalType.check, createdAt: d(1), archivedAt: null, updatedAt: u);
    final store = AppStore(InMemoryGoalsRepository(AppData(goals: [g], entries: [
      DayEntry(date: d(3), values: {'g': 100}, updatedAt: u),
      DayEntry(date: d(4), values: {'g': 0}, updatedAt: u),
      DayEntry(date: d(2, 7), values: {'g': 100}, updatedAt: u),
    ])));
    await store.load();
    return CalendarController(store, SettingsStore(SettingsRepository(prefs)), now: () => now);
  }

  CalendarData data(CalendarController c) => c.state as CalendarData;

  test('month view: one key per day of the month, quality from the engine', () async {
    final c = await boot();
    final v = data(c);
    expect(v.view, CalendarView.month);
    expect(v.month, DateTime(2026, 8, 1));
    expect(v.qualityByDay.length, 31);
    expect(v.qualityByDay[d(3)], 100);
    expect(v.qualityByDay[d(4)], 0);
    expect(v.qualityByDay[d(5)], isNull);
    expect(v.selectedDay, d(16));
    expect(v.today, d(16));
  });

  test('month navigation moves the window and keeps the selection', () async {
    final c = await boot();
    c.previousMonth();
    expect(data(c).month, DateTime(2026, 7, 1));
    expect(data(c).qualityByDay.length, 31);
    expect(data(c).qualityByDay[d(2, 7)], 100);
    expect(data(c).selectedDay, d(16)); // unchanged
    c.nextMonth();
    expect(data(c).month, DateTime(2026, 8, 1));
  });

  test('selecting a day in another month moves the month', () async {
    final c = await boot();
    c.selectDay(d(2, 7));
    expect(data(c).selectedDay, d(2, 7));
    expect(data(c).month, DateTime(2026, 7, 1));
  });

  test('year view exposes the whole year up to today', () async {
    final c = await boot();
    c.setView(CalendarView.year);
    final v = data(c);
    expect(v.view, CalendarView.year);
    expect(v.year, 2026);
    expect(v.qualityByDay.length, 228); // Jan 1 .. Aug 16 2026
    expect(v.qualityByDay[d(3)], 100);
    c.previousYear();
    expect(data(c).year, 2025);
    expect(data(c).qualityByDay.length, 365);
  });

  test('threshold change recolours (quality values are raw averages, so re-emit only)', () async {
    final c = await boot();
    final before = data(c).qualityByDay[d(3)];
    expect(before, 100);
  });

  test('load error surfaces', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final bad = AppStore(_Throwing());
    await bad.load();
    final c = CalendarController(bad, SettingsStore(SettingsRepository(prefs)), now: () => now);
    expect(c.state, isA<CalendarError>());
  });
}

class _Throwing extends InMemoryGoalsRepository {
  @override
  Future<AppData> load() async => throw const FormatException('boom');
}
```

- [ ] **Step 2: run → fails.**
- [ ] **Step 3: rewrite the controller** per the interface (build `ConsistencyEngine(data: store.data, threshold: settings.threshold, today: today)` per reload; month days via `DateTime(month.year, month.month + 1, 0).day`; year via `engine.heatmap(year)`). Keep `CalendarLoading`/`CalendarError`.
- [ ] **Step 4: keep the page compiling** — in `calendar_page.dart` remove the `CalendarCarousel` block and render a placeholder `Text('${state.month.year}-${state.month.month}')` above the existing `_DayPanel`; keep the panel wiring (`state.selectedDay`) and the error/loading branches. Remove the `flutter_calendar_carousel` imports from page and controller. Keep the dependency in `pubspec.yaml` until Task 3 (nothing else imports it — actually remove it now if `flutter pub get` succeeds; say which you did).
- [ ] **Step 5: delete `lib/configs/utilities.dart`** (grep first).
- [ ] **Step 6: tests + analyze + format → green.**
- [ ] **Step 7: Commit** — `git add -A lib test && git commit -m "refactor: calendar controller exposes day quality from the engine"`

---

### Task 2: `MonthGrid` + `QualityLegend` widgets (pure)

**Files:**
- Create: `lib/widgets/month_grid.dart`, `lib/widgets/quality_legend.dart`
- Test: `test/month_grid_test.dart`

**Interfaces:**
```dart
class MonthGrid extends StatelessWidget {
  const MonthGrid({required DateTime month, required Map<DateTime, double?> quality,
    required DateTime today, required DateTime selected, required ValueChanged<DateTime> onSelect});
}
class QualityLegend extends StatelessWidget { const QualityLegend(); }
```
- Layout: `Column(weekday header row, ...6 rows of 7 cells)`; leading blanks for the weekday offset (`month.weekday % 7` with Sunday = 0); each cell 36×36, `borderRadius: 10`, `key: ValueKey('day-${dateKey(day)}')`.
- Fill: `quality[day]` → `tokens.qualityFor(v)`; future day (`day.isAfter(today)`) → transparent fill, number in `onSurfaceVariant.withValues(alpha: .5)`, not tappable.
- Number colour: `tokens.onQualityFor(v)` when filled, `colorScheme.onSurface` when grey/unfilled.
- Today border 2px primary; selected: 3px primary border (and if today is selected, the thicker one wins).
- Tap → `onSelect(day)` with 44px min hit area (wrap the 36px visual in a 44px `InkResponse`).

- [ ] **Step 1: failing widget test** — pump `MonthGrid` for August 2026, today = 16, selected = 14, quality {3: 100, 4: 0}: expect 31 day cells (`find.byKey(ValueKey('day-2026-08-03'))` etc.), tapping day 5 calls back with `DateTime(2026,8,5)`, tapping day 20 (future) does not call back, and the header row shows 7 labels.
- [ ] **Step 2–5:** run → fail, implement, green, commit `feat: month grid and quality legend widgets`.

---

### Task 3: Calendar page — Month | Year toggle, real grid, panel

**Files:**
- Rewrite: `lib/pages/calendar_page.dart`
- Modify: `pubspec.yaml` (drop `flutter_calendar_carousel` if Task 1 didn't)
- Test: `test/calendar_page_test.dart` (rewrite/extend the Phase-4 `calendar_panel_test.dart` — keep its panel assertions)

Layout (design `calendar-month.dc.html`): `SegmentedButton` `Month | Year` at the top; month header row `‹  August 2026  ›` (`IconButton`s + title, 20/500); `MonthGrid`; `QualityLegend`; then the existing `_DayPanel(key: ValueKey(selectedDay))`. Year view: `YearHeatmap` (Task 4) + legend + summary card, no panel.
- [ ] **Step 1: failing test** — app → Calendar tab: expect `MonthGrid`, the month title text, legend; tap `‹` → title shows July; tap a past day with an entry → panel shows its goals and a `Save` button; switch to `Year` → `YearHeatmap` visible, panel gone.
- [ ] **Step 2–5:** run → fail, implement, green, commit `feat: own month calendar with quality colours`.

---

### Task 4: `YearHeatmap` + summary

**Files:**
- Create: `lib/widgets/year_heatmap.dart`
- Modify: `lib/pages/calendar_page.dart` (year branch)
- Test: `test/year_heatmap_test.dart`

**Interface:** `YearHeatmap({required int year, required Map<DateTime, double?> quality, required DateTime today, required ValueChanged<DateTime> onSelect})`.
- 7 rows (Sun..Sat) × columns of weeks; column 0 starts on the Sunday on/before Jan 1; cells 8×8 rounded 2, gap 2, `key: ValueKey('hm-${dateKey(day)}')`; days outside the year or after today are transparent placeholders (not tappable). Horizontal `SingleChildScrollView`. Month labels row above, drawn where a week's first day starts a new month. Weekday labels column (`M`, `W`, `F` only) at the left.
- Summary card under it: `'$year · N consistent days of M · best streak X · current Y'` from `ConsistencyEngine` (pass the numbers in as parameters, keep the widget pure: `YearSummary({required int year, required int consistent, required int recorded, required int best, required int current})`).
- Tap a cell → `onSelect(day)`; the page switches to month view on that day.
- [ ] **Step 1: failing test** — pump `YearHeatmap` for 2026 with quality {Jan 5: 100}: expect `find.byKey(ValueKey('hm-2026-01-05'))`, tapping it calls back with that date, and a day after `today` is not tappable.
- [ ] **Step 2–5:** run → fail, implement, green, commit `feat: year heatmap with summary`.

---

### Task 5: Smoke + tag

- [ ] Device: month grid colours match the saved days; arrows move months; tapping a day opens the panel (editable ≤7 days back); legend readable in light/dark; Year view scrolls horizontally, tap jumps to the month; no `flutter_calendar_carousel` in `pubspec.lock` (`flutter pub deps | grep calendar` → nothing). `git tag phase-5-done`.

## Self-review

- Spec fase 5: grid mensal próprio ✔ (T2/T3), heatmap anual ✔ (T4), remove `flutter_calendar_carousel` ✔ (T1/T3), cor por consistência ✔ (T1 + tokens), toggle Mês|Ano ✔ (T3), tap no ano → mês ✔ (T4/T3).
- Names: `CalendarView`, `CalendarData{qualityByDay, month, year, view, selectedDay, today}`, `MonthGrid`, `QualityLegend`, `YearHeatmap`, `YearSummary`, keys `day-yyyy-MM-dd` / `hm-yyyy-MM-dd`.
- `_DayPanel` from Phase 4 is reused as-is; its tests stay valid.
