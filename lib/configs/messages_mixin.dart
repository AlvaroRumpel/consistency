import 'package:consistency/configs/colors.dart';
import 'package:consistency/configs/text_styles.dart';
import 'package:flutter/material.dart';
import 'package:top_snackbar_flutter/custom_snack_bar.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';

mixin MessagesMixin<T extends StatefulWidget> on State<T> {
  void showError(String message) {
    showTopSnackBar(
      animationDuration: const Duration(milliseconds: 800),
      curve: Curves.linearToEaseOut,
      Overlay.of(context),
      CustomSnackBar.error(
        iconRotationAngle: 0,
        iconPositionLeft: 8,
        message: message,
        backgroundColor: AppColors.redColor.withOpacity(.8),
        textStyle: context.textStyles.boldText,
        icon: const Icon(
          Icons.error_outline_outlined,
          size: 40,
          color: AppColors.whiteColor,
        ),
        borderRadius: BorderRadius.circular(100),
      ),
    );
  }
}
