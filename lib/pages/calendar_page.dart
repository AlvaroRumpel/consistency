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
import '../widgets/month_grid.dart';
import '../widgets/quality_legend.dart';

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
          Expanded(
            flex: 5,
            child: Container(
              margin: const EdgeInsets.all(16.0),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
                  // A short window (small phone, landscape) scrolls instead
                  // of overflowing; a tall one just shows it all at once.
                  return SingleChildScrollView(
                    child: _CalendarBox(state: state, controller: _controller),
                  );
                },
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: ValueListenableBuilder(
              valueListenable: _controller.stateNotifier,
              builder: (context, state, _) {
                if (state is! CalendarData || state.view == CalendarView.year) {
                  // Errors are already shown by the calendar box above; the
                  // year view has its own summary card instead of a panel.
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

/// Month/Year toggle, month header, the grid (or the year placeholder) and
/// the legend. Pure presentation over [CalendarData] plus the controller
/// callbacks that change it.
class _CalendarBox extends StatelessWidget {
  final CalendarData state;
  final CalendarController controller;

  const _CalendarBox({required this.state, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: SegmentedButton<CalendarView>(
            segments: const [
              ButtonSegment(value: CalendarView.month, label: Text('Month')),
              ButtonSegment(value: CalendarView.year, label: Text('Year')),
            ],
            selected: {state.view},
            onSelectionChanged: (s) => controller.setView(s.first),
          ),
        ),
        if (state.view == CalendarView.month) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                key: const ValueKey('calendar-prev-month'),
                icon: const Icon(Icons.chevron_left),
                onPressed: controller.previousMonth,
              ),
              Text(
                formatMonthYear(state.month),
                style: context.textStyles.normalText.copyWith(fontSize: 20),
              ),
              IconButton(
                key: const ValueKey('calendar-next-month'),
                icon: const Icon(Icons.chevron_right),
                onPressed: controller.nextMonth,
              ),
            ],
          ),
          MonthGrid(
            month: state.month,
            quality: state.qualityByDay,
            today: state.today,
            selected: state.selectedDay,
            onSelect: controller.selectDay,
          ),
        ] else
          // YearHeatmap arrives in Task 4; placeholder keeps the toggle
          // wired end-to-end until then.
          const SizedBox(
            height: 200,
            child: Center(child: Text('Year view')),
          ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: QualityLegend(),
        ),
      ],
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
