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
    // Created in July so the goal is already active for the July fixture
    // entry below (the engine only counts entries for active goals).
    final g = Goal(
        id: 'g',
        name: 'G',
        type: GoalType.check,
        createdAt: d(1, 7),
        archivedAt: null,
        updatedAt: u);
    final store = AppStore(InMemoryGoalsRepository(AppData(goals: [
      g
    ], entries: [
      DayEntry(date: d(3), values: {'g': 100}, updatedAt: u),
      DayEntry(date: d(4), values: {'g': 0}, updatedAt: u),
      DayEntry(date: d(2, 7), values: {'g': 100}, updatedAt: u),
    ])));
    await store.load();
    return CalendarController(store, SettingsStore(SettingsRepository(prefs)),
        now: () => now);
  }

  CalendarData data(CalendarController c) => c.state as CalendarData;

  test('month view: one key per day of the month, quality from the engine',
      () async {
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

  test(
      'threshold change recolours (quality values are raw averages, so re-emit only)',
      () async {
    final c = await boot();
    final before = data(c);
    await c.settings.setThreshold(80);
    expect(identical(before, data(c)), isFalse); // the grid rebuilds
    expect(data(c).qualityByDay[d(3)], 100); // same average, new colour
  });

  test('the forward arrows stop at the current month/year', () async {
    final c = await boot();
    c.nextMonth();
    expect(data(c).month, DateTime(2026, 8, 1)); // today's month, unmoved
    c.setView(CalendarView.year);
    c.nextYear();
    expect(data(c).year, 2026);
  });

  test('switching views keeps the window the user was on', () async {
    final c = await boot();
    c.previousMonth();
    c.setView(CalendarView.year);
    expect(data(c).year, 2026);
    c.previousYear();
    c.setView(CalendarView.month);
    // The selection is in 2026, so a 2025 window opens on its January — and
    // the selection moves in with it, or the panel would edit a day the grid
    // doesn't even show.
    expect(data(c).month, DateTime(2025, 1, 1));
    expect(data(c).selectedDay, DateTime(2025, 1, 1));
  });

  test('load error surfaces', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final bad = AppStore(_Throwing());
    await bad.load();
    final c = CalendarController(bad, SettingsStore(SettingsRepository(prefs)),
        now: () => now);
    expect(c.state, isA<CalendarError>());
  });
}

class _Throwing extends InMemoryGoalsRepository {
  @override
  Future<AppData> load() async => throw const FormatException('boom');
}
