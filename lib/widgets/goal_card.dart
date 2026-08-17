import 'package:flutter/material.dart';

import '../configs/app_tokens.dart';
import '../configs/l10n_ext.dart';
import '../configs/text_styles.dart';
import '../controllers/day_editor_controller.dart';
import '../models/goal.dart';

const _steps = [0, 25, 50, 75, 100];

/// One goal on a day: name, streak caption and its control.
class GoalCard extends StatelessWidget {
  final GoalRow row;
  final bool enabled;
  final VoidCallback? onTapName;
  final ValueChanged<double> onChanged;

  const GoalCard({
    super.key,
    required this.row,
    required this.enabled,
    required this.onTapName,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Semantics(
                  button: onTapName != null,
                  child: InkWell(
                    onTap: onTapName,
                    borderRadius: BorderRadius.circular(12),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 44),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(row.name, style: context.textStyles.boldText),
                          const SizedBox(height: 2),
                          Text(
                            context.l10n.streakDays(row.streak),
                            style: context.textStyles.thinText.copyWith(
                              fontSize: 12,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (row.type == GoalType.check) _check(context, scheme),
            ],
          ),
          if (row.type == GoalType.percent) ...[
            const SizedBox(height: 12),
            _percent(context),
          ],
        ],
      ),
    );
  }

  Widget _check(BuildContext context, ColorScheme scheme) {
    final done = row.value >= 100;
    final tokens = context.tokens;
    // The circle stays 28px; the 48px box around it is the tap target.
    return Semantics(
      button: true,
      toggled: done,
      label: row.name,
      child: SizedBox(
        width: 48,
        height: 48,
        child: InkResponse(
          key: ValueKey('check-${row.goalId}'),
          radius: 24,
          onTap: enabled ? () => onChanged(done ? 0 : 100) : null,
          child: Center(
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: done ? tokens.qualityFor(100) : Colors.transparent,
                border: Border.all(
                    color: done ? tokens.qualityFor(100) : scheme.outline),
              ),
              child: done
                  ? Icon(Icons.check, size: 18, color: tokens.onQualityFor(100))
                  : null,
            ),
          ),
        ),
      ),
    );
  }

  Widget _percent(BuildContext context) {
    final tokens = context.tokens;
    // Values only ever come from the steps, but a snapped selection keeps
    // SegmentedButton happy if one ever arrives from elsewhere.
    final selected = _steps.reduce(
        (a, b) => (a - row.value).abs() <= (b - row.value).abs() ? a : b);
    return SegmentedButton<int>(
      segments: [
        for (final s in _steps) ButtonSegment(value: s, label: Text('$s')),
      ],
      selected: {selected},
      showSelectedIcon: false,
      onSelectionChanged: enabled ? (s) => onChanged(s.first.toDouble()) : null,
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) && selected > 0
                ? tokens.qualityFor(selected.toDouble())
                : null),
        foregroundColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) && selected > 0
                ? tokens.onQualityFor(selected.toDouble())
                : null),
        textStyle: WidgetStatePropertyAll(context.textStyles.normalText),
        padding: const WidgetStatePropertyAll(EdgeInsets.zero),
      ),
    );
  }
}
