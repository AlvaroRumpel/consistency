import 'package:flutter/material.dart';

import 'colors.dart';

class Utilities {
  static Color activeColor(double value) {
    if (value < 25.0) {
      return AppColors.redColor.shade900;
    }
    if (value >= 25.0 && value < 50) {
      return AppColors.redColor;
    }
    if (value >= 50.0 && value < 75) {
      return AppColors.redColor.shade50;
    }
    if (value >= 75.0 && value <= 82) {
      return AppColors.primaryColor;
    }
    return AppColors.greenColor;
  }
}
