import 'package:flutter/material.dart';

import '../configs/colors.dart';
import '../configs/text_styles.dart';
import '../controllers/skeleton_controller.dart';
import 'calendar_page.dart';
import 'home_page.dart';
import 'settings_page.dart';

class SkelentonPage extends StatefulWidget {
  const SkelentonPage({super.key});

  @override
  SkelentonPageState createState() => SkelentonPageState();
}

class SkelentonPageState extends State<SkelentonPage>
    with SingleTickerProviderStateMixin {
  late SkeletonController _controller;

  final _pageController = PageController(initialPage: 1);

  late AnimationController _animationController;
  late Animation<double> animationIconPosition;
  late Animation<double> animationLabelPosition;
  late Animation<double> animationLabelOpacity;
  late Animation<Size> animationBoxSize;

  @override
  void initState() {
    _controller = SkeletonController(_pageController.initialPage);

    _animationController = AnimationController(
      vsync: this,
      duration: Durations.short4,
    );

    animationIconPosition = Tween(begin: 24.0, end: 16.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOut,
      ),
    );

    animationLabelPosition = Tween(begin: 64.0, end: 40.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOut,
      ),
    );

    animationLabelOpacity = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOut,
      ),
    );

    animationBoxSize = Tween(
      begin: const Size(70, 70),
      end: const Size(80, 80),
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOut,
      ),
    );
    _animationController.forward();

    super.initState();
  }

  @override
  void dispose() {
    _controller.onDispose();
    _animationController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void changePage(int index) {
    _controller.changePage(index);
    _pageController.jumpToPage(_controller.state);
    _controller.state == 1
        ? _animationController.forward()
        : _animationController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: _controller.stateNotifier,
      builder: (context, value, child) => Scaffold(
        body: PageView(
          controller: _pageController,
          onPageChanged: changePage,
          children: const [
            CalendarPage(),
            HomePage(),
            SettingsPage(),
          ],
        ),
        resizeToAvoidBottomInset: false,
        bottomNavigationBar: NavigationBar(
          onDestinationSelected: changePage,
          selectedIndex: value,
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
            animation: _animationController,
            builder: (context, child) {
              return SizedBox(
                height: animationBoxSize.value.height,
                width: animationBoxSize.value.width,
                child: FloatingActionButton(
                  backgroundColor: value == 1
                      ? AppColors.primaryColor
                      : Theme.of(context).colorScheme.surfaceContainer,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  onPressed: () => changePage(1),
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: AlignmentDirectional.center,
                    children: [
                      Positioned(
                        top: animationIconPosition.value,
                        child: Icon(
                          Icons.home_outlined,
                          color: value == 1
                              ? Colors.white
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Positioned(
                        top: animationLabelPosition.value,
                        child: Opacity(
                          opacity: animationLabelOpacity.value,
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
