import 'package:consistency/data/in_memory_goals_repository.dart';
import 'package:consistency/data/settings_repository.dart';
import 'package:consistency/models/app_data.dart';
import 'package:consistency/models/day_entry.dart';
import 'package:consistency/models/goal.dart';
import 'package:consistency/notifications/fake_reminder_scheduler.dart';
import 'package:consistency/notifications/reminder_service.dart';
import 'package:consistency/state/app_store.dart';
import 'package:consistency/state/settings_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final u = DateTime.utc(2026);
  DateTime d(int day) => DateTime(2026, 8, day);
  final goal = Goal(
      id: 'g',
      name: 'G',
      type: GoalType.check,
      createdAt: d(1),
      archivedAt: null,
      updatedAt: u);

  Future<(AppStore, SettingsStore, FakeReminderScheduler, ReminderService)>
      boot({
    List<DayEntry> entries = const [],
    Map<String, Object> prefs = const {
      'notifEnabled': true,
      'notifHour': 20,
      'notifMinute': 0
    },
    DateTime? now,
  }) async {
    SharedPreferences.setMockInitialValues({'nickname': 'Alvaro', ...prefs});
    final p = await SharedPreferences.getInstance();
    final store = AppStore(
        InMemoryGoalsRepository(AppData(goals: [goal], entries: entries)));
    await store.load();
    final settings = SettingsStore(SettingsRepository(p));
    final fake = FakeReminderScheduler();
    final service = ReminderService(
      scheduler: fake,
      store: store,
      settings: settings,
      now: () => now ?? DateTime(2026, 8, 17, 9),
    );
    await service.start();
    return (store, settings, fake, service);
  }

  test('disabled → nothing scheduled', () async {
    final (_, _, fake, _) = await boot(prefs: {'notifEnabled': false});
    expect(fake.scheduled, isEmpty);
    expect(fake.cancels, greaterThan(0));
  });

  test('unsaved today, time still ahead → today at the configured time',
      () async {
    final (_, _, fake, _) = await boot();
    expect(fake.scheduled.single.when, DateTime(2026, 8, 17, 20));
    expect(fake.scheduled.single.body, contains('Alvaro'));
  });

  test('time already passed → tomorrow', () async {
    final (_, _, fake, _) = await boot(now: DateTime(2026, 8, 17, 21));
    expect(fake.scheduled.single.when, DateTime(2026, 8, 18, 20));
  });

  test('already saved today → tomorrow', () async {
    final (_, _, fake, _) = await boot(
      entries: [
        DayEntry(date: d(17), values: {'g': 100}, updatedAt: u)
      ],
    );
    expect(fake.scheduled.single.when, DateTime(2026, 8, 18, 20));
  });

  test('saving today reschedules to tomorrow', () async {
    final (store, _, fake, _) = await boot();
    expect(fake.scheduled.last.when, DateTime(2026, 8, 17, 20));
    await store.saveDay(d(17), {'g': 100});
    expect(fake.scheduled.last.when, DateTime(2026, 8, 18, 20));
  });

  test('changing the time reschedules; disabling cancels', () async {
    final (_, settings, fake, service) = await boot();
    await settings.setNotifTime(7, 30);
    expect(fake.scheduled.last.when,
        DateTime(2026, 8, 18, 7, 30)); // 7:30 today already passed at 9:00
    await service.disable();
    expect(fake.scheduled, isEmpty);
    expect(settings.notifEnabled, isFalse);
  });

  test('enable asks for permission and gives up when denied', () async {
    final (_, settings, fake, service) =
        await boot(prefs: {'notifEnabled': false});
    fake.permissionGranted = false;
    expect(await service.enable(), isFalse);
    expect(settings.notifEnabled, isFalse);
    expect(fake.scheduled, isEmpty);

    fake.permissionGranted = true;
    expect(await service.enable(), isTrue);
    expect(settings.notifEnabled, isTrue);
    expect(fake.scheduled.single.when, DateTime(2026, 8, 17, 20));
  });

  test('body carries the current streak', () async {
    final (_, _, fake, _) = await boot(
      entries: [
        DayEntry(date: d(16), values: {'g': 100}, updatedAt: u)
      ],
    );
    expect(fake.scheduled.single.body, contains('1'));
  });
}
