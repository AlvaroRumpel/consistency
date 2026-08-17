import 'package:consistency/configs/date_format.dart';
import 'package:consistency/models/app_data.dart';
import 'package:consistency/models/date_key.dart';
import 'package:consistency/models/day_entry.dart';
import 'package:consistency/models/goal.dart';
import 'package:consistency/widgets/goal_card.dart';
import 'package:consistency/widgets/month_grid.dart';
import 'package:consistency/widgets/quality_legend.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  final u = DateTime.utc(2026);
  final today = DateTime.now();
  DateTime daysAgo(int n) => DateTime(today.year, today.month, today.day - n);
  final recent = daysAgo(3);

  Goal goal(String id, String name, GoalType type) => Goal(
        id: id,
        name: name,
        type: type,
        createdAt: daysAgo(30),
        archivedAt: null,
        updatedAt: u,
      );

  AppData seed() => AppData(
        goals: [goal('run', 'Run', GoalType.check)],
        entries: [
          DayEntry(date: recent, values: const {'run': 100}, updatedAt: u),
        ],
      );

  Future<void> openCalendar(WidgetTester tester) async {
    tester.view.physicalSize = const Size(600, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(await buildApp(data: seed()));
    await pumpFrames(tester);
    await tester.tap(find.text('Calendar'));
    await pumpFrames(tester);
  }

  testWidgets('shows the month grid, month title and legend', (tester) async {
    await openCalendar(tester);

    expect(find.byType(MonthGrid), findsOneWidget);
    expect(find.text(formatMonthYear(DateTime(today.year, today.month))),
        findsOneWidget);
    expect(find.byType(QualityLegend), findsOneWidget);
  });

  testWidgets('the "‹" arrow moves the title back a month', (tester) async {
    await openCalendar(tester);

    await tester.tap(find.byKey(const ValueKey('calendar-prev-month')));
    await pumpFrames(tester);

    final previousMonth = DateTime(today.year, today.month - 1);
    expect(find.text(formatMonthYear(previousMonth)), findsOneWidget);
  });

  testWidgets('tapping a past day with an entry shows its goals and Save',
      (tester) async {
    await openCalendar(tester);

    await tester.tap(find.byKey(ValueKey('day-${dateKey(recent)}')));
    await pumpFrames(tester);

    expect(find.text(formatWeekdayDayMonth(recent)), findsOneWidget);
    expect(find.byType(GoalCard), findsOneWidget);
    expect(find.text('Save ${formatDayMonth(recent)}'), findsOneWidget);
  });

  testWidgets('switching to Year hides the day panel', (tester) async {
    await openCalendar(tester);
    expect(find.text('Save ${formatDayMonth(today)}'), findsOneWidget);

    await tester.tap(find.text('Year'));
    await pumpFrames(tester);

    expect(find.byType(MonthGrid), findsNothing);
    expect(find.text('Year view'), findsOneWidget);
    expect(find.byType(QualityLegend), findsOneWidget);
    expect(find.textContaining('Save '), findsNothing);
  });
}
