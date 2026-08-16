import 'package:flutter/material.dart';

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

  HomeData({
    required this.nickname,
    required this.goals,
    required this.hasMarkedToday,
  });
}

class HomeDataEmpty extends HomeData {
  HomeDataEmpty({required super.nickname, super.hasMarkedToday = false})
      : super(goals: []);
}

class HomeController extends BaseController<HomeState> {
  final AppStore store;
  final SettingsStore settings;
  List<TextEditingController> goalsControllers = <TextEditingController>[];
  bool _saving = false;

  HomeController(this.store, this.settings) : super(HomeInitial());

  static DateTime get _today => dateOnly(DateTime.now());

  /// Average completion of the goals currently on screen. Drives the splash
  /// colour of the mark-today button.
  double get completePercent {
    final current = state;
    if (current is! HomeData || current.goals.isEmpty) return 100;
    return current.goals
            .map((goal) => goal.percentCompleted)
            .reduce((a, b) => a + b) /
        current.goals.length;
  }

  @override
  void onInit() {
    store.addListener(reload);
    settings.addListener(reload);
    reload();
  }

  /// Rebuilds the view models from the store. Runs on every store change; a
  /// slider drag is never lost because the store only notifies on writes.
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

    if (active.isEmpty) {
      // Drop controllers left over from a previous load, or a rename would
      // read a stale one and persist a new goal under the old name.
      setGoalsControllers(const []);
      emit(HomeDataEmpty(nickname: nickname, hasMarkedToday: entry != null));
      return;
    }

    final goals = [
      for (final goal in active)
        GoalModel(
          goalId: goal.id,
          name: goal.name,
          percentCompleted: entry?.values[goal.id] ?? 0,
        ),
    ];

    setGoalsControllers(goals);
    emit(
      HomeData(
        nickname: nickname,
        goals: goals,
        hasMarkedToday: entry != null,
      ),
    );
  }

  void setGoalsControllers(List<GoalModel> goals) {
    for (final controller in goalsControllers) {
      controller.dispose();
    }
    goalsControllers = [
      for (final goal in goals) TextEditingController(text: goal.name),
    ];
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
    await store.archiveGoal(current.goals[index].goalId, on: _today);
  }

  @override
  void onDispose() {
    store.removeListener(reload);
    settings.removeListener(reload);
    for (final controller in goalsControllers) {
      controller.dispose();
    }
    goalsControllers = [];
    super.onDispose();
  }
}
