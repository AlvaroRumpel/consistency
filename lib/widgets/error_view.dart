import 'package:flutter/material.dart';

import '../configs/colors.dart';
import '../configs/l10n_ext.dart';
import '../configs/text_styles.dart';

class ErrorView extends StatelessWidget {
  /// Optional override; the default is the generic localised error title.
  /// Raw exception text is never user-facing — it goes to debugPrint.
  final String? message;
  final VoidCallback onRetry;

  const ErrorView({super.key, this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            label: context.l10n.errorTitle,
            child: const Icon(Icons.error_outline,
                color: AppColors.redColor, size: 40),
          ),
          const SizedBox(height: 8),
          Text(
            message ?? context.l10n.errorTitle,
            style: context.textStyles.normalText,
            textAlign: TextAlign.center,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, color: AppColors.whiteColor),
            label: Text(
              context.l10n.tryAgain,
              style: context.textStyles.normalText
                  .copyWith(color: AppColors.whiteColor),
            ),
          ),
        ],
      ),
    );
  }
}
