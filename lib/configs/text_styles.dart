import 'package:consistency/configs/colors.dart';
import 'package:flutter/material.dart';

class TextStyles {
  static TextStyles? _instance;
  // Avoid self isntance
  TextStyles._();
  static TextStyles get i {
    _instance ??= TextStyles._();
    return _instance!;
  }

  final String font = 'WorkSans';

  TextStyle get normalText => TextStyle(
        color: AppColors.whiteColor,
        fontWeight: FontWeight.w400,
        fontFamily: font,
        fontSize: 16,
      );
  TextStyle get boldText => TextStyle(
        color: AppColors.whiteColor,
        fontWeight: FontWeight.w700,
        fontFamily: font,
        fontSize: 16,
      );
  TextStyle get thinText => TextStyle(
        color: AppColors.whiteColor,
        fontWeight: FontWeight.w100,
        fontFamily: font,
        fontSize: 16,
      );

  TextStyle get titleText => boldText.copyWith(fontSize: 32);
}

extension TextStylesExtension on BuildContext {
  TextStyles get textStyles => TextStyles.i;
}
