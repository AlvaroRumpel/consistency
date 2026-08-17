import 'dart:async';

import 'package:consistency/state/app_store.dart';
import 'package:consistency/widgets/goal_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'helpers.dart';

void main() {
  testWidgets(
      'new goal via sheet appears as a card; edit renames and changes type',
      (tester) async {
    await tester.pumpWidget(await buildApp());
    await pumpFrames(tester);
    await tester.tap(find.text('New goal'));
    await pumpFrames(tester);
    await tester.enterText(find.byType(TextFormField), 'Meditate');
    await tester.tap(find.text('Percent 0–100'));
    await tester.tap(find.text('Add goal'));
    await pumpFrames(tester);
    expect(find.text('Meditate'), findsOneWidget);
    expect(find.text('25'),
        findsOneWidget); // segmented control present → percent type

    // Edit: drive showGoalSheet directly with the goal, since tapping the
    // name reopens through home_page's own lookup.
    final store = tester.element(find.text('Meditate')).read<AppStore>();
    final goal = store.data.goals.firstWhere((g) => g.name == 'Meditate');
    unawaited(showGoalSheet(tester.element(find.text('Meditate')), goal: goal));
    await pumpFrames(tester, 20); // let the sheet's enter animation settle
    await tester.enterText(find.byType(TextFormField), 'Breathe');
    await tester.tap(find.text('Save changes'));
    await pumpFrames(tester, 20); // let the sheet's exit animation settle
    expect(find.text('Breathe'), findsOneWidget);
    expect(find.text('Meditate'), findsNothing);

    // Archive: reopen the sheet for the renamed goal, confirm archive.
    final renamed = store.data.goalById(goal.id)!;
    unawaited(
        showGoalSheet(tester.element(find.text('Breathe')), goal: renamed));
    await pumpFrames(tester, 20); // let the sheet's enter animation settle
    await tester.tap(find.text('Archive goal'));
    await pumpFrames(tester);
    await tester.tap(find.text('Archive'));
    await pumpFrames(tester, 20); // let the sheet's exit animation settle
    expect(find.text('Breathe'), findsNothing);
  });
}
