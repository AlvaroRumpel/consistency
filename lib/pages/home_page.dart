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
    _animation = Tween(begin: 26.0, end: 0.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
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
          child: AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              return Stack(
                alignment: AlignmentDirectional.center,
                children: [
                  InkWell(
                    child: Container(
                      height: MediaQuery.of(context).size.height * .5,
                      width: MediaQuery.of(context).size.width * .6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primaryColor,
                        boxShadow: [
                          for (int i = 1; i <= 2; i++)
                            BoxShadow(
                              color: i == 1
                                  ? AppColors.primaryColor.shade900
                                  : AppColors.blackColor.shade500,
                              spreadRadius: _animation.value / i,
                              blurRadius: 0,
                            )
                          // BoxShadow(
                          //   color: AppColors.primaryColor.shade50,
                          //   spreadRadius: 18,
                          // ),
                          // BoxShadow(
                          //   color: AppColors.blackColor.shade500,
                          //   spreadRadius: 12,
                          // ),
                        ],
                      ),
                      child: Icon(
                        Icons.add,
                        color: AppColors.whiteColor,
                        size: MediaQuery.of(context).size.width * .3,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        )
      ],
    );
  }
}
