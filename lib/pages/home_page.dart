import 'package:consistency/configs/colors.dart';
import 'package:consistency/configs/text_styles.dart';
import 'package:consistency/controllers/home_controller.dart';
import 'package:consistency/providers/theme_provider.dart';
import 'package:flutter/material.dart';

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
      child: Column(
        children: [
          ValueListenableBuilder(
            valueListenable: controller.nickname,
            builder: (context, value, _) {
              return Wrap(
                alignment: WrapAlignment.center,
                children: [
                  Text(
                    'How are you ',
                    style: context.textStyles.normalText.copyWith(fontSize: 32),
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
          ),
          Flexible(
            child: Center(
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
                          color:
                              AppColors.primaryColor.shade900.withOpacity(.5),
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
                        if (!controller.hasMarketToday.value) {
                          controller.saveData();
                          _iconAnimationController.forward();
                        }
                      },
                      highlightColor: AppColors.primaryColor,
                      splashColor: controller
                          .activeColor(controller.completePercent.value),
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
          ),
          Text(
            'How much completed?',
            style: context.textStyles.normalText.copyWith(fontSize: 24),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: ValueListenableBuilder(
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
                            activeColor: controller.activeColor(value),
                            label: '${value.toStringAsFixed(0)}%',
                            onChanged: hasMarketToday
                                ? null
                                : (value) =>
                                    controller.completePercent.value = value,
                          );
                        }),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
