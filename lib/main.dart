import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import 'configs/l10n_ext.dart';
import 'configs/theme.dart';
import 'data/backup_service.dart';
import 'data/file_goals_repository.dart';
import 'data/legacy_migration.dart';
import 'data/settings_repository.dart';
import 'l10n/app_localizations.dart';
import 'notifications/reminder_scheduler.dart';
import 'notifications/reminder_service.dart';
import 'pages/onboarding_page.dart';
import 'pages/skeleton_page.dart';
import 'pages/splash_page.dart';
import 'state/app_store.dart';
import 'state/settings_store.dart';
import 'widget/home_widget_bridge.dart';
import 'widget/widget_bridge.dart';
import 'widget/widget_sync_service.dart';
import 'widget/widget_tick.dart';

const _widgetTickTask = 'widget-tick';

/// WorkManager entry point. Runs in a headless engine with no app state, so
/// it rebuilds just enough (prefs, repo, both stores) to publish once, books
/// the next tick and exits — any failure is swallowed so a bad tick never
/// wedges the schedule.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final repo = await FileGoalsRepository.open();
      final store = AppStore(repo);
      await store.load();
      await publishTick(
        bridge: HomeWidgetBridge(),
        store: store,
        settings: SettingsStore(SettingsRepository(prefs)),
        now: DateTime.now(),
      );
      await _scheduleTick();
    } catch (e, s) {
      debugPrint('widget tick failed: $e\n$s');
    }
    return true;
  });
}

/// (Re)anchors the daily tick on the next 00:05 local. One-off rather than
/// periodic: a periodic task keeps the anchor it was first registered with,
/// so it drifts off midnight and never re-aligns — each run books the next
/// one from the current clock instead. `replace` from inside the running
/// tick also cancels that run, which is harmless: it has already published
/// by the time this is called, and the replacement is what keeps the chain
/// alive.
Future<void> _scheduleTick() => Workmanager().registerOneOffTask(
      _widgetTickTask,
      'widgetTick',
      initialDelay: delayToNextTick(DateTime.now()),
      existingWorkPolicy: ExistingWorkPolicy.replace,
    );

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
  try {
    await Workmanager().initialize(callbackDispatcher);
    await _scheduleTick();
  } catch (e, s) {
    debugPrint('Workmanager setup failed: $e\n$s');
  }
  runApp(
    ConsistencyApp(
      settings: SettingsStore(SettingsRepository(prefs)),
      store: store,
      scheduler: LocalReminderScheduler(),
      backups: PlatformBackupService(),
      bridge: HomeWidgetBridge(),
    ),
  );
}

class ConsistencyApp extends StatefulWidget {
  final SettingsStore settings;
  final AppStore store;
  final ReminderScheduler scheduler;
  final BackupService backups;
  final WidgetBridge bridge;

  const ConsistencyApp({
    super.key,
    required this.settings,
    required this.store,
    required this.scheduler,
    required this.backups,
    required this.bridge,
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
  late final WidgetSyncService _widgetSync = WidgetSyncService(
    bridge: widget.bridge,
    store: widget.store,
    settings: widget.settings,
  );

  @override
  void initState() {
    super.initState();
    unawaited(_reminders.start());
    unawaited(_widgetSync.start());
  }

  @override
  void dispose() {
    _reminders.dispose();
    _widgetSync.dispose();
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
          onGenerateTitle: (context) => context.l10n.appTitle,
          debugShowCheckedModeBanner: false,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          theme: themeLight,
          darkTheme: themeDark,
          themeMode: context.watch<SettingsStore>().themeMode,
          initialRoute: '/',
          routes: {
            '/': (context) => const SplashPage(),
            '/onboarding': (context) => const OnboardingPage(),
            '/manager': (context) => const SkelentonPage(),
          },
        ),
      ),
    );
  }
}
