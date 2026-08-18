import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../configs/app_tokens.dart';
import '../configs/date_format.dart';
import '../configs/l10n_ext.dart';
import '../configs/text_styles.dart';
import '../controllers/calendar_controller.dart';
import '../controllers/day_editor_controller.dart';
import '../engine/consistency_engine.dart';
import '../state/app_store.dart';
import '../state/settings_store.dart';
import '../widgets/day_editor.dart';
import '../widgets/error_view.dart';
import '../widgets/month_grid.dart';
import '../widgets/quality_legend.dart';
import '../widgets/raw_export.dart';
import '../widgets/year_heatmap.dart';

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
      child: ValueListenableBuilder(
        valueListenable: _controller.stateNotifier,
        builder: (context, state, _) {
          // The year view has its own summary card instead of a day panel, so
          // it leaves the panel out and the calendar box takes the whole page.
          final day = state is CalendarData && state.view == CalendarView.month
              ? state.selectedDay
              : null;
          return Column(
            children: [
              Expanded(
                flex: 5,
                child: Container(
                  margin: const EdgeInsets.all(16.0),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  decoration: _card(context),
                  child: switch (state) {
                    CalendarError() => ErrorView(
                        onRetry: _controller.reload,
                        onExportRaw: () => exportRawFile(context),
                      ),
                    // A short window (small phone, landscape) scrolls instead
                    // of overflowing; a tall one just shows it all at once.
                    CalendarData d => SingleChildScrollView(
                        child: _CalendarBox(state: d, controller: _controller),
                      ),
                    _ => const Center(child: CircularProgressIndicator()),
                  },
                ),
              ),
              if (day != null)
                Expanded(
                  flex: 4,
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    padding: const EdgeInsets.all(16),
                    decoration: _card(context),
                    child: _DayPanel(key: ValueKey(day), day: day),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Month/Year toggle, the month header and grid or the year header and
/// heatmap, plus the legend. Presentation over [CalendarData] and the
/// controller callbacks that change it.
class _CalendarBox extends StatelessWidget {
  final CalendarData state;
  final CalendarController controller;

  const _CalendarBox({required this.state, required this.controller});

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: SegmentedButton<CalendarView>(
            segments: [
              ButtonSegment(
                  value: CalendarView.month, label: Text(context.l10n.month)),
              ButtonSegment(
                  value: CalendarView.year, label: Text(context.l10n.year)),
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
                formatMonthYear(state.month, locale),
                key: const ValueKey('calendar-month-title'),
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
        ] else ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                key: const ValueKey('calendar-prev-year'),
                icon: const Icon(Icons.chevron_left),
                onPressed: controller.previousYear,
              ),
              Text(
                '${state.year}',
                style: context.textStyles.normalText.copyWith(fontSize: 20),
              ),
              IconButton(
                key: const ValueKey('calendar-next-year'),
                icon: const Icon(Icons.chevron_right),
                onPressed: controller.nextYear,
              ),
            ],
          ),
          YearHeatmap(
            year: state.year,
            quality: state.qualityByDay,
            today: state.today,
            onSelect: controller.openMonthFor,
          ),
        ],
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: QualityLegend(),
        ),
        if (state.view == CalendarView.year) _summary(context),
      ],
    );
  }

  Widget _summary(BuildContext context) {
    final threshold = context.read<SettingsStore>().threshold;
    // qualityByDay is the displayed year — up to today on the current one, all
    // 12 months on a past one. Streaks are all-time, so they only say
    // something about the year we are living in.
    final engine = state.year == state.today.year
        ? ConsistencyEngine(
            data: context.read<AppStore>().data,
            threshold: threshold,
            today: state.today,
          )
        : null;
    final recorded = state.qualityByDay.values.whereType<double>();
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          YearSummary(
            year: state.year,
            consistent: recorded.where((v) => v >= threshold).length,
            recorded: recorded.length,
            best: engine?.globalBest(),
            current: engine?.globalStreak(),
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.tapDayToOpenMonth,
            style: context.textStyles.thinText.copyWith(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
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
          formatWeekdayDayMonth(
              view.day, Localizations.localeOf(context).toLanguageTag()),
          style: context.textStyles.boldText.copyWith(fontSize: 20),
        ),
        const SizedBox(height: 4),
        Text(
          avg == null
              ? context.l10n.noEntry
              : '${context.l10n.dayAverage(avg.round())} · '
                  '${consistent ? context.l10n.consistentDay : context.l10n.belowTarget}',
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
            ? context.l10n.dayInFuture
            : context.l10n.readOnlyWindow,
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
      child: Text(context.l10n.saveDay(formatDayMonth(
          view.day, Localizations.localeOf(context).toLanguageTag()))),
    );
  }

  @override
  Widget build(BuildContext context) => DayEditor(
        controller: _controller,
        header: _header,
        footer: _footer,
      );
}
