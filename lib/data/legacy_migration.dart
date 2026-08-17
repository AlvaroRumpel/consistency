import 'dart:convert';

import 'package:flutter/foundation.dart';
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
  static const migratedKey = 'migratedV1';

  static AppData convert(String userDataJson, {String Function()? newId}) {
    final mkId = newId ?? const Uuid().v4;
    final raw = jsonDecode(userDataJson) as List;

    // Group by calendar day first: v1 could write more than one item for the
    // same day, and the later item's values must win per goal name.
    final groups = <DateTime, List<(String, double)>>{};
    for (final item in raw) {
      final m = jsonDecode(item as String) as Map<String, dynamic>;
      final date = dateOnly(
        DateTime.fromMillisecondsSinceEpoch(m['date'] as int),
      );
      final goals = groups.putIfAbsent(date, () => <(String, double)>[]);
      for (final g in (m['goals'] as List? ?? const [])) {
        goals.add((
          (g['name'] as String? ?? '').trim(),
          ((g['percentCompleted'] as num?) ?? 0).toDouble(),
        ));
      }
    }
    final dates = groups.keys.toList()..sort();

    final byName = <String, Goal>{};
    final lastSeen = <String, DateTime>{};
    final entries = <DayEntry>[];
    final now = DateTime.now().toUtc();

    for (final date in dates) {
      final values = <String, double>{};
      for (final (name, pct) in groups[date]!) {
        final goal = byName.putIfAbsent(
          name,
          () => Goal(
            id: mkId(),
            name: name,
            type: GoalType.percent,
            createdAt: date,
            archivedAt: null,
            updatedAt: now,
          ),
        );
        values[goal.id] = pct; // later item on the same day overwrites
        lastSeen[name] = date;
      }
      entries.add(DayEntry(date: date, values: values, updatedAt: now));
    }

    final lastDayNames = dates.isEmpty
        ? const <String>{}
        : {for (final (n, _) in groups[dates.last]!) n};
    final goals = <Goal>[];
    for (final g in byName.values) {
      if (lastDayNames.contains(g.name)) {
        goals.add(g);
      } else {
        final d = lastSeen[g.name]!;
        goals.add(g.copyWith(archivedAt: DateTime(d.year, d.month, d.day + 1)));
      }
    }
    return AppData(goals: goals, entries: entries);
  }

  static Future<bool> runIfNeeded(
    SharedPreferences prefs,
    GoalsRepository repo,
  ) async {
    await prefs.remove(beforeDeleteKey);
    if (prefs.getBool(migratedKey) == true) return false;
    if (await repo.exists()) return false;
    final blob = prefs.getString(userDataKey);
    if (blob == null || blob.isEmpty) return false;
    final AppData data;
    try {
      data = convert(blob);
    } catch (e) {
      // Malformed blob: leave it in prefs untouched so a future app version
      // can retry (or a human can inspect it) instead of silently losing it.
      debugPrint('LegacyMigration failed: $e');
      return false;
    }
    await repo.save(data);
    await prefs.remove(userDataKey);
    await prefs.setBool(migratedKey, true);
    return true;
  }
}
