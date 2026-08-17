import 'dart:io';

import 'package:consistency/models/app_data.dart';
import 'package:consistency/models/goal.dart';
import 'package:consistency/pages/onboarding_page.dart';
import 'package:consistency/pages/skeleton_page.dart';
import 'package:consistency/state/app_store.dart';
import 'package:consistency/state/settings_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A truly fresh install (no prefs at all) also has onboardingDone unset,
  // i.e. false — same as passing it explicitly. buildApp() otherwise
  // defaults onboardingDone to true so unrelated tests land on Home.
  const fresh = {'onboardingDone': false};

  testWidgets('fresh install with no goals lands on onboarding',
      (tester) async {
    await tester.pumpWidget(await buildApp(prefs: fresh));
    await pumpFrames(tester);
    expect(find.byType(OnboardingPage), findsOneWidget);
  });

  testWidgets(
      'Start creates the goal, saves the nickname, marks onboarding done, '
      'and shows Home', (tester) async {
    await tester.pumpWidget(await buildApp(prefs: fresh));
    await pumpFrames(tester);

    await tester.enterText(
        find.byKey(const ValueKey('onboarding-nickname')), 'Ana');
    await tester.enterText(
        find.byKey(const ValueKey('onboarding-goal-name')), 'Run 5 km');
    await tester.tap(find.text('Percent 0–100'));
    await pumpFrames(tester);
    await tester.tap(find.text('Start'));
    await pumpFrames(tester, 30); // let the push-replacement settle

    expect(find.byType(SkelentonPage), findsOneWidget);
    final element = tester.element(find.byType(SkelentonPage));
    final store = element.read<AppStore>();
    final settings = element.read<SettingsStore>();
    expect(store.data.goals, hasLength(1));
    expect(store.data.goals.single.name, 'Run 5 km');
    expect(store.data.goals.single.type, GoalType.percent);
    expect(settings.nickname, 'Ana');
    expect(settings.onboardingDone, isTrue);
  });

  testWidgets('Start with a blank nickname skips saving it', (tester) async {
    await tester.pumpWidget(await buildApp(prefs: fresh));
    await pumpFrames(tester);

    await tester.enterText(
        find.byKey(const ValueKey('onboarding-goal-name')), 'Meditate');
    await pumpFrames(tester);
    await tester.tap(find.text('Start'));
    await pumpFrames(tester, 30); // let the push-replacement settle

    final settings =
        tester.element(find.byType(SkelentonPage)).read<SettingsStore>();
    expect(settings.nickname, isNull);
  });

  testWidgets('Start is disabled until the goal name is non-empty',
      (tester) async {
    await tester.pumpWidget(await buildApp(prefs: fresh));
    await pumpFrames(tester);

    final button =
        tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Start'));
    expect(button.onPressed, isNull);

    await tester.enterText(
        find.byKey(const ValueKey('onboarding-goal-name')), 'Read');
    await pumpFrames(tester);

    final enabled =
        tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Start'));
    expect(enabled.onPressed, isNotNull);
  });

  testWidgets(
      'install that already has goals skips onboarding and marks it done',
      (tester) async {
    final data = AppData.empty.copyWith(goals: [
      Goal(
        id: 'g1',
        name: 'Existing',
        type: GoalType.check,
        createdAt: DateTime(2026, 1, 1),
        archivedAt: null,
        updatedAt: DateTime(2026, 1, 1),
      ),
    ]);
    await tester.pumpWidget(await buildApp(prefs: fresh, data: data));
    await pumpFrames(tester);

    expect(find.byType(SkelentonPage), findsOneWidget);
    expect(find.byType(OnboardingPage), findsNothing);
    final settings =
        tester.element(find.byType(SkelentonPage)).read<SettingsStore>();
    expect(settings.onboardingDone, isTrue);
  });

  testWidgets('onboardingDone true with no goals goes straight to Home',
      (tester) async {
    await tester.pumpWidget(await buildApp(prefs: {'onboardingDone': true}));
    await pumpFrames(tester);

    expect(find.byType(SkelentonPage), findsOneWidget);
    expect(find.byType(OnboardingPage), findsNothing);
  });

  test('onboarding page has no hardcoded colours', () {
    final src = File('lib/pages/onboarding_page.dart').readAsStringSync();
    expect(src.contains('Color(0x'), isFalse);
    expect(src.contains('Colors.'), isFalse);
  });
}
