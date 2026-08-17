import 'package:consistency/configs/date_format.dart';
import 'package:consistency/configs/theme.dart';
import 'package:consistency/data/backup_service.dart';
import 'package:consistency/data/fake_backup_service.dart';
import 'package:consistency/data/goals_repository.dart';
import 'package:consistency/data/in_memory_goals_repository.dart';
import 'package:consistency/data/settings_repository.dart';
import 'package:consistency/l10n/app_localizations.dart';
import 'package:consistency/main.dart';
import 'package:consistency/models/app_data.dart';
import 'package:consistency/models/date_key.dart';
import 'package:consistency/notifications/fake_reminder_scheduler.dart';
import 'package:consistency/notifications/reminder_service.dart';
import 'package:consistency/state/app_store.dart';
import 'package:consistency/state/settings_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A repository that loads fine but can never write.
class SaveThrowsRepository extends InMemoryGoalsRepository {
  SaveThrowsRepository([super.stored]);

  @override
  Future<void> save(AppData data) async =>
      throw const FormatException('disk full');
}

Future<(SettingsStore, AppStore)> _stores(Map<String, Object> prefs,
    AppData? data, bool failSaves, GoalsRepository? repo) async {
  SharedPreferences.setMockInitialValues(prefs);
  final p = await SharedPreferences.getInstance();
  final store = AppStore(repo ??
      (failSaves ? SaveThrowsRepository(data) : InMemoryGoalsRepository(data)));
  await store.load();
  return (SettingsStore(SettingsRepository(p)), store);
}

/// The whole app over in-memory storage, already loaded. Onboarding is
/// treated as already done unless the caller says otherwise, since most
/// callers exercise Home/Calendar/Settings, not first-run — tests for
/// onboarding itself pass `prefs: {'onboardingDone': false}` explicitly.
Future<ConsistencyApp> buildApp({
  Map<String, Object> prefs = const {},
  AppData? data,
  bool failSaves = false,
  FakeReminderScheduler? scheduler,
  BackupService? backups,
  GoalsRepository? repo,
}) async {
  final seededPrefs = prefs.containsKey('onboardingDone')
      ? prefs
      : {...prefs, 'onboardingDone': true};
  final (settings, store) = await _stores(seededPrefs, data, failSaves, repo);
  return ConsistencyApp(
    settings: settings,
    store: store,
    scheduler: scheduler ?? FakeReminderScheduler(),
    backups: backups ?? FakeBackupService(),
  );
}

/// One page under the same providers and theme as [buildApp].
Future<Widget> wrap(
  Widget child, {
  Map<String, Object> prefs = const {},
  AppData? data,
  BackupService? backups,
}) async {
  final (settings, store) = await _stores(prefs, data, false, null);
  // Not started: pages only read it to enable/disable, and an unstarted
  // service leaves no listeners or lifecycle observer behind.
  final reminders = ReminderService(
    scheduler: FakeReminderScheduler(),
    store: store,
    settings: settings,
  );
  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: settings),
      ChangeNotifierProvider.value(value: store),
      Provider<ReminderService>.value(value: reminders),
      Provider<BackupService>.value(value: backups ?? FakeBackupService()),
    ],
    child: MaterialApp(
      theme: themeLight,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    ),
  );
}

Future<void> pumpFrames(WidgetTester tester, [int n = 10]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// The month the calendar page is showing, read back from its title.
DateTime displayedMonth(WidgetTester tester) {
  final title = tester
      .widget<Text>(find.byKey(const ValueKey('calendar-month-title')))
      .data!;
  final year = int.parse(title.split(' ').last);
  for (var m = 1; m <= 12; m++) {
    if (formatMonthYear(DateTime(year, m)) == title) return DateTime(year, m);
  }
  throw ArgumentError('not a month title: $title');
}

/// Selects [day] through the real UI. The grid only renders the month on
/// screen, so hop with the '‹'/'›' arrows until the target month shows.
Future<void> select(WidgetTester tester, DateTime day) async {
  final target = DateTime(day.year, day.month, day.day);
  final targetMonth = DateTime(target.year, target.month);
  for (var hops = 0; displayedMonth(tester) != targetMonth; hops++) {
    if (hops > 24) fail('$targetMonth is out of reach of the month arrows');
    await tester.tap(find.byKey(ValueKey(
        displayedMonth(tester).isAfter(targetMonth)
            ? 'calendar-prev-month'
            : 'calendar-next-month')));
    await pumpFrames(tester);
  }
  await tester.tap(find.byKey(ValueKey('day-${dateKey(target)}')));
  await pumpFrames(tester);
}
