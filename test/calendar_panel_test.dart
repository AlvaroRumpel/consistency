import 'package:consistency/configs/date_format.dart';
import 'package:consistency/models/app_data.dart';
import 'package:consistency/models/date_key.dart';
import 'package:consistency/models/day_entry.dart';
import 'package:consistency/models/goal.dart';
import 'package:consistency/pages/calendar_page.dart';
import 'package:consistency/state/app_store.dart';
import 'package:consistency/widgets/goal_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'helpers.dart';

void main() {
  final u = DateTime.utc(2026);
  final today = DateTime.now();
  DateTime daysAgo(int n) => DateTime(today.year, today.month, today.day - n);
  final recent = daysAgo(3);
  final old = daysAgo(10);

  Goal goal(String id, String name, GoalType type) => Goal(
        id: id,
        name: name,
        type: type,
        createdAt: daysAgo(30),
        archivedAt: null,
        updatedAt: u,
      );

  AppData seed() => AppData(
        goals: [
          goal('run', 'Run', GoalType.check),
          goal('read', 'Read', GoalType.percent),
        ],
        entries: [
          DayEntry(
              date: recent, values: const {'run': 0, 'read': 50}, updatedAt: u),
        ],
      );

  // Drives selection through the real UI: the grid only renders cells for
  // the month currently displayed, so hop months with the '‹' arrow first
  // when the target day isn't in view.
  var displayedMonth = DateTime(today.year, today.month);
  Future<void> select(WidgetTester tester, DateTime day) async {
    final target = DateTime(day.year, day.month, day.day);
    final targetMonth = DateTime(target.year, target.month);
    var monthsBack = (displayedMonth.year * 12 + displayedMonth.month) -
        (targetMonth.year * 12 + targetMonth.month);
    while (monthsBack > 0) {
      await tester.tap(find.byKey(const ValueKey('calendar-prev-month')));
      await pumpFrames(tester);
      monthsBack--;
    }
    while (monthsBack < 0) {
      await tester.tap(find.byKey(const ValueKey('calendar-next-month')));
      await pumpFrames(tester);
      monthsBack++;
    }
    displayedMonth = targetMonth;
    await tester.tap(find.byKey(ValueKey('day-${dateKey(target)}')));
    await pumpFrames(tester);
  }

  test('weekday/month names', () {
    expect(formatWeekdayDayMonth(DateTime(2026, 8, 14)), 'Fri, 14 August');
    expect(formatDayMonth(DateTime(2026, 8, 14)), '14/08');
  });

  testWidgets('the panel edits days inside the window and locks older ones',
      (tester) async {
    tester.view.physicalSize = const Size(600, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(await buildApp(data: seed()));
    await pumpFrames(tester);
    await tester.tap(find.text('Calendar'));
    await pumpFrames(tester);

    await select(tester, recent);
    expect(find.text(formatWeekdayDayMonth(recent)), findsOneWidget);
    expect(find.textContaining('25% average'), findsOneWidget);
    expect(find.byType(GoalCard), findsNWidgets(2));
    expect(find.text('Save ${formatDayMonth(recent)}'), findsOneWidget);

    await select(tester, old);
    expect(find.text('Read-only — you can only edit the last week'),
        findsOneWidget);
    expect(find.textContaining('Save '), findsNothing);
    expect(find.text('no entry'), findsOneWidget);

    await select(tester, recent);
    await tester.tap(find.byKey(const ValueKey('check-run')));
    await pumpFrames(tester);
    await tester.tap(find.text('Save ${formatDayMonth(recent)}'));
    await pumpFrames(tester);

    final store = tester.element(find.byType(CalendarPage)).read<AppStore>();
    expect(store.data.entryOn(recent)!.values['run'], 100);
    expect(store.data.entryOn(recent)!.values['read'], 50);
  });
}
