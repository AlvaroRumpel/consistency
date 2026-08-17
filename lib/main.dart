import 'dart:async' show unawaited;
import 'dart:ui' show Locale, PlatformDispatcher;

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
import 'models/date_key.dart';
import 'notifications/reminder_scheduler.dart';
import 'notifications/reminder_service.dart';
import 'pages/onboarding_page.dart';
import 'pages/skeleton_page.dart';
import 'pages/splash_page.dart';
import 'state/app_store.dart';
import 'state/settings_store.dart';
import 'widget/home_widget_bridge.dart';
import 'widget/widget_bridge.dart';
import 'widget/widget_publisher.dart';
import 'widget/widget_sync_service.dart';

const _widgetTickTask = 'widget-tick';

/// WorkManager entry point. Runs in a headless engine with no app state, so
/// it rebuilds just enough (prefs, repo, both stores) to publish once and
/// exits — any failure is swallowed so a bad tick never wedges the schedule.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final repo = await FileGoalsRepository.open();
      final store = AppStore(repo);
      await store.load();
      final settings = SettingsStore(SettingsRepository(prefs));

      var locale = PlatformDispatcher.instance.locale;
      if (!AppLocalizations.delegate.isSupported(locale)) {
        locale = const Locale('en');
      }
      final l10n = await AppLocalizations.delegate.load(locale);
      final snapshot = WidgetPublisher.snapshot(
        data: store.data,
        threshold: settings.threshold,
        today: dateOnly(DateTime.now()),
        nickname: settings.nickname ?? l10n.defaultNickname,
        l10n: l10n,
      );
      await WidgetPublisher.publish(HomeWidgetBridge(), snapshot);
    } catch (e, s) {
      debugPrint('widget tick failed: $e\n$s');
    }
    return true;
  });
}

/// Time until the next 00:05 local, so the first tick lands there and every
/// 24h after (WorkManager reschedules itself from [Workmanager.frequency]).
Duration _delayToNextFiveAfterMidnight(DateTime now) {
  var next = DateTime(now.year, now.month, now.day, 0, 5);
  if (!next.isAfter(now)) next = next.add(const Duration(days: 1));
  return next.difference(now);
}

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
    await Workmanager().registerPeriodicTask(
      _widgetTickTask,
      'widgetTick',
      frequency: const Duration(hours: 24),
      initialDelay: _delayToNextFiveAfterMidnight(DateTime.now()),
    );
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
