import 'dart:convert';

import '../models/app_data.dart';
import '../models/date_key.dart';
import '../models/day_entry.dart';
import '../models/goal.dart';

class BackupSummary {
  final int goals;
  final int days;
  const BackupSummary({required this.goals, required this.days});
}

/// Pure JSON codec for backup import/export. No plugins, no dart:io — the
/// surrounding I/O (file picking, sharing) lives elsewhere.
class BackupCodec {
  static String encode(AppData data) =>
      const JsonEncoder.withIndent('  ').convert(data.toJson());

  static AppData decode(String json) {
    try {
      final decoded = jsonDecode(json);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Backup must be a JSON object');
      }
      return AppData.fromJson(decoded);
    } on FormatException {
      rethrow;
    } catch (e) {
      throw FormatException('Invalid backup: $e');
    }
  }

  static BackupSummary summarize(AppData data) =>
      BackupSummary(goals: data.goals.length, days: data.entries.length);

  static String fileName(DateTime day) => 'consistency-${dateKey(day)}.json';

  /// Union of goals (by id) and entries (by date); on conflict the newer
  /// `updatedAt` wins the whole record.
  static AppData merge(AppData current, AppData incoming) {
    final goals = <String, Goal>{
      for (final g in current.goals) g.id: g,
    };
    for (final g in incoming.goals) {
      final existing = goals[g.id];
      if (existing == null || g.updatedAt.isAfter(existing.updatedAt)) {
        goals[g.id] = g;
      }
    }

    final entries = <DateTime, DayEntry>{
      for (final e in current.entries) e.date: e,
    };
    for (final e in incoming.entries) {
      final existing = entries[e.date];
      if (existing == null || e.updatedAt.isAfter(existing.updatedAt)) {
        entries[e.date] = e;
      }
    }

    return AppData(
        goals: goals.values.toList(), entries: entries.values.toList());
  }
}
