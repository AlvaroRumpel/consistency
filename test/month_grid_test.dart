import 'package:consistency/configs/theme.dart';
import 'package:consistency/widgets/month_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) =>
    MaterialApp(theme: themeLight, home: Scaffold(body: child));

void main() {
  testWidgets('MonthGrid renders 31 day cells, header, and handles selection',
      (tester) async {
    final today = DateTime(2026, 8, 16);
    final selected = DateTime(2026, 8, 14);
    DateTime? tapped;

    await tester.pumpWidget(_wrap(MonthGrid(
      month: DateTime(2026, 8),
      quality: {
        DateTime(2026, 8, 3): 100,
        DateTime(2026, 8, 4): 0,
      },
      today: today,
      selected: selected,
      onSelect: (d) => tapped = d,
    )));

    for (var d = 1; d <= 31; d++) {
      final key = 'day-2026-08-${d.toString().padLeft(2, '0')}';
      expect(find.byKey(ValueKey(key)), findsOneWidget, reason: key);
    }

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('weekday-header')),
        matching: find.byType(Text),
      ),
      findsNWidgets(7),
    );

    await tester.tap(find.byKey(const ValueKey('day-2026-08-05')));
    expect(tapped, DateTime(2026, 8, 5));

    tapped = null;
    await tester.tap(find.byKey(const ValueKey('day-2026-08-20')));
    expect(tapped, isNull);

    // 1 August 2026 is a Saturday: last column, so the Sunday after it starts
    // the next row and sits further left.
    double dx(String key) => tester.getTopLeft(find.byKey(ValueKey(key))).dx;
    expect(dx('day-2026-08-02'), lessThan(dx('day-2026-08-01')));
  });

  testWidgets('MonthGrid renders a leap February and nothing past it',
      (tester) async {
    await tester.pumpWidget(_wrap(MonthGrid(
      month: DateTime(2028, 2),
      quality: const {},
      today: DateTime(2028, 3, 15),
      selected: DateTime(2028, 2, 29),
      onSelect: (_) {},
    )));

    expect(find.byKey(const ValueKey('day-2028-02-29')), findsOneWidget);
    expect(find.byKey(const ValueKey('day-2028-03-01')), findsNothing);
  });
}
