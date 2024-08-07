import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'configs/theme.dart';
import 'pages/skeleton_page.dart';
import 'pages/splash_page.dart';
import 'providers/theme_provider.dart';

void main() {
  runApp(const ConsistencyApp());
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
}

class ConsistencyApp extends StatefulWidget {
  const ConsistencyApp({super.key});

  @override
  State<ConsistencyApp> createState() => _ConsistencyAppState();
}

class _ConsistencyAppState extends State<ConsistencyApp> {
  ThemeModel theme = ThemeModel();

  @override
  Widget build(BuildContext context) {
    return ThemeProvider(
      notifier: theme,
      child: Builder(
        builder: (context) {
          return MaterialApp(
            title: 'Consistency',
            debugShowCheckedModeBanner: false,
            darkTheme: themeDark,
            themeMode: ThemeProvider.of(context).themeMode,
            theme: themeLight,
            initialRoute: '/',
            routes: {
              '/': (context) => const SplashPage(),
              '/manager': (context) => const SkelentonPage(),
            },
          );
        },
      ),
    );
  }
}
