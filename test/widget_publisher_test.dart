import 'package:consistency/l10n/app_localizations_en.dart';
import 'package:consistency/l10n/app_localizations_pt.dart';
import 'package:consistency/models/app_data.dart';
import 'package:consistency/models/day_entry.dart';
import 'package:consistency/models/goal.dart';
import 'package:consistency/widget/fake_widget_bridge.dart';
import 'package:consistency/widget/widget_publisher.dart';
import 'package:flutter_test/flutter_test.dart';

final _u = DateTime.utc(2026, 1, 1);
DateTime d(int day) => DateTime(2026, 8, day);

Goal goal(String id, GoalType t, {int created = 1}) => Goal(
      id: id,
      name: id,
      type: t,
      createdAt: d(created),
      archivedAt: null,
      updatedAt: _u,
    );

DayEntry entry(int day, Map<String, double> v) =>
    DayEntry(date: d(day), values: v, updatedAt: _u);

void main() {
  final en = AppLocalizationsEn();
  final pt = AppLocalizationsPt();

  test('empty data: no streak, no history, today pending', () {
    final s = WidgetPublisher.snapshot(
      data: AppData.empty,
      threshold: 50,
      today: d(10),
      nickname: 'Alvaro',
      l10n: en,
    );
    expect(s.streak, 0);
    expect(s.todayDone, isFalse);
    expect(s.week, '-------');
    expect(s.line1, en.widgetStreak(0));
    expect(s.line2, en.widgetTodayPending);
  });

  test('a saved today marks todayDone and the week\'s last char a tier', () {
    final g = goal('g', GoalType.percent, created: 10);
    final data = AppData(goals: [
      g
    ], entries: [
      entry(10, {'g': 100})
    ]);
    final s = WidgetPublisher.snapshot(
      data: data,
      threshold: 50,
      today: d(10),
      nickname: 'Alvaro',
      l10n: en,
    );
    expect(s.todayDone, isTrue);
    expect(s.week, '------4');
    expect(s.line2, en.widgetTodayDone);
  });

  test('a 3-day streak', () {
    final g = goal('g', GoalType.check, created: 1);
    final data = AppData(goals: [
      g
    ], entries: [
      entry(8, {'g': 100}),
      entry(9, {'g': 100}),
      entry(10, {'g': 100}),
    ]);
    final s = WidgetPublisher.snapshot(
      data: data,
      threshold: 50,
      today: d(10),
      nickname: 'Alvaro',
      l10n: en,
    );
    expect(s.streak, 3);
    expect(s.line1, en.widgetStreak(3));
  });

  test('publish writes all seven keys and updates once', () async {
    final bridge = FakeWidgetBridge();
    final s = WidgetPublisher.snapshot(
      data: AppData.empty,
      threshold: 50,
      today: d(10),
      nickname: 'Alvaro',
      l10n: en,
    );

    await WidgetPublisher.publish(bridge, s);

    expect(
      bridge.data.keys.toSet(),
      {
        'streak',
        'todayDone',
        'nickname',
        'week',
        'line1',
        'line2',
        'updatedAt'
      },
    );
    expect(bridge.data['streak'], 0);
    expect(bridge.data['todayDone'], isFalse);
    expect(bridge.data['nickname'], 'Alvaro');
    expect(bridge.data['week'], '-------');
    expect(bridge.data['line1'], en.widgetStreak(0));
    expect(bridge.data['line2'], en.widgetTodayPending);
    expect(bridge.updates, 1);
  });

  test('PT locale produces PT lines', () {
    final s = WidgetPublisher.snapshot(
      data: AppData.empty,
      threshold: 50,
      today: d(10),
      nickname: 'Alvaro',
      l10n: pt,
    );
    expect(s.line1, pt.widgetStreak(0));
    expect(s.line2, 'Hoje: pendente');
  });
}
