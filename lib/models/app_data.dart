import 'date_key.dart';
import 'day_entry.dart';
import 'goal.dart';

class AppData {
  static const int schemaVersion = 2;

  final List<Goal> goals;
  final List<DayEntry> entries; // always sorted by date ascending, deduped

  AppData({required List<Goal> goals, required List<DayEntry> entries})
      : goals = List.unmodifiable(goals),
        entries = List.unmodifiable(_dedupeSorted(entries));

  // Later entries for the same date win (input order), then sorted.
  static List<DayEntry> _dedupeSorted(List<DayEntry> entries) {
    final byDate = <DateTime, DayEntry>{}; // insertion-ordered (LinkedHashMap)
    for (final e in entries) {
      byDate[e.date] = e;
    }
    return byDate.values.toList()..sort((a, b) => a.date.compareTo(b.date));
  }

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

  List<Goal> activeGoalsOn(DateTime day) => [
        for (final g in goals)
          if (g.isActiveOn(day)) g
      ];

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
        for (final g in j['goals'] as List)
          Goal.fromJson(g as Map<String, dynamic>),
      ],
      entries: [
        for (final e in j['entries'] as List)
          DayEntry.fromJson(e as Map<String, dynamic>),
      ],
    );
  }
}
