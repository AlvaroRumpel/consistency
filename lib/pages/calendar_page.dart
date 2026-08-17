import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../configs/app_tokens.dart';
import '../configs/date_format.dart';
import '../configs/text_styles.dart';
import '../controllers/calendar_controller.dart';
import '../controllers/day_editor_controller.dart';
import '../state/app_store.dart';
import '../state/settings_store.dart';
import '../widgets/day_editor.dart';
import '../widgets/error_view.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  late CalendarController _controller;

  @override
  void initState() {
    super.initState();
    _controller = CalendarController(
        context.read<AppStore>(), context.read<SettingsStore>());
  }

  /// Exposed for tests, which drive selection directly until Task 3 builds
  /// the real day grid.
  CalendarController get controller => _controller;

  @override
  void dispose() {
    _controller.onDispose();
    super.dispose();
  }

  BoxDecoration _card(BuildContext context) => BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        color: Theme.of(context).cardColor,
        border: Border.all(color: context.tokens.cardBorder, width: 2),
      );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24.0),
      child: Column(
        children: [
          Text(
            "How's it going",
            style: context.textStyles.normalText.copyWith(fontSize: 32),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Container(
            height: MediaQuery.sizeOf(context).height * 0.4,
            margin: const EdgeInsets.all(16.0),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: _card(context),
            child: ValueListenableBuilder(
              valueListenable: _controller.stateNotifier,
              builder: (context, state, _) {
                if (state is CalendarError) {
                  return ErrorView(
                    message: state.message,
                    onRetry: _controller.reload,
                  );
                }
                if (state is! CalendarData) {
                  return const Center(child: CircularProgressIndicator());
                }
                // Placeholder until Task 3 builds the real month/year grid.
                return Center(
                  child: Text(
                    '${state.month.year}-${state.month.month}',
                    style: context.textStyles.normalText.copyWith(
                      fontSize: 20,
                    ),
                  ),
                );
              },
            ),
          ),
          Expanded(
            child: ValueListenableBuilder(
              valueListenable: _controller.stateNotifier,
              builder: (context, state, _) {
                if (state is! CalendarData) {
                  // Errors are already shown by the calendar box above.
                  return const SizedBox.shrink();
                }
                return Container(
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  padding: const EdgeInsets.all(16),
                  decoration: _card(context),
                  child: _DayPanel(
                    key: ValueKey(state.selectedDay),
                    day: state.selectedDay,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Edits one calendar day. Recreated (via its key) whenever the selection
/// moves, so the controller always belongs to the day on screen.
class _DayPanel extends StatefulWidget {
  final DateTime day;

  const _DayPanel({super.key, required this.day});

  @override
  State<_DayPanel> createState() => _DayPanelState();
}

class _DayPanelState extends State<_DayPanel> {
  late final DayEditorController _controller;

  @override
  void initState() {
    super.initState();
    _controller = DayEditorController(
      context.read<AppStore>(),
      context.read<SettingsStore>(),
      day: widget.day,
    );
  }

  @override
  void dispose() {
    _controller.onDispose();
    super.dispose();
  }

  Widget _header(BuildContext context, DayView view) {
    // Nothing to average until the day is saved or the user starts editing.
    final avg = view.saved || view.dirty ? view.average : null;
    final consistent =
        avg != null && avg >= context.read<SettingsStore>().threshold;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          formatWeekdayDayMonth(view.day),
          style: context.textStyles.boldText.copyWith(fontSize: 20),
        ),
        const SizedBox(height: 4),
        Text(
          avg == null
              ? 'no entry'
              : '${avg.round()}% average · '
                  '${consistent ? 'consistent day' : 'below target'}',
          style: context.textStyles.thinText.copyWith(
            fontSize: 12,
            color: context.tokens.qualityFor(avg),
          ),
        ),
      ],
    );
  }

  Widget _footer(BuildContext context, DayView view) {
    if (!view.editable) {
      return Text(
        view.day.isAfter(_controller.today)
            ? "This day hasn't happened yet"
            : 'Read-only — you can only edit the last week',
        style: context.textStyles.thinText.copyWith(
          fontSize: 12,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      );
    }
    return FilledButton(
      onPressed: view.goals.isEmpty ? null : _controller.save,
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: const StadiumBorder(),
      ),
      child: Text('Save ${formatDayMonth(view.day)}'),
    );
  }

  @override
  Widget build(BuildContext context) => DayEditor(
        controller: _controller,
        header: _header,
        footer: _footer,
      );
}
