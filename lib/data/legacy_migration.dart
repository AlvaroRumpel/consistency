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
