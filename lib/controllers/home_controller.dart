import 'package:flutter/material.dart';

import '../configs/local_data.dart';
import '../models/date_goal_model.dart';
import '../models/goal_model.dart';
import 'base_controller.dart';

sealed class HomeState {
  T when<T>({
    required T Function(HomeInitial) initial,
    required T Function(HomeData) data,
    required T Function(HomeDataEmpty) dataEmpty,
    required T Function(HomeDataLoading) dataLoading,
    required T Function(HomeLoading) loading,
    required T Function(HomeError) error,
  }) {
    if (this is HomeInitial) {
      return initial(this as HomeInitial);
    } else if (this is HomeDataEmpty) {
      return dataEmpty(this as HomeDataEmpty);
    } else if (this is HomeDataLoading) {
      return dataLoading(this as HomeDataLoading);
    } else if (this is HomeData) {
      return data(this as HomeData);
    } else if (this is HomeLoading) {
      return loading(this as HomeLoading);
    } else if (this is HomeError) {
      return error(this as HomeError);
    } else {
      throw Exception('Unknown HomeState: $this');
    }
  }

  T whenNull<T>({
    T Function(HomeInitial)? initial,
    T Function(HomeData)? data,
    T Function(HomeDataEmpty)? dataEmpty,
    T Function(HomeDataLoading)? dataLoading,
    T Function(HomeLoading)? loading,
    T Function(HomeError)? error,
    required T Function() orElse,
  }) {
    if (this is HomeInitial && initial != null) {
      return initial(this as HomeInitial);
    } else if (this is HomeDataEmpty && dataEmpty != null) {
      return dataEmpty(this as HomeDataEmpty);
    } else if (this is HomeDataLoading && dataLoading != null) {
      return dataLoading(this as HomeDataLoading);
    } else if (this is HomeData && data != null) {
      return data(this as HomeData);
    } else if (this is HomeLoading && loading != null) {
      return loading(this as HomeLoading);
    } else if (this is HomeError && error != null) {
      return error(this as HomeError);
    } else {
      return orElse();
    }
  }
}

class HomeInitial extends HomeState {}

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

class HomeDataLoading extends HomeData {
  HomeDataLoading({
    required super.nickname,
    super.goals = const [],
    super.hasMarkedToday = false,
  });
}

class HomeLoading extends HomeState {}

class HomeError extends HomeState {
  final String message;

  HomeError({required this.message});
}

class HomeController extends BaseController<HomeState> {
  late LocalData localData;
  double completePercent = 100.0;
  List<TextEditingController> goalsControllers = <TextEditingController>[];
  final userData = <DateGoalModel>[];

  HomeController() : super(HomeInitial());

  @override
  void onInit() async {
    localData = await LocalData.i;
    emitGuard(
      loadingState: HomeLoading(),
      newState: recoveryData,
      errorState: (e) => HomeError(message: e.toString()),
    );
  }

  Future<HomeState> recoveryData([HomeState? oldState]) async {
    final nickname = await localData.searchNickname() ?? 'User';
    final userGoals = await localData.searchUserData();

    userData.addAll(userGoals ?? []);

    if (userGoals == null) {
      return HomeDataEmpty(nickname: nickname);
    }

    final hasMarkedToday = userGoals.any(
      (item) =>
          item.date ==
          DateTime(
            DateTime.now().year,
            DateTime.now().month,
            DateTime.now().day,
          ),
    );
    final goals = [...userGoals.last.goals];

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
    if (goals == null) {
      return;
    }

    goalsControllers.clear();

    for (var goal in goals) {
      goalsControllers.add(TextEditingController(text: goal.name));
    }
  }

  Future<void> saveData() async {
    final newState = state as HomeData;
    emit(
      HomeDataLoading(
        nickname: newState.nickname,
        goals: newState.goals,
        hasMarkedToday: newState.hasMarkedToday,
      ),
    );

    final currentDate = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );

    var totalPercentCompleted = 0.0;
    final goals = newState.goals;
    for (var i = 0; i < goals.length; i++) {
      goals[i].name = goalsControllers[i].text;
      totalPercentCompleted = goals[i].percentCompleted + totalPercentCompleted;
    }

    userData.add(DateGoalModel(date: currentDate, goals: goals));

    final hasMarkedToday = await localData.saveUserData(userData);

    emit(
      goals.isNotEmpty
          ? HomeData(
              nickname: newState.nickname,
              goals: goals,
              hasMarkedToday: hasMarkedToday,
            )
          : HomeDataEmpty(
              nickname: newState.nickname,
              hasMarkedToday: newState.hasMarkedToday,
            ),
    );
  }

  void addNewGoal() {
    final newState = state as HomeData;
    emit(HomeDataLoading(
      nickname: newState.nickname,
      goals: newState.goals,
      hasMarkedToday: newState.hasMarkedToday,
    ));
    var goals = (state as HomeData).goals;

    goals = [...goals, GoalModel(name: 'New Goal', percentCompleted: 0)];

    setGoalsControllers(goals);

    emit(
      goals.isNotEmpty
          ? HomeData(
              nickname: newState.nickname,
              goals: goals,
              hasMarkedToday: newState.hasMarkedToday,
            )
          : HomeDataEmpty(
              nickname: newState.nickname,
              hasMarkedToday: newState.hasMarkedToday,
            ),
    );
  }

  void removeGoal(int index) {
    final newState = state as HomeData;
    emit(
      HomeDataLoading(
        nickname: newState.nickname,
        goals: newState.goals,
        hasMarkedToday: newState.hasMarkedToday,
      ),
    );

    if (newState.hasMarkedToday) return;

    var goals = (state as HomeData).goals;
    var goalsCopy = [...goals];
    goalsCopy.removeAt(index);
    goals = goalsCopy;
    goalsControllers.removeAt(index);

    emit(
      goals.isNotEmpty
          ? HomeData(
              nickname: newState.nickname,
              goals: goals,
              hasMarkedToday: newState.hasMarkedToday,
            )
          : HomeDataEmpty(
              nickname: newState.nickname,
              hasMarkedToday: newState.hasMarkedToday,
            ),
    );
  }
}
