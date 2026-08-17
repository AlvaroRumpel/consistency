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
  Future<void> cancelAll();
}

const _notificationId = 1;

/// Wraps flutter_local_notifications for Android reminder scheduling.
class LocalReminderScheduler implements ReminderScheduler {
  final _plugin = FlutterLocalNotificationsPlugin();

  @override
  Future<void> init() async {
    tz.initializeTimeZones();
    tz.setLocalLocation(
        tz.getLocation(await FlutterTimezone.getLocalTimezone()));
    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
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
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  @override
  Future<void> cancelAll() => _plugin.cancelAll();
}
