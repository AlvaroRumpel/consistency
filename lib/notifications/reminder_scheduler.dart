import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// A single scheduled reminder: a local wall-clock instant plus notification text.
class ReminderRequest {
  final DateTime when;
  final String title;
  final String body;

  const ReminderRequest(
      {required this.when, required this.title, required this.body});
}

/// Platform notification scheduling, kept free of app-state (no AppStore/SettingsStore).
abstract class ReminderScheduler {
  Future<void> init();
  Future<bool> ensurePermission();
  Future<void> schedule(ReminderRequest r);

  /// Cancels the single reminder this app schedules.
  Future<void> cancel();

  /// Cancels everything this app ever posted, reminder included.
  Future<void> cancelAll();
}

const _notificationId = 1;

/// Wraps flutter_local_notifications for Android reminder scheduling.
class LocalReminderScheduler implements ReminderScheduler {
  final _plugin = FlutterLocalNotificationsPlugin();

  /// Makes the reminder repeat every day at the same wall-clock time.
  /// The app reschedules with fresh text whenever it is opened, so the repeat
  /// is only the fallback for a user who never opens it — their body text
  /// (streak, "you haven't saved today") then goes stale. Accepted: a stale
  /// nudge beats no nudge at all.
  @visibleForTesting
  static const repeatComponent = DateTimeComponents.time;

  @override
  Future<void> init() async {
    tz.initializeTimeZones();
    try {
      tz.setLocalLocation(
          tz.getLocation(await FlutterTimezone.getLocalTimezone()));
    } catch (e, s) {
      // Unknown/unavailable zone: tz.local stays UTC. The reminder fires at
      // the wrong hour, which is far better than no reminders at all.
      debugPrint('LocalReminderScheduler: timezone lookup failed: $e\n$s');
    }
    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('ic_notification'),
      ),
    );
  }

  @override
  Future<bool> ensurePermission() async =>
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission() ??
      true;

  @override
  Future<void> schedule(ReminderRequest r) async {
    await _plugin.zonedSchedule(
      _notificationId,
      r.title,
      r.body,
      tz.TZDateTime.from(r.when, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_reminder',
          'Daily reminder',
          importance: Importance.defaultImportance,
          icon: 'ic_notification',
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: repeatComponent,
    );
  }

  @override
  Future<void> cancel() => _plugin.cancel(_notificationId);

  @override
  Future<void> cancelAll() => _plugin.cancelAll();
}
