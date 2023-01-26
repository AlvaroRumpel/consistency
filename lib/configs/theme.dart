import 'package:consistency/configs/colors.dart';
import 'package:flutter/material.dart';

ThemeData theme = ThemeData(
  primarySwatch: AppColors.primaryColor,
  scaffoldBackgroundColor: AppColors.blackColor,
  useMaterial3: true,
  navigationBarTheme: NavigationBarThemeData(
    backgroundColor: AppColors.blackColor.shade700,
    labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
    indicatorColor: AppColors.primaryColor,
    indicatorShape: const CircleBorder(),
    labelTextStyle: MaterialStateProperty.resolveWith<TextStyle>(
      (value) {
        if (value.contains(MaterialState.selected)) {
          return const TextStyle(
            color: AppColors.whiteColor,
            fontSize: 16,
            fontWeight: FontWeight.w400,
          );
        }
        return TextStyle(
          color: AppColors.whiteColor.shade900,
          // fontSize: 16,
          fontWeight: FontWeight.w400,
        );
      },
    ),
    iconTheme: MaterialStateProperty.resolveWith<IconThemeData>(
      (value) {
        if (value.contains(MaterialState.selected)) {
          return const IconThemeData(
            color: AppColors.whiteColor,
          );
        }
        return IconThemeData(
          color: AppColors.whiteColor.shade900,
        );
      },
    ),
  ),
);
