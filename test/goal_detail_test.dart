import 'package:consistency/configs/app_tokens.dart';
import 'package:consistency/models/app_data.dart';
import 'package:consistency/models/day_entry.dart';
import 'package:consistency/models/goal.dart';
import 'package:consistency/pages/goal_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  final u = DateTime.utc(2026);
  final today = DateTime.now();
  DateTime ago(int n) => DateTime(today.year, today.month, today.day - n);

  Goal read({DateTime? archivedAt}) => Goal(
        id: 'read',
        name: 'Read',
        type: GoalType.percent,
        createdAt: ago(10),
        archivedAt: archivedAt,
        updatedAt: u,
      );

  AppData seed({DateTime? archivedAt}) => AppData(
        goals: [read(archivedAt: archivedAt)],
        entries: [
          DayEntry(date: ago(2), values: const {'read': 25}, updatedAt: u),
          DayEntry(date: ago(1), values: const {'read': 75}, updatedAt: u),
          DayEntry(date: today, values: const {'read': 100}, updatedAt: u),
        ],
      );

  Color squareColor(WidgetTester tester, int i) {
    final box = tester.widget<Container>(find.byKey(ValueKey('hm-$i')));
    return (box.decoration as BoxDecoration).color!;
  }

  testWidgets(
      'tapping a goal on home opens its detail; archive flips the '
      'page to restore', (tester) async {
    await tester.pumpWidget(await buildApp(data: seed()));
    await pumpFrames(tester);
    await tester.tap(find.text('Read'));
    await pumpFrames(tester, 20); // route transition

    expect(find.text('CURRENT STREAK'), findsOneWidget);
    expect(find.text('RECORD'), findsOneWidget);
    expect(find.text('LAST 7 DAYS'), findsOneWidget);
    // Once as a stat tile label, once as the strip's section header.
    expect(find.text('LAST 30 DAYS'), findsNWidgets(2));
    expect(find.text('Change it with the edit button'), findsOneWidget);
    expect(
        find.byWidgetPredicate(
            (w) => w.key is ValueKey<String> && w is Container),
        findsNWidgets(30));

    // The strip is this goal's own values: today 100, before it was created
    // there is no data.
    const tokens = AppTokens.light;
    expect(squareColor(tester, 29), tokens.qualityFor(100));
    expect(squareColor(tester, 28), tokens.qualityFor(75));
    expect(squareColor(tester, 0), tokens.qualityFor(null));

    await tester.tap(find.text('Archive goal'));
    await pumpFrames(tester);
    await tester.tap(find.text('Archive'));
    await pumpFrames(tester, 20);
    expect(find.text('Restore goal'), findsOneWidget);
    expect(find.textContaining('Archived on'), findsOneWidget);
  });

  testWidgets('an archived goal shows the banner and restores in place',
      (tester) async {
    await tester.pumpWidget(await wrap(
      const GoalDetailPage(goalId: 'read'),
      data: seed(archivedAt: ago(1)),
    ));
    await pumpFrames(tester);
    expect(find.text('Restore goal'), findsOneWidget);
    final d = ago(1);
    final dmy = '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/${d.year}';
    expect(find.text('Archived on $dmy'), findsOneWidget);

    await tester.tap(find.text('Restore goal'));
    await pumpFrames(tester);
    expect(find.text('Archive goal'), findsOneWidget);
    expect(find.textContaining('Archived on'), findsNothing);
  });

  testWidgets('a goal that disappears pops the page', (tester) async {
    await tester.pumpWidget(await wrap(
      const GoalDetailPage(goalId: 'gone'),
      data: seed(),
    ));
    await pumpFrames(tester);
    // Nothing to show and no route below it: the page renders empty.
    expect(find.text('Read'), findsNothing);
  });
}
