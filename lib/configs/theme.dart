import 'package:flutter/material.dart';

import 'colors.dart';
import 'local_data.dart';
import 'text_styles.dart';

class ThemeModel extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;

  ThemeModel() {
    _load();
  }

  ThemeMode get themeMode => _themeMode;

  Future<void> _load() async {
    final localData = await LocalData.i;
    _themeMode = switch (localData.searchTheme()) {
      null => ThemeMode.system,
      true => ThemeMode.dark,
      false => ThemeMode.light,
    };
    notifyListeners();
  }

  Future<void> setMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    final localData = await LocalData.i;
    await localData.saveThemeDark(switch (mode) {
      ThemeMode.system => null,
      ThemeMode.dark => true,
      ThemeMode.light => false,
    });
  }
}

ThemeData themeDark = ThemeData(
  brightness: Brightness.dark,
  primarySwatch: AppColors.primaryColor,
  primaryColor: AppColors.primaryColor,
  scaffoldBackgroundColor: AppColors.blackColor,
  useMaterial3: true,
  cardColor: AppColors.blackColor,
  iconTheme: const IconThemeData(color: AppColors.whiteColor),
  dividerColor: AppColors.whiteColor.shade900.withValues(alpha: .3),
  inputDecorationTheme: InputDecorationTheme(
    disabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(30),
      borderSide: BorderSide(
        color: AppColors.blackColor.shade200,
        width: 2,
      ),
    ),
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
    labelStyle: const TextStyles(true).normalText,
    floatingLabelStyle: const TextStyles(true).normalText,
    errorStyle:
        const TextStyles(true).normalText.copyWith(color: AppColors.redColor),
  ),
  progressIndicatorTheme: const ProgressIndicatorThemeData(
    color: AppColors.primaryColor,
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.primaryColor,
      textStyle: const TextStyles(true).normalText,
      alignment: Alignment.center,
      foregroundColor: AppColors.primaryColor.shade900,
    ),
  ),
  textSelectionTheme: TextSelectionThemeData(
    selectionColor: AppColors.primaryColor.shade50.withValues(alpha: .5),
    selectionHandleColor: AppColors.primaryColor,
    cursorColor: AppColors.whiteColor,
  ),
  navigationBarTheme: NavigationBarThemeData(
    backgroundColor: AppColors.blackColor.shade700,
    labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
    indicatorColor: AppColors.primaryColor,
    indicatorShape: const CircleBorder(),
    labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>(
      (value) {
        if (value.contains(WidgetState.selected)) {
          return const TextStyles(true).normalText;
        }
        return const TextStyles(true).normalText.copyWith(
              color: AppColors.whiteColor.shade900,
            );
      },
    ),
    iconTheme: WidgetStateProperty.resolveWith<IconThemeData>(
      (value) {
        if (value.contains(WidgetState.selected)) {
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
  brightness: Brightness.light,
  primarySwatch: AppColors.primaryColor,
  primaryColor: AppColors.primaryColor,
  scaffoldBackgroundColor: AppColors.whiteColor.shade700,
  useMaterial3: true,
  cardColor: AppColors.whiteColor.shade700,
  iconTheme: const IconThemeData(color: AppColors.blackColor),
  dividerColor: AppColors.blackColor.withValues(alpha: .3),
  inputDecorationTheme: InputDecorationTheme(
    disabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(30),
      borderSide: BorderSide(
        color: AppColors.blackColor.shade200,
        width: 2,
      ),
    ),
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
    labelStyle: const TextStyles(false).normalText,
    floatingLabelStyle: const TextStyles(false).normalText,
    errorStyle:
        const TextStyles(false).normalText.copyWith(color: AppColors.redColor),
  ),
  progressIndicatorTheme: const ProgressIndicatorThemeData(
    color: AppColors.primaryColor,
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.primaryColor,
      textStyle: const TextStyles(false)
          .normalText
          .copyWith(color: AppColors.whiteColor),
      alignment: Alignment.center,
      foregroundColor: AppColors.primaryColor.shade700,
    ),
  ),
  textSelectionTheme: TextSelectionThemeData(
    selectionColor: AppColors.primaryColor.shade50.withValues(alpha: .5),
    selectionHandleColor: AppColors.primaryColor,
    cursorColor: AppColors.blackColor,
  ),
  navigationBarTheme: NavigationBarThemeData(
    backgroundColor: AppColors.whiteColor.shade900,
    labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
    indicatorColor: AppColors.primaryColor,
    indicatorShape: const CircleBorder(),
    labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>(
      (value) {
        if (value.contains(WidgetState.selected)) {
          return const TextStyles(false).normalText;
        }
        return const TextStyles(false).normalText.copyWith(
              color: AppColors.blackColor,
            );
      },
    ),
    iconTheme: WidgetStateProperty.resolveWith<IconThemeData>(
      (value) {
        if (value.contains(WidgetState.selected)) {
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
