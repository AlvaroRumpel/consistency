import 'package:flutter/material.dart';

class TextStyles {
  final Color color;

  const TextStyles(this.color);

  static const String font = 'WorkSans';

  TextStyle get normalText => TextStyle(
        color: color,
        fontWeight: FontWeight.w500,
        fontFamily: font,
        fontSize: 16,
      );

  TextStyle get boldText => normalText.copyWith(fontWeight: FontWeight.w700);

  TextStyle get thinText => normalText.copyWith(fontWeight: FontWeight.w400);

  TextStyle get titleText => boldText.copyWith(fontSize: 32);
}

extension TextStylesExtension on BuildContext {
  TextStyles get textStyles => TextStyles(Theme.of(this).colorScheme.onSurface);
}
