import 'package:flutter/material.dart';

import '../configs/app_tokens.dart';
import '../configs/text_styles.dart';

const _labels = ['no data', '<25', '25–49', '50–74', '≥75'];

class QualityLegend extends StatelessWidget {
  const QualityLegend({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final textColor = Theme.of(context).colorScheme.onSurfaceVariant;
    return Wrap(
      spacing: 12,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (var i = 0; i < _labels.length; i++)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: tokens.quality[i],
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                _labels[i],
                style: context.textStyles.thinText
                    .copyWith(fontSize: 12, color: textColor),
              ),
            ],
          ),
      ],
    );
  }
}
