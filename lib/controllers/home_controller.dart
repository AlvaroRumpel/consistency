import 'package:flutter/material.dart';

import '../configs/local_data.dart';
import '../models/date_goal_model.dart';
import '../models/goal_model.dart';
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
  late LocalData localData;
  List<TextEditingController> goalsControllers = <TextEditingController>[];
  final userData = <DateGoalModel>[];
  bool _saving = false;

  HomeController() : super(HomeInitial());

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

  static DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  @override
  void onInit() async {
    localData = await LocalData.i;
    LocalData.revision.addListener(reload);
    emitGuard(
      loadingState: HomeLoading(),
      newState: recoveryData,
      errorState: (e) => HomeError(message: e.toString()),
    );
  }

  void reload() => emitGuard(
        loadingState: HomeLoading(),
        newState: recoveryData,
        errorState: (e) => HomeError(message: e.toString()),
      );

  Future<HomeState> recoveryData([HomeState? oldState]) async {
    final nickname = await localData.searchNickname() ?? 'User';
    final userGoals = await localData.searchUserData();

    userData
      ..clear()
      ..addAll(userGoals ?? []);

    if (userGoals == null || userGoals.isEmpty) {
      // Drop any controllers left over from a previous load, or saveData would
      // read a stale one and persist the new goal under the old name.
      setGoalsControllers(const []);
      return HomeDataEmpty(nickname: nickname);
    }

    final hasMarkedToday = userGoals.any((item) => item.date == _today);

    // Deep copy: the sliders mutate these objects in place, and userData holds
    // the persisted history. Sharing instances lets today's edits rewrite
    // yesterday's record.
    final goals = userGoals.last.goals.map((goal) => goal.copyWith()).toList();

    setGoalsControllers(goals);

    return goals.isNotEmpty
        ? HomeData(
            nickname: nickname,
            goals: goals,
            hasMarkedToday: hasMarkedToday,
          )
        : HomeDataEmpty(nickname: nickname);
  }

  void setGoalsControllers(List<GoalModel>? goals) {
    if (goals == null) return;

    for (final controller in goalsControllers) {
      controller.dispose();
    }
    goalsControllers = [
      for (final goal in goals) TextEditingController(text: goal.name),
    ];
  }

  Future<void> saveData() async {
    final current = state;
    // _saving holds across the await; hasMarkedToday is only emitted after it,
    // so on its own it lets a double tap append today twice.
    if (_saving ||
        current is! HomeData ||
        current.hasMarkedToday ||
        current.goals.isEmpty) {
      return;
    }
    _saving = true;

    try {
      // Snapshot, so later slider drags and renames cannot reach the history.
      final snapshot = [
        for (var i = 0; i < current.goals.length; i++)
          current.goals[i].copyWith(name: goalsControllers[i].text),
      ];

      for (var i = 0; i < current.goals.length; i++) {
        current.goals[i].name = goalsControllers[i].text;
      }

      userData.add(DateGoalModel(date: _today, goals: snapshot));
      await localData.saveUserData(userData);

      emit(
        HomeData(
          nickname: current.nickname,
          goals: current.goals,
          hasMarkedToday: true,
        ),
      );
    } finally {
      _saving = false;
    }
  }

  void addNewGoal() {
    final current = state;
    if (current is! HomeData) return;

    // Read the live text back before rebuilding, so in-progress typing on the
    // other rows survives.
    for (var i = 0; i < current.goals.length; i++) {
      current.goals[i].name = goalsControllers[i].text;
    }

    final goals = [
      ...current.goals,
      GoalModel(name: 'New Goal', percentCompleted: 0),
    ];

    goalsControllers.add(TextEditingController(text: 'New Goal'));

    emit(
      HomeData(
        nickname: current.nickname,
        goals: goals,
        hasMarkedToday: current.hasMarkedToday,
      ),
    );
  }

  void removeGoal(int index) {
    final current = state;
    if (current is! HomeData || current.hasMarkedToday) return;

    final goals = [...current.goals]..removeAt(index);
    goalsControllers.removeAt(index).dispose();

    emit(
      goals.isNotEmpty
          ? HomeData(
              nickname: current.nickname,
              goals: goals,
              hasMarkedToday: current.hasMarkedToday,
            )
          : HomeDataEmpty(
              nickname: current.nickname,
              hasMarkedToday: current.hasMarkedToday,
            ),
    );
  }

  @override
  void onDispose() {
    LocalData.revision.removeListener(reload);
    for (final controller in goalsControllers) {
      controller.dispose();
    }
    goalsControllers = [];
    super.onDispose();
  }
}
