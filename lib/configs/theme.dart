import 'package:consistency/configs/colors.dart';
import 'package:consistency/configs/local_data.dart';
import 'package:consistency/configs/text_styles.dart';
import 'package:flutter/material.dart';

class ThemeModel extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.dark;

  ThemeModel() {
    setThemeMode();
  }

  ThemeMode get themeMode => _themeMode;

  Future<void> setThemeMode() async {
    var localData = await LocalData.i;
    _themeMode = localData.searchTheme() ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }

  void switchThemeMode() {
    _themeMode =
        _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
  }
}

ThemeData themeDark = ThemeData(
  primarySwatch: AppColors.primaryColor,
  primaryColor: AppColors.primaryColor,
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
  progressIndicatorTheme: const ProgressIndicatorThemeData(
    color: AppColors.primaryColor,
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

ThemeData themeLight = ThemeData(
  primarySwatch: AppColors.primaryColor,
  primaryColor: AppColors.primaryColor,
  scaffoldBackgroundColor: AppColors.whiteColor.shade700,
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
  progressIndicatorTheme: const ProgressIndicatorThemeData(
    color: AppColors.primaryColor,
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.primaryColor,
      textStyle: TextStyles.i.normalText.copyWith(color: AppColors.whiteColor),
      alignment: Alignment.center,
      foregroundColor: AppColors.primaryColor.shade700,
    ),
  ),
  textSelectionTheme: TextSelectionThemeData(
    selectionColor: AppColors.primaryColor.shade50.withOpacity(.5),
    selectionHandleColor: AppColors.primaryColor,
    cursorColor: AppColors.blackColor,
  ),
  navigationBarTheme: NavigationBarThemeData(
    backgroundColor: AppColors.whiteColor.shade900,
    labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
    indicatorColor: AppColors.primaryColor,
    indicatorShape: const CircleBorder(),
    labelTextStyle: MaterialStateProperty.resolveWith<TextStyle>(
      (value) {
        if (value.contains(MaterialState.selected)) {
          return TextStyles.i.normalText;
        }
        return TextStyles.i.normalText.copyWith(
          color: AppColors.blackColor,
        );
      },
    ),
    iconTheme: MaterialStateProperty.resolveWith<IconThemeData>(
      (value) {
        if (value.contains(MaterialState.selected)) {
          return const IconThemeData(
            color: AppColors.blackColor,
          );
        }
        return IconThemeData(
          color: AppColors.blackColor.shade900,
        );
      },
    ),
  ),
);
