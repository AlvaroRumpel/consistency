import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../configs/app_tokens.dart';
import '../configs/date_format.dart';
import '../configs/l10n_ext.dart';
import '../configs/text_styles.dart';
import '../models/date_key.dart';

const _cell = 12.0;
const _gap = 3.0;
const _step = _cell + _gap;
const _monthLabels = 12.0; // height of the month label strip

/// Sunday first; only three labels, like GitHub's contribution graph.
const _weekdayLabels = [null, 'M', null, 'W', null, 'F', null];

/// A year of days as 7 weekday rows × ~53 week columns. Pure: it renders the
/// [quality] it is given and reports taps, nothing else.
class YearHeatmap extends StatelessWidget {
  final int year;
  final Map<DateTime, double?> quality;
  final DateTime today;
  final ValueChanged<DateTime> onSelect;

  const YearHeatmap({
    super.key,
    required this.year,
    required this.quality,
    required this.today,
    required this.onSelect,
  });

  /// Weeks from the Sunday on/before Jan 1 to the week holding Dec 31.
  List<List<DateTime>> get _weeks {
    final jan1 = DateTime(year, 1, 1);
    final end = DateTime(year, 12, 31);
    final weeks = <List<DateTime>>[];
    for (var d = DateTime(year, 1, 1 - jan1.weekday % 7); // Sunday = 0
        !d.isAfter(end);
        d = DateTime(d.year, d.month, d.day + 7)) {
      weeks.add(
          [for (var i = 0; i < 7; i++) DateTime(d.year, d.month, d.day + i)]);
    }
    return weeks;
  }

  @override
  Widget build(BuildContext context) {
    final weeks = _weeks;
    final labelStyle = context.textStyles.thinText.copyWith(
      fontSize: 8,
      height: 1,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );

    return Semantics(
      container: true,
      label: context.l10n.yearActivityHeatmap(year),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            // Line the rows up with the grid, below the month strip.
            padding: const EdgeInsets.only(top: _monthLabels + _gap, right: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final label in _weekdayLabels)
                  SizedBox(
                    height: _step,
                    child:
                        label == null ? null : Text(label, style: labelStyle),
                  ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _monthStrip(weeks, labelStyle,
                      Localizations.localeOf(context).toLanguageTag()),
                  const SizedBox(height: _gap),
                  // 365 unlabelled squares are noise to a screen reader; the
                  // label on the whole heatmap says what this is.
                  ExcludeSemantics(
                    child: Row(
                      children: [
                        for (final week in weeks)
                          Column(
                            children: [
                              for (final day in week) _dayCell(context, day)
                            ],
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// A month name over the first column whose week starts that month.
  Widget _monthStrip(
      List<List<DateTime>> weeks, TextStyle style, String locale) {
    return SizedBox(
      height: _monthLabels,
      // Room for the last label, which is wider than its column.
      width: weeks.length * _step + 16,
      child: Stack(
        children: [
          for (var c = 0; c < weeks.length; c++)
            if (_monthLabel(weeks, c, locale) case final label?)
              Positioned(
                  left: c * _step, top: 0, child: Text(label, style: style)),
        ],
      ),
    );
  }

  /// Month of the column's first day inside [year] — so the column straddling
  /// New Year counts as January, not as last December.
  int? _columnMonth(List<DateTime> week) {
    for (final d in week) {
      if (d.year == year) return d.month;
    }
    return null;
  }

  String? _monthLabel(List<List<DateTime>> weeks, int c, String locale) {
    final month = _columnMonth(weeks[c]);
    if (month == null) return null;
    if (c > 0 && _columnMonth(weeks[c - 1]) == month) return null;
    ensureDateSymbols();
    return DateFormat.MMM(locale).format(DateTime(year, month));
  }

  Widget _dayCell(BuildContext context, DateTime day) {
    final active = day.year == year && !day.isAfter(today);
    return GestureDetector(
      key: ValueKey('hm-${dateKey(day)}'),
      behavior: HitTestBehavior.opaque,
      onTap: active ? () => onSelect(day) : null,
      child: Container(
        width: _step,
        height: _step,
        padding: const EdgeInsets.only(right: _gap, bottom: _gap),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: active
                ? context.tokens.qualityFor(quality[day])
                : Colors.transparent,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}

/// The year's totals under the heatmap. Numbers come from the page.
class YearSummary extends StatelessWidget {
  final int year;
  final int consistent;
  final int recorded;

  /// All-time streaks, so they are null on any year but the current one.
  final int? best;
  final int? current;

  const YearSummary({
    super.key,
    required this.year,
    required this.consistent,
    required this.recorded,
    required this.best,
    required this.current,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.yearSummary(year, consistent, recorded),
          style: context.textStyles.boldText.copyWith(fontSize: 18),
        ),
        if (best != null && current != null) ...[
          const SizedBox(height: 6),
          Text(
            context.l10n.bestAndCurrent(best!, current!),
            style: context.textStyles.thinText.copyWith(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}
