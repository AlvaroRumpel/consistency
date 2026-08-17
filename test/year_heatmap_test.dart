import 'package:consistency/configs/theme.dart';
import 'package:consistency/l10n/app_localizations.dart';
import 'package:consistency/widgets/year_heatmap.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: themeLight,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    );

void main() {
  testWidgets('YearHeatmap renders day cells and only past ones are tappable',
      (tester) async {
    DateTime? tapped;

    await tester.pumpWidget(_wrap(YearHeatmap(
      year: 2026,
      quality: {DateTime(2026, 1, 5): 100},
      today: DateTime(2026, 8, 16),
      onSelect: (d) => tapped = d,
    )));

    expect(find.byKey(const ValueKey('hm-2026-01-05')), findsOneWidget);
    expect(find.byKey(const ValueKey('hm-2026-12-31')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('hm-2026-01-05')));
    expect(tapped, DateTime(2026, 1, 5));

    tapped = null;
    await tester.tap(find.byKey(const ValueKey('hm-2026-08-20')));
    expect(tapped, isNull);

    // Month labels above the columns, weekday labels at the left.
    expect(find.text('Jan'), findsOneWidget);
    expect(find.text('Dec'), findsOneWidget);
    expect(find.text('W'), findsOneWidget);
  });

  testWidgets('YearHeatmap scrolls horizontally in a narrow window',
      (tester) async {
    tester.view.physicalSize = const Size(300, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap(YearHeatmap(
      year: 2026,
      quality: const {},
      today: DateTime(2026, 8, 16),
      onSelect: (_) {},
    )));

    expect(tester.takeException(), isNull);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
  });

  testWidgets('YearHeatmap only pads the first column when it has to',
      (tester) async {
    // 1 January 2023 is itself a Sunday, so the grid starts exactly there.
    await tester.pumpWidget(_wrap(YearHeatmap(
      year: 2023,
      quality: const {},
      today: DateTime(2023, 12, 31),
      onSelect: (_) {},
    )));
    expect(find.byKey(const ValueKey('hm-2023-01-01')), findsOneWidget);
    expect(find.byKey(const ValueKey('hm-2022-12-31')), findsNothing);

    // 1 January 2024 is a Monday, so its column opens on the Sunday before.
    await tester.pumpWidget(_wrap(YearHeatmap(
      year: 2024,
      quality: const {},
      today: DateTime(2024, 12, 31),
      onSelect: (_) {},
    )));
    expect(find.byKey(const ValueKey('hm-2023-12-31')), findsOneWidget);
  });

  testWidgets('YearSummary states the year totals', (tester) async {
    await tester.pumpWidget(_wrap(const YearSummary(
      year: 2026,
      consistent: 128,
      recorded: 228,
      best: 31,
      current: 12,
    )));

    expect(find.text('2026 · 128 consistent days of 228'), findsOneWidget);
    expect(find.text('best streak 31 days · current 12'), findsOneWidget);

    // Streaks are all-time, so a past year has none to show.
    await tester.pumpWidget(_wrap(const YearSummary(
      year: 2025,
      consistent: 100,
      recorded: 365,
      best: null,
      current: null,
    )));
    expect(find.text('2025 · 100 consistent days of 365'), findsOneWidget);
    expect(find.textContaining('best streak'), findsNothing);
  });
}
