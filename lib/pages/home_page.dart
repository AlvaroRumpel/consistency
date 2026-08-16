import 'package:flutter/material.dart';

import '../configs/colors.dart';
import '../configs/text_styles.dart';
import '../configs/utilities.dart';
import '../controllers/home_controller.dart';
import '../widgets/add_day_button.dart';
import '../widgets/error_view.dart';
import '../widgets/goals_list_view.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  HomePageState createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  late HomeController _controller;

  @override
  void initState() {
    super.initState();
    _controller = HomeController();
  }

  @override
  void dispose() {
    _controller.onDispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24.0),
      child: CustomScrollView(
        slivers: [
          SliverList(
            delegate: SliverChildListDelegate.fixed(
              [
                Wrap(
                  alignment: WrapAlignment.center,
                  children: [
                    Text(
                      'How are you ',
                      style:
                          context.textStyles.normalText.copyWith(fontSize: 32),
                    ),
                    ValueListenableBuilder(
                      valueListenable: _controller.stateNotifier,
                      builder: (context, value, _) {
                        final nickname =
                            value is HomeData ? value.nickname : 'user';
                        return Text(
                          '$nickname?',
                          style: context.textStyles.normalText.copyWith(
                            fontSize: 32,
                            color: AppColors.primaryColor,
                          ),
                        );
                      },
                    ),
                  ],
                ),
                Text(
                  'Did you complete your goals today?',
                  style: context.textStyles.normalText,
                  textAlign: TextAlign.center,
                ),
                ValueListenableBuilder(
                  valueListenable: _controller.stateNotifier,
                  builder: (context, state, _) {
                    return AddDayButton(
                      color: Utilities.activeColor(_controller.completePercent),
                      onTap: () {
                        if (state is HomeData &&
                            !state.hasMarkedToday &&
                            state.goals.isNotEmpty) {
                          _controller.saveData();

                          return true;
                        }

                        return false;
                      },
                      hasMarkedToday:
                          state is HomeData ? state.hasMarkedToday : true,
                    );
                  },
                ),
              ],
            ),
          ),
          SliverList(
            delegate: SliverChildListDelegate(
              [
                Text(
                  'How much completed?',
                  style: context.textStyles.normalText.copyWith(fontSize: 24),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 8.0,
                    horizontal: 16,
                  ),
                  child: ValueListenableBuilder(
                    valueListenable: _controller.stateNotifier,
                    builder: (context, state, _) {
                      return switch (state) {
                        HomeDataEmpty() => IconButton(
                            onPressed: _controller.addNewGoal,
                            style: IconButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(100),
                                side: const BorderSide(
                                  color: AppColors.primaryColor,
                                  width: 2,
                                ),
                              ),
                            ),
                            icon: const Icon(
                              Icons.add,
                              color: AppColors.primaryColor,
                            ),
                          ),
                        HomeData(:final goals, :final hasMarkedToday) =>
                          GoalsListView(
                            goals: goals,
                            textControllers: _controller.goalsControllers,
                            hasMarkedToday: hasMarkedToday,
                            onRemove: _controller.removeGoal,
                            onAdd: _controller.addNewGoal,
                          ),
                        HomeError(:final message) => ErrorView(
                            message: message,
                            onRetry: _controller.reload,
                          ),
                        HomeInitial() || HomeLoading() =>
                          const SizedBox.shrink(),
                      };
                    },
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}
