import 'package:consistency/configs/colors.dart';
import 'package:consistency/providers/theme_provider.dart';
import 'package:flutter/material.dart';

class TextStyles {
  static TextStyles? _instance;
  static bool _isDark = true;

  TextStyles._();
  static TextStyles get i {
    _instance ??= TextStyles._();
    return _instance!;
  }

  void setIsDark(bool value) {
    _isDark = value;
  }

  final String font = 'WorkSans';

  TextStyle get normalText => TextStyle(
        color: _isDark ? AppColors.whiteColor : AppColors.blackColor,
        fontWeight: FontWeight.w400,
        fontFamily: font,
        fontSize: 16,
      );
  TextStyle get boldText => TextStyle(
        color: _isDark ? AppColors.whiteColor : AppColors.blackColor,
        fontWeight: FontWeight.w700,
        fontFamily: font,
        fontSize: 16,
      );
  TextStyle get thinText => TextStyle(
        color: _isDark ? AppColors.whiteColor : AppColors.blackColor,
        fontWeight: FontWeight.w100,
        fontFamily: font,
        fontSize: 16,
      );

  TextStyle get titleText => boldText.copyWith(fontSize: 32);
}

extension TextStylesExtension on BuildContext {
  TextStyles get textStyles {
    TextStyles.i.setIsDark(ThemeProvider.of(this).themeMode == ThemeMode.dark);
    return TextStyles.i;
  }
}
