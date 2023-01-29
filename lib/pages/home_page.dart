import 'package:consistency/configs/colors.dart';
import 'package:flutter/material.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  HomePageState createState() => HomePageState();
}

class HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    _animationController =
        AnimationController(vsync: this, duration: const Duration(seconds: 2));
    _animation = Tween(begin: 18.0, end: 0.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _animationController.repeat(reverse: true);

    super.initState();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Flexible(
          child: Center(
            child: AnimatedBuilder(
              animation: _animation,
              builder: (context, child) {
                return InkWell(
                  child: Container(
                    height: MediaQuery.of(context).size.height * .5,
                    width: MediaQuery.of(context).size.width * .6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.blackColor,
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
                          color: AppColors.blackColor.shade500,
                          spreadRadius: _animation.value / 1.5,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.add_rounded,
                      color: AppColors.whiteColor,
                      size: MediaQuery.of(context).size.width * .3,
                    ),
                  ),
                );
              },
            ),
          ),
        )
      ],
    );
  }
}
