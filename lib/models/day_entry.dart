import 'date_key.dart';

class DayEntry {
  final DateTime date; // calendar day
  final Map<String, double> values; // goalId -> 0..100 (check: 0 | 100)
  final DateTime updatedAt; // UTC instant

  DayEntry({
    required DateTime date,
    required Map<String, double> values,
    required this.updatedAt,
  })  : date = dateOnly(date),
        values = Map.unmodifiable(values);

  DayEntry copyWith({Map<String, double>? values, DateTime? updatedAt}) =>
      DayEntry(
        date: date,
        values: values ?? this.values,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, dynamic> toJson() => {
        'date': dateKey(date),
        'values': values,
        'updatedAt': updatedAt.toUtc().toIso8601String(),
      };

  factory DayEntry.fromJson(Map<String, dynamic> j) => DayEntry(
        date: parseDateKey(j['date'] as String),
        values: {
          for (final e in (j['values'] as Map).entries)
            e.key as String: (e.value as num).toDouble(),
        },
        updatedAt: DateTime.parse(j['updatedAt'] as String).toUtc(),
      );
}
