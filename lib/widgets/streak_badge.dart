import 'package:flutter/material.dart';

import '../configs/app_tokens.dart';
import '../configs/text_styles.dart';

/// Flame + day count, coloured by streak tier.
class StreakBadge extends StatelessWidget {
  final int streak;

  const StreakBadge({super.key, required this.streak});

  @override
  Widget build(BuildContext context) {
    final color = context.tokens.flameFor(streak);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.local_fire_department, color: color, size: 22),
        const SizedBox(width: 4),
        Text('$streak',
            style: context.textStyles.boldText.copyWith(fontSize: 18)),
      ],
    );
  }
}
