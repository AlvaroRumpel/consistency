import 'package:consistency/configs/colors.dart';
import 'package:consistency/configs/text_styles.dart';
import 'package:consistency/controllers/home_controller.dart';
import 'package:consistency/providers/theme_provider.dart';
import 'package:flutter/material.dart';

import '../configs/utilities.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  HomePageState createState() => HomePageState();
}

class HomePageState extends State<HomePage> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _iconAnimationController;
  late Animation<double> _animation;
  late Animation<double> _iconAnimation;

  late HomeController controller;

  @override
  void initState() {
    _animationController =
        AnimationController(vsync: this, duration: const Duration(seconds: 2));
    _iconAnimationController =
        AnimationController(vsync: this, duration: const Duration(seconds: 1));
    _animation = Tween(begin: 18.0, end: 0.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _iconAnimation =
        Tween<double>(begin: 0.0, end: 1.0).animate(_iconAnimationController);

    _animationController.repeat(reverse: true);

    super.initState();

    controller = HomeController();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _iconAnimationController.dispose();
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
                ValueListenableBuilder(
                  valueListenable: controller.nickname,
                  builder: (context, value, _) {
                    return Wrap(
                      alignment: WrapAlignment.center,
                      children: [
                        Text(
                          'How are you ',
                          style: context.textStyles.normalText
                              .copyWith(fontSize: 32),
                        ),
                        Text(
                          '$value?',
                          style: context.textStyles.normalText.copyWith(
                            fontSize: 32,
                            color: AppColors.primaryColor,
                          ),
                        ),
                      ],
                    );
                  },
                ),
                Text(
                  'Did you complete your goals today?',
                  style: context.textStyles.normalText,
                  textAlign: TextAlign.center,
                ),
                Center(
                  child: AnimatedBuilder(
                    animation: _animation,
                    builder: (context, child) {
                      if (controller.hasMarketToday.value) {
                        _iconAnimationController.forward();
                      }
                      return Ink(
                        height: MediaQuery.of(context).size.height * .5,
                        width: MediaQuery.of(context).size.width * .6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.primaryColor,
                            width: 2 + (_animation.value / 4),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primaryColor.shade900
                                  .withOpacity(.5),
                              spreadRadius: _animation.value,
                            ),
                            BoxShadow(
                              color: ThemeProvider.of(context).themeMode ==
                                      ThemeMode.dark
                                  ? AppColors.blackColor.shade500
                                  : AppColors.whiteColor.shade700,
                              spreadRadius: _animation.value / 1.5,
                            ),
                          ],
                        ),
                        child: InkWell(
                          onTap: () {
                            if (!controller.hasMarketToday.value &&
                                controller.goals.value != null) {
                              controller.saveData();
                              _iconAnimationController.forward();
                            }
                          },
                          highlightColor: AppColors.primaryColor,
                          splashColor: Utilities.activeColor(
                              controller.completePercent.value),
                          customBorder: const CircleBorder(),
                          child: Center(
                            child: AnimatedIcon(
                              icon: AnimatedIcons.add_event,
                              progress: _iconAnimation,
                              color: ThemeProvider.of(context).themeMode ==
                                      ThemeMode.dark
                                  ? AppColors.whiteColor
                                  : AppColors.blackColor.shade300,
                              size: MediaQuery.of(context).size.width * .2,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          SliverList(
            delegate: SliverChildListDelegate([
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
                child: Visibility(
                  visible: controller.goals.value != null ||
                      !controller.hasMarketToday.value,
                  replacement: ValueListenableBuilder(
                    valueListenable: controller.completePercent,
                    builder: (context, value, _) {
                      return Column(
                        children: [
                          ValueListenableBuilder(
                            valueListenable: controller.hasMarketToday,
                            builder: (context, hasMarketToday, _) {
                              return Slider(
                                value: value,
                                max: 100,
                                min: 0,
                                divisions: 4,
                                inactiveColor: AppColors.whiteColor,
                                activeColor: Utilities.activeColor(value),
                                label: '${value.toStringAsFixed(0)}%',
                                onChanged: hasMarketToday
                                    ? null
                                    : (value) => controller
                                        .completePercent.value = value,
                              );
                            },
                          ),
                        ],
                      );
                    },
                  ),
                  child: ValueListenableBuilder(
                    valueListenable: controller.goals,
                    builder: (context, value, _) {
                      return ValueListenableBuilder(
                        valueListenable: controller.hasMarketToday,
                        builder: (context, hasMarketToday, _) {
                          return ListView.separated(
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: value?.length ?? 1,
                            shrinkWrap: true,
                            itemBuilder: (context, index) {
                              return value != null && value.isNotEmpty
                                  ? Column(
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: TextFormField(
                                                controller: controller
                                                    .goalsControllers[index],
                                                maxLength: 50,
                                                style: context
                                                    .textStyles.normalText,
                                                enabled: !hasMarketToday,
                                                cursorColor:
                                                    ThemeProvider.of(context)
                                                                .themeMode ==
                                                            ThemeMode.dark
                                                        ? AppColors
                                                            .whiteColor.shade50
                                                        : AppColors.blackColor,
                                                decoration: InputDecoration(
                                                  counterText: '',
                                                  label: Text(
                                                    'Goal name',
                                                    style: context
                                                        .textStyles.normalText,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            Visibility(
                                              visible: !hasMarketToday,
                                              child: IconButton(
                                                onPressed: () => controller
                                                    .removeGoal(index),
                                                style: IconButton.styleFrom(
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            100),
                                                    side: const BorderSide(
                                                      color: AppColors.redColor,
                                                      width: 2,
                                                    ),
                                                  ),
                                                ),
                                                icon: const Icon(
                                                  Icons.remove,
                                                  color: AppColors.redColor,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        Slider(
                                          value: value[index].percentCompleted,
                                          max: 100,
                                          min: 0,
                                          divisions: 4,
                                          inactiveColor: AppColors.whiteColor,
                                          activeColor: Utilities.activeColor(
                                              value[index].percentCompleted),
                                          label:
                                              '${value[index].percentCompleted.toStringAsFixed(0)}%',
                                          onChanged: hasMarketToday
                                              ? null
                                              : (v) {
                                                  setState(() {
                                                    value[index]
                                                        .percentCompleted = v;
                                                  });
                                                },
                                        ),
                                        Visibility(
                                          visible: index == value.length - 1 &&
                                              !hasMarketToday,
                                          child: IconButton(
                                            onPressed: controller.addNewGoal,
                                            style: IconButton.styleFrom(
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(100),
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
                                        )
                                      ],
                                    )
                                  : Column(
                                      children: [
                                        IconButton(
                                          onPressed: controller.addNewGoal,
                                          style: IconButton.styleFrom(
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(100),
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
                                      ],
                                    );
                            },
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 4),
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
            ]),
          )
        ],
      ),
    );
  }
}
