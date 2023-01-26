import 'package:consistency/configs/colors.dart';
import 'package:consistency/controllers/base_controller.dart';
import 'package:consistency/controllers/skeleton_controller.dart';
import 'package:consistency/pages/home_page.dart';
import 'package:flutter/material.dart';

class Skelenton extends StatefulWidget {
  const Skelenton({this.controller, Key? key}) : super(key: key);

  final BaseController? controller;

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
    widget.controller != null ? widget.controller!.onInit() : null;
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
          children: [
            Text("1"),
            HomePage(),
            Text("3"),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          onDestinationSelected: (index) => controller.changePage(index),
          selectedIndex: controller.currentIndex.value,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.calendar_month_outlined),
              label: 'calendar',
            ),
            NavigationDestination(
              icon: SizedBox(width: 0, height: 0),
              label: '',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              label: 'settings',
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
                  backgroundColor: controller.currentIndex.value == 1
                      ? AppColors.primaryColor.shade500
                      : AppColors.primaryColor.shade900,
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
                          color: controller.currentIndex.value == 1
                              ? AppColors.whiteColor.shade500
                              : AppColors.whiteColor.shade900,
                        ),
                      ),
                      Positioned(
                        top: controller.animationLabelPosition.value,
                        child: Opacity(
                          opacity: controller.animationLabelOpacity.value,
                          child: Text(
                            'Home',
                            style:
                                TextStyle(color: AppColors.whiteColor.shade500),
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
