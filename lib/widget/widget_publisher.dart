import '../engine/consistency_engine.dart';
import '../l10n/app_localizations.dart';
import '../models/app_data.dart';
import '../models/date_key.dart';
import 'widget_bridge.dart';

/// Home-screen widget content, computed once from [AppData] so the
/// Android side only ever writes/reads plain strings — no engine, no l10n.
class WidgetSnapshot {
  final int streak;
  final bool todayDone;
  final String nickname;
  final String week;
  final String line1;
  final String line2;

  WidgetSnapshot({
    required this.streak,
    required this.todayDone,
    required this.nickname,
    required this.week,
    required this.line1,
    required this.line2,
  });
}

class WidgetPublisher {
  /// Builds the widget's content for [today].
  ///
  /// [week] is 7 characters, oldest (`today` - 6) first and `today` last:
  /// `-` when [ConsistencyEngine.dayAverage] is null (no data that day),
  /// else the day's quality tier using the same cut-offs as
  /// `AppTokens.qualityFor` (<25 -> 1, <50 -> 2, <75 -> 3, else -> 4).
  /// Tier `0` is never emitted here — `AppTokens.qualityTier` uses it for
  /// "no data", which this widget spells `-` instead.
  static WidgetSnapshot snapshot({
    required AppData data,
    required int threshold,
    required DateTime today,
    required String nickname,
    required AppLocalizations l10n,
  }) {
    final day = dateOnly(today);
    final engine =
        ConsistencyEngine(data: data, threshold: threshold, today: day);
    final streak = engine.globalStreak();
    final todayDone = data.entryOn(day) != null;
    final week = StringBuffer();
    for (var i = 6; i >= 0; i--) {
      final d = DateTime(day.year, day.month, day.day - i);
      week.write(_tier(engine.dayAverage(d)));
    }
    return WidgetSnapshot(
      streak: streak,
      todayDone: todayDone,
      nickname: nickname,
      week: week.toString(),
      line1: l10n.widgetStreak(streak),
      line2: todayDone ? l10n.widgetTodayDone : l10n.widgetTodayPending,
    );
  }

  static String _tier(double? avgPercent) {
    if (avgPercent == null) return '-';
    if (avgPercent < 25) return '1';
    if (avgPercent < 50) return '2';
    if (avgPercent < 75) return '3';
    return '4';
  }

  static Future<void> publish(WidgetBridge bridge, WidgetSnapshot s) async {
    await bridge.save('streak', s.streak);
    await bridge.save('todayDone', s.todayDone);
    await bridge.save('nickname', s.nickname);
    await bridge.save('week', s.week);
    await bridge.save('line1', s.line1);
    await bridge.save('line2', s.line2);
    // Not read by the Android side (nothing there compares timestamps);
    // it is here so the widget's SharedPreferences file says when it was
    // last written when someone is debugging a stale-looking widget.
    await bridge.save('updatedAt', DateTime.now().toUtc().toIso8601String());
    await bridge.update();
  }
}
