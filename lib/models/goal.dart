import 'date_key.dart';

const _keep = Object();

enum GoalType { check, percent }

class Goal {
  final String id;
  final String name;
  final GoalType type;
  final DateTime createdAt; // calendar day; active from here
  final DateTime? archivedAt; // calendar day; null = active
  final DateTime updatedAt; // UTC instant, for merge/sync

  Goal({
    required this.id,
    required this.name,
    required this.type,
    required DateTime createdAt,
    required DateTime? archivedAt,
    required this.updatedAt,
  })  : createdAt = dateOnly(createdAt),
        archivedAt = archivedAt == null ? null : dateOnly(archivedAt);

  bool isActiveOn(DateTime day) {
    final d = dateOnly(day);
    if (d.isBefore(createdAt)) return false;
    final a = archivedAt;
    return a == null || d.isBefore(a);
  }

  bool get isArchived => archivedAt != null;

  Goal copyWith({
    String? name,
    GoalType? type,
    DateTime? createdAt,
    Object? archivedAt = _keep,
    DateTime? updatedAt,
  }) =>
      Goal(
        id: id,
        name: name ?? this.name,
        type: type ?? this.type,
        createdAt: createdAt ?? this.createdAt,
        archivedAt: identical(archivedAt, _keep)
            ? this.archivedAt
            : archivedAt as DateTime?,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type.name,
        'createdAt': dateKey(createdAt),
        'archivedAt': archivedAt == null ? null : dateKey(archivedAt!),
        'updatedAt': updatedAt.toUtc().toIso8601String(),
      };

  factory Goal.fromJson(Map<String, dynamic> j) => Goal(
        id: j['id'] as String,
        name: j['name'] as String,
        type: GoalType.values.byName(j['type'] as String),
        createdAt: parseDateKey(j['createdAt'] as String),
        archivedAt: j['archivedAt'] == null
            ? null
            : parseDateKey(j['archivedAt'] as String),
        updatedAt: DateTime.parse(j['updatedAt'] as String).toUtc(),
      );
}
