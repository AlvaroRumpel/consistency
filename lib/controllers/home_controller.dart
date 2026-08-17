import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../engine/consistency_engine.dart';
import '../models/date_key.dart';
import '../models/goal.dart';
import '../models/goal_model.dart';
import '../state/app_store.dart';
import '../state/settings_store.dart';
import 'base_controller.dart';

sealed class HomeState {}

class HomeInitial extends HomeState {}

class HomeLoading extends HomeState {}

class HomeError extends HomeState {
  final String message;

  HomeError({required this.message});
}

class HomeData extends HomeState {
  final String nickname;
  final List<GoalModel> goals;
  final bool hasMarkedToday;
  final int streak;
  final int best;
  final double? todayAverage;
  final Map<String, int> goalStreaks;

  HomeData({
    required this.nickname,
    required this.goals,
    required this.hasMarkedToday,
    required this.streak,
    required this.best,
    required this.todayAverage,
    required this.goalStreaks,
  });
}

class HomeDataEmpty extends HomeData {
  HomeDataEmpty({
    required super.nickname,
    super.hasMarkedToday = false,
    required super.streak,
    required super.best,
  }) : super(goals: [], todayAverage: null, goalStreaks: const {});
}

class HomeController extends BaseController<HomeState> {
  final AppStore store;
  final SettingsStore settings;
  final DateTime Function() _now;
  List<TextEditingController> goalsControllers = <TextEditingController>[];
  List<String> _controllerIds = <String>[];
  bool _saving = false;
  final _archiving = <String>{};

  HomeController(this.store, this.settings, {DateTime Function()? now})
      : _now = now ?? DateTime.now,
        super(HomeInitial());

  DateTime get _today => dateOnly(_now());

  @override
  void onInit() {
    store.addListener(reload);
    settings.addListener(reload);
    reload();
  }

  /// Rebuilds the view models from the store. Any value the user has changed
  /// but not yet marked (a slider drag) is carried forward by goal id, so an
  /// archive/add/rename mid-session does not zero the other sliders.
  void reload() {
    final error = store.loadError;
    if (error != null) {
      emit(HomeError(message: error.toString()));
      return;
    }
    if (!store.loaded) {
      emit(HomeLoading());
      return;
    }

    final nickname = settings.nicknameOrDefault;
    final today = _today;
    final active = store.data.activeGoalsOn(today);
    final entry = store.data.entryOn(today);
    final engine = ConsistencyEngine(
      data: store.data,
      threshold: settings.threshold,
      today: today,
    );

    if (active.isEmpty) {
      // Drop controllers left over from a previous load, or a rename would
      // read a stale one and persist a new goal under the old name.
      setGoalsControllers(const []);
      emit(HomeDataEmpty(
        nickname: nickname,
        hasMarkedToday: entry != null,
        streak: engine.globalStreak(),
        best: engine.globalBest(),
      ));
      return;
    }

    final previous = state;
    final inProgress = {
      if (previous is HomeData)
        for (final goal in previous.goals) goal.goalId: goal.percentCompleted,
    };

    final goals = [
      for (final goal in active)
        GoalModel(
          goalId: goal.id,
          name: goal.name,
          percentCompleted: entry?.values[goal.id] ?? inProgress[goal.id] ?? 0,
        ),
    ];

    setGoalsControllers(goals);
    emit(
      HomeData(
        nickname: nickname,
        goals: goals,
        hasMarkedToday: entry != null,
        streak: engine.globalStreak(),
        best: engine.globalBest(),
        todayAverage: engine.dayAverage(today),
        goalStreaks: {for (final g in active) g.id: engine.goalStreak(g)},
      ),
    );
  }

  /// Rebuilds the text fields only when the goal list itself changed: a
  /// nickname or theme change must not throw away what the user is typing.
  void setGoalsControllers(List<GoalModel> goals) {
    final ids = [for (final goal in goals) goal.goalId];
    if (listEquals(ids, _controllerIds)) return;

    for (final controller in goalsControllers) {
      controller.dispose();
    }
    goalsControllers = [
      for (final goal in goals) TextEditingController(text: goal.name),
    ];
    _controllerIds = ids;
  }

  /// Persists names typed inline. Every field is read up front: each rename
  /// notifies the store, and the resulting reload() rebuilds goalsControllers.
  Future<void> _commitTypedNames(List<GoalModel> goals) async {
    final typed = [
      for (var i = 0; i < goals.length && i < goalsControllers.length; i++)
        goalsControllers[i].text.trim(),
    ];
    for (var i = 0; i < typed.length; i++) {
      if (typed[i].isNotEmpty && typed[i] != goals[i].name) {
        await store.renameGoal(goals[i].goalId, typed[i]);
      }
    }
  }

  Future<void> saveData() async {
    final current = state;
    // _saving holds across the awaits; hasMarkedToday is only emitted after
    // them, so on its own it lets a double tap write today twice.
    if (_saving ||
        current is! HomeData ||
        current.hasMarkedToday ||
        current.goals.isEmpty) {
      return;
    }
    _saving = true;

    try {
      // Names typed inline are committed together with the day.
      await _commitTypedNames(current.goals);
      await store.saveDay(_today, {
        for (final goal in current.goals) goal.goalId: goal.percentCompleted,
      });
      // The store notifies, so reload() emits HomeData(hasMarkedToday: true).
    } finally {
      _saving = false;
    }
  }

  Future<void> addNewGoal() async {
    final current = state;
    if (current is! HomeData) return;

    // Preserve in-progress renames before the store-triggered rebuild.
    await _commitTypedNames(current.goals);
    await store.addGoal('New Goal', GoalType.percent, createdAt: _today);
  }

  Future<void> removeGoal(int index) async {
    final current = state;
    if (current is! HomeData || current.hasMarkedToday) return;
    if (index < 0 || index >= current.goals.length) return;
    final id = current.goals[index].goalId;
    if (_archiving.contains(id)) return;
    _archiving.add(id);
    try {
      await store.archiveGoal(id, on: _today);
    } finally {
      _archiving.remove(id);
    }
  }

  @override
  void onDispose() {
    store.removeListener(reload);
    settings.removeListener(reload);
    for (final controller in goalsControllers) {
      controller.dispose();
    }
    goalsControllers = [];
    _controllerIds = [];
    super.onDispose();
  }
}
