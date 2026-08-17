import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'configs/theme.dart';
import 'data/backup_service.dart';
import 'data/file_goals_repository.dart';
import 'data/legacy_migration.dart';
import 'data/settings_repository.dart';
import 'notifications/reminder_scheduler.dart';
import 'notifications/reminder_service.dart';
import 'pages/skeleton_page.dart';
import 'pages/splash_page.dart';
import 'state/app_store.dart';
import 'state/settings_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  // If the documents directory is unavailable there is nowhere to store data
  // at all, so that one is left to crash. The migration is only best-effort:
  // its own guard covers a malformed blob, this covers the save/remove I/O.
  final repo = await FileGoalsRepository.open();
  try {
    await LegacyMigration.runIfNeeded(prefs, repo);
  } catch (e, s) {
    debugPrint('LegacyMigration.runIfNeeded failed: $e\n$s');
  }
  final store = AppStore(repo);
  unawaited(store.load()); // the splash waits on it
  runApp(
    ConsistencyApp(
      settings: SettingsStore(SettingsRepository(prefs)),
      store: store,
      scheduler: LocalReminderScheduler(),
      backups: PlatformBackupService(),
    ),
  );
}

class ConsistencyApp extends StatefulWidget {
  final SettingsStore settings;
  final AppStore store;
  final ReminderScheduler scheduler;
  final BackupService backups;

  const ConsistencyApp({
    super.key,
    required this.settings,
    required this.store,
    required this.scheduler,
    required this.backups,
  });

  @override
  State<ConsistencyApp> createState() => _ConsistencyAppState();
}

class _ConsistencyAppState extends State<ConsistencyApp> {
  late final ReminderService _reminders = ReminderService(
    scheduler: widget.scheduler,
    store: widget.store,
    settings: widget.settings,
  );

  @override
  void initState() {
    super.initState();
    unawaited(_reminders.start());
  }

  @override
  void dispose() {
    _reminders.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: widget.settings),
        ChangeNotifierProvider.value(value: widget.store),
        Provider<ReminderService>.value(value: _reminders),
        Provider<BackupService>.value(value: widget.backups),
      ],
      child: Builder(
        builder: (context) => MaterialApp(
          title: 'Consistency',
          debugShowCheckedModeBanner: false,
          theme: themeLight,
          darkTheme: themeDark,
          themeMode: context.watch<SettingsStore>().themeMode,
          initialRoute: '/',
          routes: {
            '/': (context) => const SplashPage(),
            '/manager': (context) => const SkelentonPage(),
          },
        ),
      ),
    );
  }
}
