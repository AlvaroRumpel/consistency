import 'package:consistency/configs/colors.dart';
import 'package:consistency/configs/text_styles.dart';
import 'package:consistency/controllers/manager_controller.dart';
import 'package:consistency/pages/calendar_page.dart';
import 'package:consistency/pages/home_page.dart';
import 'package:consistency/pages/settings_page.dart';
import 'package:consistency/providers/theme_provider.dart';
import 'package:flutter/material.dart';

class Skelenton extends StatefulWidget {
  const Skelenton({Key? key}) : super(key: key);

  @override
  SkelentonState createState() => SkelentonState();
}

class SkelentonState extends State<Skelenton>
    with SingleTickerProviderStateMixin {
  late SkeletonController controller;

  @override
  void initState() {
    controller = SkeletonController(vsync: this);
    super.initState();
  }

  @override
  void dispose() {
    controller.onDispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: controller.currentIndex,
      builder: (context, value, child) => Scaffold(
        body: PageView(
          controller: controller.pageController,
          onPageChanged: (index) => controller.changePage(index),
          children: const [
            CalendarPage(),
            HomePage(),
            SettingsPage(),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          onDestinationSelected: (index) => controller.changePage(index),
          selectedIndex: controller.currentIndex.value,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.calendar_month_outlined),
              label: 'Calendar',
            ),
            NavigationDestination(
              icon: SizedBox(width: 0, height: 0),
              label: '',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              label: 'Settings',
            ),
          ],
        ),
        floatingActionButton: Align(
          alignment: Alignment.bottomCenter,
          heightFactor: 6 / 4,
          child: AnimatedBuilder(
            animation: controller.animationController,
            builder: (context, child) {
              return SizedBox(
                height: controller.animationBoxSize.value.height,
                width: controller.animationBoxSize.value.width,
                child: FloatingActionButton(
                  backgroundColor:
                      ThemeProvider.of(context).themeMode == ThemeMode.dark
                          ? controller.currentIndex.value == 1
                              ? AppColors.primaryColor.shade500
                              : AppColors.primaryColor.shade900
                          : controller.currentIndex.value == 1
                              ? AppColors.primaryColor.shade50
                              : AppColors.primaryColor.shade500,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  onPressed: () => controller.changePage(1),
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: AlignmentDirectional.center,
                    children: [
                      Positioned(
                        top: controller.animationIconPosition.value,
                        child: Icon(
                          Icons.home_outlined,
                          color: ThemeProvider.of(context).themeMode ==
                                  ThemeMode.dark
                              ? controller.currentIndex.value == 1
                                  ? AppColors.whiteColor.shade500
                                  : AppColors.whiteColor.shade900
                              : controller.currentIndex.value == 1
                                  ? AppColors.blackColor.shade500
                                  : AppColors.blackColor.shade900,
                        ),
                      ),
                      Positioned(
                        top: controller.animationLabelPosition.value,
                        child: Opacity(
                          opacity: controller.animationLabelOpacity.value,
                          child: Text(
                            'Home',
                            style: context.textStyles.normalText,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        floatingActionButtonLocation:
            FloatingActionButtonLocation.miniCenterDocked,
      ),
    );
  }
}
