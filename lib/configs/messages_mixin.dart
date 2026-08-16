import 'package:flutter/material.dart';
import 'package:top_snackbar_flutter/custom_snack_bar.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';

import 'colors.dart';
import 'text_styles.dart';

mixin MessagesMixin<T extends StatefulWidget> on State<T> {
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
        backgroundColor: AppColors.primaryColor.withValues(alpha: .8),
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
