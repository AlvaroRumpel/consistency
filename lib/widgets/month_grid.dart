import 'package:flutter/material.dart';

import '../configs/app_tokens.dart';
import '../configs/text_styles.dart';
import '../models/date_key.dart';

const _weekdayLabels = ['S', 'M', 'T', 'W', 'T', 'F', 'S']; // Sunday first

class MonthGrid extends StatelessWidget {
  final DateTime month;
  final Map<DateTime, double?> quality;
  final DateTime today;
  final DateTime selected;
  final ValueChanged<DateTime> onSelect;

  const MonthGrid({
    super.key,
    required this.month,
    required this.quality,
    required this.today,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leading = month.weekday % 7; // Sunday = 0
    final rows = ((leading + daysInMonth) / 7).ceil();

    // The page draws the grid on a decorated Container, which would paint over
    // the ink of the Material further up; this one is right under the taps.
    return Material(
      type: MaterialType.transparency,
      child: Column(
        children: [
          Row(
            key: const ValueKey('weekday-header'),
            children: [
              for (final label in _weekdayLabels)
                Expanded(
                  child: Center(
                    child: Text(
                      label,
                      style: context.textStyles.thinText.copyWith(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          for (var r = 0; r < rows; r++)
            Row(
              children: [
                for (var c = 0; c < 7; c++)
                  Expanded(
                    child: Center(
                      child:
                          _cell(context, r * 7 + c - leading + 1, daysInMonth),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _cell(BuildContext context, int dayNum, int daysInMonth) {
    if (dayNum < 1 || dayNum > daysInMonth) {
      return const SizedBox(width: 44, height: 44);
    }
    final day = DateTime(month.year, month.month, dayNum);
    final tokens = context.tokens;
    final scheme = Theme.of(context).colorScheme;

    final future = day.isAfter(today);
    final v = quality[day];
    final bg = future ? Colors.transparent : tokens.qualityFor(v);
    final textColor = future
        ? scheme.onSurfaceVariant.withValues(alpha: .5)
        : (v == null ? scheme.onSurface : tokens.onQualityFor(v));

    final isToday = dateKey(day) == dateKey(today);
    final isSelected = dateKey(day) == dateKey(selected);
    final borderWidth = isSelected ? 3.0 : (isToday ? 2.0 : 0.0);

    return SizedBox(
      width: 44,
      height: 44,
      child: InkResponse(
        key: ValueKey('day-${dateKey(day)}'),
        radius: 22,
        onTap: future ? null : () => onSelect(day),
        child: Center(
          child: Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(10),
              border: borderWidth > 0
                  ? Border.all(color: scheme.primary, width: borderWidth)
                  : null,
            ),
            child: Text(
              '$dayNum',
              style: context.textStyles.normalText
                  .copyWith(fontSize: 14, color: textColor),
            ),
          ),
        ),
      ),
    );
  }
}
