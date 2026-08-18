import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../data/goals_repository.dart';
import '../models/app_data.dart';
import '../models/date_key.dart';
import '../models/day_entry.dart';
import '../models/goal.dart';

/// The single in-memory copy of the user's data. Every mutation persists
/// through the repository and notifies listeners.
class AppStore extends ChangeNotifier {
  final GoalsRepository _repo;
  final String Function() _newId;
  final DateTime Function() _now;

  AppData _data = AppData.empty;
  bool _loaded = false;
  Object? _loadError;
  Object? _saveError;

  AppStore(
    this._repo, {
    String Function()? newId,
    DateTime Function()? now,
  })  : _newId = newId ?? const Uuid().v4,
        _now = now ?? (() => DateTime.now().toUtc());

  AppData get data => _data;
  bool get loaded => _loaded;
  Object? get loadError => _loadError;
  Object? get saveError => _saveError;

  /// The main file's raw text even when it fails to parse — see
  /// [GoalsRepository.readRaw]. Never throws.
  Future<String?> readRaw() => _repo.readRaw();

  Future<void> load() async {
    try {
      _data = await _repo.load();
      _loaded = true;
      _loadError = null;
    } catch (e, s) {
      debugPrint('AppStore.load failed: $e\n$s');
      _loadError = e;
      _loaded = false;
    }
    notifyListeners();
  }

  Future<void> _commit(AppData next) async {
    _data = next;
    notifyListeners();
    try {
      await _repo.save(next);
      if (_saveError != null) {
        _saveError = null;
        notifyListeners();
      }
    } catch (e, s) {
      debugPrint('AppStore save failed: $e\n$s');
      _saveError = e;
      notifyListeners();
    }
  }

  Future<Goal> addGoal(String name, GoalType type,
      {DateTime? createdAt}) async {
    final goal = Goal(
      id: _newId(),
      name: name.trim(),
      type: type,
      createdAt: createdAt ?? dateOnly(DateTime.now()),
      archivedAt: null,
      updatedAt: _now(),
    );
    await _commit(_data.copyWith(goals: [..._data.goals, goal]));
    return goal;
  }

  Future<void> _updateGoal(String id, Goal Function(Goal) f) => _commit(
        _data.copyWith(goals: [
          for (final g in _data.goals)
            g.id == id ? f(g).copyWith(updatedAt: _now()) : g,
        ]),
      );

  Future<void> renameGoal(String id, String name) =>
      _updateGoal(id, (g) => g.copyWith(name: name.trim()));

  Future<void> setGoalType(String id, GoalType type) =>
      _updateGoal(id, (g) => g.copyWith(type: type));

  Future<void> archiveGoal(String id, {DateTime? on}) => _updateGoal(
      id, (g) => g.copyWith(archivedAt: on ?? dateOnly(DateTime.now())));

  Future<void> restoreGoal(String id) =>
      _updateGoal(id, (g) => g.copyWith(archivedAt: null));

  Future<void> saveDay(DateTime day, Map<String, double> values) async {
    final d = dateOnly(day);
    final active = {for (final g in _data.activeGoalsOn(d)) g.id};
    final clean = {
      for (final e in values.entries)
        if (active.contains(e.key)) e.key: e.value.clamp(0, 100).toDouble(),
    };
    final entry = DayEntry(date: d, values: clean, updatedAt: _now());
    final others = [
      for (final e in _data.entries)
        if (e.date != d) e
    ];
    await _commit(_data.copyWith(entries: [...others, entry]));
  }

  Future<void> replaceAll(AppData data) => _commit(data);

  Future<void> clearAll() async {
    await _repo.moveToUndo();
    _data = AppData.empty;
    notifyListeners();
  }

  Future<bool> undoClear() async {
    if (!await _repo.restoreFromUndo()) return false;
    _data = await _repo.load();
    notifyListeners();
    return true;
  }
}
