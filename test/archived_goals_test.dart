import 'package:consistency/configs/date_format.dart';
import 'package:consistency/models/app_data.dart';
import 'package:consistency/models/goal.dart';
import 'package:consistency/state/app_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'helpers.dart';

void main() {
  final u = DateTime.utc(2026);
  final today = DateTime.now();
  DateTime ago(int n) => DateTime(today.year, today.month, today.day - n);

  AppData seed() => AppData(
        goals: [
          Goal(
              id: 'read',
              name: 'Read',
              type: GoalType.percent,
              createdAt: ago(20),
              archivedAt: ago(5),
              updatedAt: u),
          Goal(
              id: 'run',
              name: 'Run',
              type: GoalType.check,
              createdAt: ago(20),
              archivedAt: null,
              updatedAt: u),
        ],
        entries: const [],
      );

  testWidgets(
      'archived goal shows in Settings, restoring clears it back to active',
      (tester) async {
    await tester.pumpWidget(await buildApp(data: seed()));
    await pumpFrames(tester);

    await tester.tap(find.text('Settings'));
    await pumpFrames(tester);
    expect(find.textContaining('Archived goals'), findsOneWidget);
    expect(find.text('Archived goals (1)'), findsOneWidget);

    await tester.tap(find.text('Archived goals (1)'));
    await pumpFrames(tester, 20); // route transition

    expect(find.text('Read'), findsOneWidget);
    expect(find.text('Restore'), findsOneWidget);
    expect(
      find.textContaining(formatDayMonthYear(ago(5), 'en')),
      findsOneWidget,
    );

    await tester.tap(find.text('Restore'));
    await pumpFrames(tester);

    expect(find.text('No archived goals'), findsOneWidget);
    expect(find.text('Read'), findsNothing);

    final context = tester.element(find.byType(Navigator).first);
    expect(context.read<AppStore>().data.goalById('read')!.archivedAt, isNull);
  });
}
