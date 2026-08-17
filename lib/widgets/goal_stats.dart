import 'package:flutter/material.dart';

import '../configs/app_tokens.dart';
import '../configs/text_styles.dart';
import '../models/app_data.dart';
import '../models/date_key.dart';
import '../models/goal.dart';

const _stripDays = 30;
const _cell = 14.0;
const _gap = 4.0;
const _perRow = 10;

/// A number over an uppercase label, with an optional icon.
class StatTile extends StatelessWidget {
  final IconData? icon;
  final Color? iconColor;
  final String value;
  final String label;

  const StatTile({
    super.key,
    this.icon,
    this.iconColor,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 20, color: iconColor),
            const SizedBox(height: 6),
          ],
          Text(value,
              style: context.textStyles.boldText.copyWith(fontSize: 22)),
          const SizedBox(height: 6),
          Text(
            label,
            style: context.textStyles.thinText.copyWith(
              fontSize: 11,
              letterSpacing: 0.7,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// The last 30 days of this goal alone, oldest first, 10 per row.
class DayStrip extends StatelessWidget {
  final Goal goal;
  final AppData data;

  const DayStrip({super.key, required this.goal, required this.data});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final today = dateOnly(DateTime.now());
    return SizedBox(
      width: _perRow * _cell + (_perRow - 1) * _gap,
      child: Wrap(
        spacing: _gap,
        runSpacing: _gap,
        children: [
          for (var i = 0; i < _stripDays; i++)
            _square(tokens,
                DateTime(today.year, today.month, today.day - 29 + i), i),
        ],
      ),
    );
  }

  Widget _square(AppTokens tokens, DateTime day, int i) {
    final value =
        goal.isActiveOn(day) ? data.entryOn(day)?.values[goal.id] : null;
    return Container(
      key: ValueKey('hm-$i'),
      width: _cell,
      height: _cell,
      decoration: BoxDecoration(
        color: tokens.qualityFor(value),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}
