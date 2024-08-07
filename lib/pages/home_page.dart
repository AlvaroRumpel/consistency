import 'package:flutter/material.dart';

import '../configs/colors.dart';
import '../configs/text_styles.dart';
import '../configs/utilities.dart';
import '../controllers/home_controller.dart';
import '../widgets/add_day_button.dart';
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
                        return value.whenNull(
                          data: (state) {
                            return Text(
                              '${state.nickname}?',
                              style: context.textStyles.normalText.copyWith(
                                fontSize: 32,
                                color: AppColors.primaryColor,
                              ),
                            );
                          },
                          orElse: () => Text(
                            'user?',
                            style: context.textStyles.normalText.copyWith(
                              fontSize: 32,
                              color: AppColors.primaryColor,
                            ),
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
                      return state.whenNull(
                        data: (state) {
                          final value = state.goals;
                          return GoalsListView(
                            goals: value,
                            textControllers: _controller.goalsControllers,
                            hasMarkedToday: state.hasMarkedToday,
                            onRemove: _controller.removeGoal,
                            onAdd: _controller.addNewGoal,
                          );
                        },
                        dataEmpty: (state) => IconButton(
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
                        orElse: () => const SizedBox.shrink(),
                      );
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
