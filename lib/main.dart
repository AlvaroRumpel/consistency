import 'package:consistency/configs/theme.dart';
import 'package:consistency/pages/manager_page.dart';
import 'package:consistency/pages/splash_page.dart';
import 'package:consistency/providers/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
              '/manager': (context) => const Skelenton(),
            },
          );
        },
      ),
    );
  }
}
