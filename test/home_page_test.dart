import 'package:consistency/models/app_data.dart';
import 'package:consistency/models/day_entry.dart';
import 'package:consistency/models/goal.dart';
import 'package:consistency/pages/home_page.dart';
import 'package:consistency/state/settings_store.dart';
import 'package:consistency/widgets/goal_card.dart';
import 'package:consistency/widgets/progress_ring.dart';
import 'package:consistency/widgets/streak_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'helpers.dart';

void main() {
  final u = DateTime.utc(2026);
  final today = DateTime.now();
  final yesterday = DateTime(today.year, today.month, today.day - 1);

  AppData seed() => AppData(goals: [
        Goal(
            id: 'run',
            name: 'Run',
            type: GoalType.check,
            createdAt: today,
            archivedAt: null,
            updatedAt: u),
        Goal(
            id: 'read',
            name: 'Read',
            type: GoalType.percent,
            createdAt: today,
            archivedAt: null,
            updatedAt: u),
      ], entries: const []);

  testWidgets(
      'home renders ring, greeting, cards; toggling and saving flips the ring subtitle',
      (tester) async {
    await tester.pumpWidget(
        await buildApp(prefs: {'nickname': 'Alvaro'}, data: seed()));
    await pumpFrames(tester);
    expect(find.textContaining('Alvaro'), findsOneWidget);
    expect(find.byType(ProgressRing), findsOneWidget);
    expect(find.byType(GoalCard), findsNWidgets(2));
    expect(find.text('TAP TO SAVE'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('check-run')));
    await pumpFrames(tester);
    expect(find.text('50%'), findsOneWidget);

    await tester.tap(find.byType(ProgressRing));
    await pumpFrames(tester);
    expect(find.text('SAVED · TAP TO EDIT'), findsOneWidget);

    // The goal list scrolls: the last card sits below the fold on a 600 px
    // test surface.
    await tester.ensureVisible(find.text('75').last);
    await pumpFrames(tester);
    await tester.tap(find.text('75').last);
    await pumpFrames(tester);
    expect(find.text('TAP TO SAVE'), findsOneWidget); // dirty again
    expect(find.text('88%'), findsOneWidget); // (100+75)/2 = 87.5 → 88
  });

  testWidgets('empty home shows a "New goal" pill', (tester) async {
    await tester.pumpWidget(await buildApp());
    await pumpFrames(tester);
    expect(find.text('New goal'), findsOneWidget);
    expect(find.byType(GoalCard), findsNothing);
  });

  testWidgets('changing the threshold recomputes the header', (tester) async {
    final data = AppData(
      goals: [
        Goal(
            id: 'run',
            name: 'Run',
            type: GoalType.percent,
            createdAt: yesterday,
            archivedAt: null,
            updatedAt: u),
        Goal(
            id: 'read',
            name: 'Read',
            type: GoalType.percent,
            createdAt: yesterday,
            archivedAt: null,
            updatedAt: u),
      ],
      entries: [
        DayEntry(
            date: yesterday,
            values: const {'run': 50, 'read': 50},
            updatedAt: u)
      ],
    );
    await tester.pumpWidget(await buildApp(data: data));
    await pumpFrames(tester);
    // Default threshold 50: yesterday's 50 % average counts.
    final badge = find.byType(StreakBadge);
    expect(
        find.descendant(of: badge, matching: find.text('1')), findsOneWidget);

    tester
        .element(find.byType(HomePage))
        .read<SettingsStore>()
        .setThreshold(90);
    await pumpFrames(tester);
    expect(
        find.descendant(of: badge, matching: find.text('0')), findsOneWidget);
  });
}
