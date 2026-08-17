import 'package:flutter/foundation.dart';

import '../engine/consistency_engine.dart';
import '../models/date_key.dart';
import '../models/goal.dart';
import '../state/app_store.dart';
import '../state/settings_store.dart';
import 'base_controller.dart';

const kEditWindowDays = 7;

class GoalRow {
  final String goalId;
  final String name;
  final GoalType type;
  final double value;
  final int streak;
  const GoalRow(
      {required this.goalId,
      required this.name,
      required this.type,
      required this.value,
      required this.streak});
}

class DayView {
  final DateTime day;

  /// null until the user picks one; the UI falls back to l10n.defaultNickname.
  final String? nickname;
  final List<GoalRow> goals;
  final bool editable;
  final bool saved;
  final bool dirty;
  final bool saveFailed;
  final double? average;
  final int streak;
  final int best;
  const DayView({
    required this.day,
    required this.nickname,
    required this.goals,
    required this.editable,
    required this.saved,
    required this.dirty,
    this.saveFailed = false,
    required this.average,
    required this.streak,
    required this.best,
  });
}

sealed class DayEditorState {}

class DayEditorLoading extends DayEditorState {}

class DayEditorError extends DayEditorState {}

class DayEditorReady extends DayEditorState {
  final DayView view;
  DayEditorReady(this.view);
}

/// Edits the values of one calendar day. `day == null` means "today", which is
/// re-evaluated on every reload so an open app rolls over at midnight.
class DayEditorController extends BaseController<DayEditorState> {
  final AppStore store;
  final SettingsStore settings;
  final DateTime? _fixedDay;
  final DateTime Function() _now;
  final Map<String, double> _draft = {}; // goalId -> unsaved value
  bool _saving = false;

  DayEditorController(this.store, this.settings,
      {DateTime? day, DateTime Function()? now})
      : _fixedDay = day == null ? null : dateOnly(day),
        _now = now ?? DateTime.now,
        super(DayEditorLoading());

  DateTime get today => dateOnly(_now());
  DateTime get day => _fixedDay ?? today;

  bool _isEditable(DateTime d) {
    final t = today;
    if (d.isAfter(t)) return false;
    final earliest = DateTime(t.year, t.month, t.day - kEditWindowDays);
    return !d.isBefore(earliest);
  }

  @override
  void onInit() {
    store.addListener(reload);
    settings.addListener(reload);
    reload();
  }

  void reload() {
    final err = store.loadError;
    if (err != null) {
      // The raw text is a diagnostic; the UI shows a localised message.
      debugPrint('DayEditorController: load failed: $err');
      emit(DayEditorError());
      return;
    }
    if (!store.loaded) {
      emit(DayEditorLoading());
      return;
    }

    final d = day;
    final t = today;
    if (_fixedDay == null &&
        state is DayEditorReady &&
        (state as DayEditorReady).view.day != d) {
      _draft
          .clear(); // midnight rolled over: yesterday's unsaved edits don't belong to today
    }
    final entry = store.data.entryOn(d);
    final active = store.data.activeGoalsOn(d);
    final engine = ConsistencyEngine(
        data: store.data, threshold: settings.threshold, today: t);

    final goals = [
      for (final g in active)
        GoalRow(
          goalId: g.id,
          name: g.name,
          type: g.type,
          value: _draft[g.id] ?? entry?.values[g.id] ?? 0,
          streak: engine.goalStreak(g),
        ),
    ];
    // A failed write leaves the new values in memory only, so the day still
    // counts as unsaved even though the in-memory entry already matches.
    final saveFailed = store.saveError != null;
    final dirty = saveFailed ||
        (entry == null
            ? _draft.isNotEmpty
            : goals.any((g) => (entry.values[g.goalId] ?? 0) != g.value));
    final avg = goals.isEmpty
        ? null
        : goals.map((g) => g.value).reduce((a, b) => a + b) / goals.length;

    emit(DayEditorReady(DayView(
      day: d,
      nickname: settings.nickname,
      goals: goals,
      editable: _isEditable(d),
      saved: entry != null,
      dirty: dirty,
      saveFailed: saveFailed,
      average: avg,
      streak: engine.globalStreak(),
      best: engine.globalBest(),
    )));
  }

  void setValue(String goalId, double v) {
    final s = state;
    if (s is! DayEditorReady || !s.view.editable) return;
    if (!s.view.goals.any((g) => g.goalId == goalId)) return;
    _draft[goalId] = v.clamp(0, 100).toDouble();
    reload();
  }

  void toggle(String goalId) {
    final s = state;
    if (s is! DayEditorReady) return;
    GoalRow? row;
    for (final g in s.view.goals) {
      if (g.goalId == goalId) {
        row = g;
        break;
      }
    }
    if (row == null) return;
    setValue(goalId, row.value >= 100 ? 0 : 100);
  }

  Future<void> save() async {
    final s = state;
    if (_saving ||
        s is! DayEditorReady ||
        !s.view.editable ||
        s.view.goals.isEmpty) {
      return;
    }
    _saving = true;
    try {
      await store.saveDay(
          s.view.day, {for (final g in s.view.goals) g.goalId: g.value});
      if (store.saveError == null) _draft.clear();
      reload();
    } finally {
      _saving = false;
    }
  }

  @override
  void onDispose() {
    store.removeListener(reload);
    settings.removeListener(reload);
    super.onDispose();
  }
}
