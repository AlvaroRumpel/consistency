import 'package:flutter/material.dart';

import '../configs/l10n_ext.dart';
import '../configs/text_styles.dart';
import '../controllers/day_editor_controller.dart';
import 'error_view.dart';
import 'goal_card.dart';
import 'raw_export.dart';

/// Renders a [DayEditorController]: a caller-supplied header, one [GoalCard]
/// per goal and an optional footer, both built from the current [DayView].
class DayEditor extends StatefulWidget {
  final DayEditorController controller;
  final Widget Function(BuildContext, DayView) header;
  final Widget Function(BuildContext, DayView)? footer;
  final void Function(GoalRow)? onGoalTap;

  const DayEditor({
    super.key,
    required this.controller,
    required this.header,
    this.footer,
    this.onGoalTap,
  });

  @override
  State<DayEditor> createState() => _DayEditorState();
}

class _DayEditorState extends State<DayEditor> {
  bool _lastFailed = false;

  void _reportSaveFailure(bool failed) {
    if (failed == _lastFailed) return;
    _lastFailed = failed;
    if (!failed) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(context.l10n.couldNotSave),
        backgroundColor: Theme.of(context).colorScheme.error,
      ));
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return ValueListenableBuilder(
      valueListenable: controller.stateNotifier,
      builder: (context, state, _) {
        if (state is DayEditorError) {
          return Center(
            child: ErrorView(
              onRetry: controller.reload,
              onExportRaw: () => exportRawFile(context),
            ),
          );
        }
        if (state is! DayEditorReady) {
          return const Center(child: CircularProgressIndicator());
        }
        final view = state.view;
        _reportSaveFailure(view.saveFailed);
        final isToday = view.day == controller.today;
        return ListView(
          children: [
            widget.header(context, view),
            if (view.goals.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text(
                isToday ? context.l10n.todaysGoals : context.l10n.goals,
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
                  onTapName: widget.onGoalTap == null
                      ? null
                      : () => widget.onGoalTap!(row),
                  onChanged: (v) => controller.setValue(row.goalId, v),
                ),
              ),
            if (widget.footer != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: widget.footer!(context, view),
              ),
          ],
        );
      },
    );
  }
}
