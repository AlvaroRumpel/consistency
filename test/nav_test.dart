import 'package:consistency/pages/calendar_page.dart';
import 'package:consistency/pages/home_page.dart';
import 'package:consistency/pages/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  // Calendar 0, Home 1, Settings 2 - an IndexedStack keeps all three alive,
  // so only the selected index tells the tabs apart.
  void expectSelected(WidgetTester tester, int index) {
    expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        index);
    expect(tester.widget<IndexedStack>(find.byType(IndexedStack).first).index,
        index);
  }

  testWidgets('three tabs, home first, no FAB', (tester) async {
    await tester.pumpWidget(await buildApp());
    await pumpFrames(tester);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.byType(NavigationDestination), findsNWidgets(3));
    expect(find.byType(HomePage), findsOneWidget);
    expectSelected(tester, 1);
    await tester.tap(find.text('Calendar'));
    await pumpFrames(tester);
    expect(find.byType(CalendarPage), findsOneWidget);
    expectSelected(tester, 0);
    await tester.tap(find.text('Settings'));
    await pumpFrames(tester);
    expect(find.byType(SettingsPage), findsOneWidget);
    expectSelected(tester, 2);
  });
}
