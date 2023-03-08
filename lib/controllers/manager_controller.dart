import 'package:consistency/controllers/base_controller.dart';
import 'package:flutter/material.dart';

class SkeletonController extends BaseController<int> {
  SkeletonController({required this.vsync});

  ValueNotifier<int> currentIndex = ValueNotifier(1);
  PageController pageController = PageController(initialPage: 1);
  TickerProvider vsync;

  late AnimationController animationController;
  late Animation<double> animationIconPosition;
  late Animation<double> animationLabelPosition;
  late Animation<double> animationLabelOpacity;
  late Animation<Size> animationBoxSize;

  @override
  Future<void> onInit() async {
    animationController = AnimationController(
      vsync: vsync,
      duration: const Duration(milliseconds: 200),
    );
    animationIconPosition = Tween(
      begin: 24.0,
      end: 16.0,
    ).animate(
      CurvedAnimation(
        parent: animationController,
        curve: Curves.easeOut,
      ),
    );
    animationLabelPosition = Tween(
      begin: 64.0,
      end: 40.0,
    ).animate(
      CurvedAnimation(
        parent: animationController,
        curve: Curves.easeOut,
      ),
    );
    animationLabelOpacity = Tween(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: animationController,
        curve: Curves.easeOut,
      ),
    );
    animationBoxSize = Tween(
      begin: const Size(70, 70),
      end: const Size(80, 80),
    ).animate(
      CurvedAnimation(
        parent: animationController,
        curve: Curves.easeOut,
      ),
    );
    animationController.forward();
  }

  @override
  void onDispose() {
    animationController.dispose();
    pageController.dispose();
  }

  changePage(int index) {
    currentIndex.value = index;
    pageController.jumpToPage(index);
    currentIndex.value == 1
        ? animationController.forward()
        : animationController.reverse();
  }
}
