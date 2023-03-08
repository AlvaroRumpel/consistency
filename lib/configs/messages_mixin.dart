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
        iconPositionLeft: 16,
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

  void showMessageUndo({
    required String message,
    required Function() onTap,
  }) {
    showTopSnackBar(
      animationDuration: const Duration(milliseconds: 800),
      curve: Curves.linearToEaseOut,
      Overlay.of(context),
      displayDuration: const Duration(milliseconds: 5000),
      onTap: onTap,
      CustomSnackBar.info(
        iconRotationAngle: 0,
        iconPositionLeft: 16,
        message: message,
        backgroundColor: AppColors.primaryColor.withOpacity(.8),
        textStyle: context.textStyles.boldText,
        icon: const Icon(
          Icons.undo_rounded,
          size: 32,
          color: AppColors.whiteColor,
        ),
        borderRadius: BorderRadius.circular(100),
      ),
    );
  }
}
