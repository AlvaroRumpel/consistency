import 'package:flutter/material.dart';

import 'colors.dart';

class Utilities {
  static Color activeColor(double value) {
    if (value < 25.0) return AppColors.redColor.shade900;
    if (value < 50.0) return AppColors.redColor;
    if (value < 75.0) return AppColors.redColor.shade50;
    if (value <= 82.0) return AppColors.primaryColor;
    return AppColors.greenColor;
  }
}
