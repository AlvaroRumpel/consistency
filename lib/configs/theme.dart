import 'package:consistency/configs/colors.dart';
import 'package:consistency/configs/text_styles.dart';
import 'package:flutter/material.dart';

ThemeData theme = ThemeData(
  primarySwatch: AppColors.primaryColor,
  scaffoldBackgroundColor: AppColors.blackColor,
  useMaterial3: true,
  inputDecorationTheme: InputDecorationTheme(
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(30),
      borderSide: BorderSide(
        color: AppColors.blackColor.shade100,
        width: 2,
      ),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(30),
      borderSide: BorderSide(
        color: AppColors.primaryColor.shade50,
        width: 2,
      ),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(30),
      borderSide: BorderSide(
        color: AppColors.redColor.shade200,
        width: 2,
      ),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(30),
      borderSide: const BorderSide(
        color: AppColors.redColor,
        width: 2,
      ),
    ),
    contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
    labelStyle: TextStyles.i.normalText,
    floatingLabelStyle: TextStyles.i.normalText,
    errorStyle: TextStyles.i.normalText.copyWith(color: AppColors.redColor),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.primaryColor,
      textStyle: TextStyles.i.normalText,
      alignment: Alignment.center,
      foregroundColor: AppColors.primaryColor.shade900,
    ),
  ),
  textSelectionTheme: TextSelectionThemeData(
    selectionColor: AppColors.primaryColor.shade50.withOpacity(.5),
    selectionHandleColor: AppColors.primaryColor,
    cursorColor: AppColors.whiteColor,
  ),
  navigationBarTheme: NavigationBarThemeData(
    backgroundColor: AppColors.blackColor.shade700,
    labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
    indicatorColor: AppColors.primaryColor,
    indicatorShape: const CircleBorder(),
    labelTextStyle: MaterialStateProperty.resolveWith<TextStyle>(
      (value) {
        if (value.contains(MaterialState.selected)) {
          return TextStyles.i.normalText;
        }
        return TextStyles.i.normalText.copyWith(
          color: AppColors.whiteColor.shade900,
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
