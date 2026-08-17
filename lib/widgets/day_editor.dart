import 'package:flutter/material.dart';

import '../configs/text_styles.dart';
import '../controllers/day_editor_controller.dart';
import 'error_view.dart';
import 'goal_card.dart';

/// Renders a [DayEditorController]: a caller-supplied header, one [GoalCard]
/// per goal and an optional footer.
class DayEditor extends StatelessWidget {
  final DayEditorController controller;
  final Widget Function(BuildContext, DayView) header;
  final Widget? footer;
  final void Function(GoalRow)? onGoalTap;

  const DayEditor({
    super.key,
    required this.controller,
    required this.header,
    this.footer,
    this.onGoalTap,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: controller.stateNotifier,
      builder: (context, state, _) {
        if (state is DayEditorError) {
          return Center(
            child:
                ErrorView(message: state.message, onRetry: controller.reload),
          );
        }
        if (state is! DayEditorReady) {
          return const Center(child: CircularProgressIndicator());
        }
        final view = state.view;
        final isToday = view.day == controller.today;
        return ListView(
          children: [
            header(context, view),
            if (view.goals.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text(
                isToday ? "TODAY'S GOALS" : 'GOALS',
                style: context.textStyles.boldText.copyWith(
                  fontSize: 12,
                  letterSpacing: 1.2,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            for (final row in view.goals)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: GoalCard(
                  row: row,
                  enabled: view.editable,
                  onTapName: onGoalTap == null ? null : () => onGoalTap!(row),
                  onChanged: (v) => controller.setValue(row.goalId, v),
                ),
              ),
            if (footer != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: footer,
              ),
          ],
        );
      },
    );
  }
}
