import 'package:flutter/material.dart';

import 'colors.dart';

class TextStyles {
  final bool isDark;

  const TextStyles(this.isDark);

  static const String font = 'WorkSans';

  Color get _color => isDark ? AppColors.whiteColor : AppColors.blackColor;

  TextStyle get normalText => TextStyle(
        color: _color,
        fontWeight: FontWeight.w500,
        fontFamily: font,
        fontSize: 16,
      );

  TextStyle get boldText => TextStyle(
        color: _color,
        fontWeight: FontWeight.w700,
        fontFamily: font,
        fontSize: 16,
      );

  TextStyle get thinText => TextStyle(
        color: _color,
        fontWeight: isDark ? FontWeight.w100 : FontWeight.w400,
        fontFamily: font,
        fontSize: 16,
      );

  TextStyle get titleText => boldText.copyWith(fontSize: 32);
}

extension TextStylesExtension on BuildContext {
  TextStyles get textStyles =>
      TextStyles(Theme.of(this).brightness == Brightness.dark);
}
