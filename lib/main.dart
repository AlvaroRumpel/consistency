import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'configs/theme.dart';
import 'data/settings_repository.dart';
import 'pages/skeleton_page.dart';
import 'pages/splash_page.dart';
import 'state/settings_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(ConsistencyApp(settings: SettingsStore(SettingsRepository(prefs))));
}

class ConsistencyApp extends StatelessWidget {
  final SettingsStore settings;
  const ConsistencyApp({super.key, required this.settings});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: settings,
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
