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
            : data.goals
                .map((g) => g.createdAt)
                .reduce((a, b) => a.isBefore(b) ? a : b);

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
  int _runBack(DateTime from, bool Function(DateTime) inUniverse,
      bool Function(DateTime) ok) {
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
    for (var d = first;
        !d.isAfter(today);
        d = DateTime(d.year, d.month, d.day + 1)) {
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

  bool _goalDoneOn(Goal g, DateTime d) =>
      isGoalDone(g, _byDay[d]?.values[g.id] ?? 0);

  int goalStreak(Goal g) {
    // For an archived goal the streak freezes on its last active day.
    final end = g.archivedAt == null
        ? DateTime(today.year, today.month, today.day - 1)
        : DateTime(
            g.archivedAt!.year, g.archivedAt!.month, g.archivedAt!.day - 1);
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
    for (var d = DateTime(year, 1, 1);
        !d.isAfter(end);
        d = DateTime(d.year, d.month, d.day + 1)) {
      m[d] = dayAverage(d);
    }
    return m;
  }
}
