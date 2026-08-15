import 'package:flutter/material.dart';

import '../configs/colors.dart';
import '../providers/theme_provider.dart';

class AddDayButton extends StatefulWidget {
  const AddDayButton({
    super.key,
    required this.onTap,
    required this.hasMarkedToday,
    required this.color,
  });
  final bool Function() onTap;
  final bool hasMarkedToday;
  final Color color;

  @override
  State<AddDayButton> createState() => _AddDayButtonState();
}

class _AddDayButtonState extends State<AddDayButton>
    with TickerProviderStateMixin {
  late Animation<double> _animation;
  late Animation<double> _iconAnimation;
  late AnimationController _animationController;
  late AnimationController _iconAnimationController;

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
  }

  @override
  void dispose() {
    _animationController.dispose();
    _iconAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          if (widget.hasMarkedToday) {
            _iconAnimationController.forward();
          } else {
            _iconAnimationController.reverse();
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
                  color: AppColors.primaryColor.shade900.withValues(alpha: .5),
                  spreadRadius: _animation.value,
                ),
                BoxShadow(
                  color: ThemeProvider.of(context).themeMode == ThemeMode.dark
                      ? AppColors.blackColor.shade500
                      : AppColors.whiteColor.shade700,
                  spreadRadius: _animation.value / 1.5,
                ),
              ],
            ),
            child: InkWell(
              onTap: () {
                if (widget.onTap()) _iconAnimationController.forward();
              },
              highlightColor: AppColors.primaryColor,
              splashColor: widget.color,
              customBorder: const CircleBorder(),
              child: Center(
                child: AnimatedIcon(
                  icon: AnimatedIcons.add_event,
                  progress: _iconAnimation,
                  color: ThemeProvider.of(context).themeMode == ThemeMode.dark
                      ? AppColors.whiteColor
                      : AppColors.blackColor.shade300,
                  size: MediaQuery.of(context).size.width * .2,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
