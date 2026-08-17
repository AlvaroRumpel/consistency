import 'package:consistency/notifications/fake_reminder_scheduler.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('off by default; enabling shows the configured time',
      (tester) async {
    final fake = FakeReminderScheduler();
    final app = await buildApp(scheduler: fake);
    await tester.pumpWidget(app);
    await pumpFrames(tester);
    await tester.tap(find.text('Settings'));
    await pumpFrames(tester);

    final switchFinder = find.byType(Switch);
    expect(tester.widget<Switch>(switchFinder).value, isFalse);

    await tester.tap(switchFinder);
    await pumpFrames(tester);

    expect(tester.widget<Switch>(switchFinder).value, isTrue);
    expect(find.text('20:00'), findsOneWidget);
  });

  testWidgets('permission denied keeps it off and shows a snackbar',
      (tester) async {
    final fake = FakeReminderScheduler()..permissionGranted = false;
    final app = await buildApp(scheduler: fake);
    await tester.pumpWidget(app);
    await pumpFrames(tester);
    await tester.tap(find.text('Settings'));
    await pumpFrames(tester);

    final switchFinder = find.byType(Switch);
    await tester.tap(switchFinder);
    await pumpFrames(tester);

    expect(tester.widget<Switch>(switchFinder).value, isFalse);
    expect(
      find.text('Notifications are blocked in system settings.'),
      findsOneWidget,
    );
  });
}
