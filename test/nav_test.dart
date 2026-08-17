import 'package:consistency/pages/calendar_page.dart';
import 'package:consistency/pages/home_page.dart';
import 'package:consistency/pages/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  testWidgets('three tabs, home first, no FAB', (tester) async {
    await tester.pumpWidget(await buildApp());
    await pumpFrames(tester);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.byType(HomePage), findsOneWidget);
    await tester.tap(find.text('Calendar'));
    await pumpFrames(tester);
    expect(find.byType(CalendarPage), findsOneWidget);
    await tester.tap(find.text('Settings'));
    await pumpFrames(tester);
    expect(find.byType(SettingsPage), findsOneWidget);
    expect(find.byType(NavigationDestination), findsNWidgets(3));
  });
}
