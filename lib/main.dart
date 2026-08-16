import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'configs/theme.dart';
import 'data/file_goals_repository.dart';
import 'data/legacy_migration.dart';
import 'data/settings_repository.dart';
import 'pages/skeleton_page.dart';
import 'pages/splash_page.dart';
import 'state/app_store.dart';
import 'state/settings_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final repo = await FileGoalsRepository.open();
  await LegacyMigration.runIfNeeded(prefs, repo);
  final store = AppStore(repo);
  unawaited(store.load()); // the splash waits on it
  runApp(
    ConsistencyApp(
      settings: SettingsStore(SettingsRepository(prefs)),
      store: store,
    ),
  );
}

class ConsistencyApp extends StatelessWidget {
  final SettingsStore settings;
  final AppStore store;

  const ConsistencyApp({
    super.key,
    required this.settings,
    required this.store,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider.value(value: store),
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
