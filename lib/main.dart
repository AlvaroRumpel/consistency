import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'configs/theme.dart';
import 'pages/skeleton_page.dart';
import 'pages/splash_page.dart';

void main() {
  runApp(const ConsistencyApp());
}

class ConsistencyApp extends StatelessWidget {
  const ConsistencyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ThemeModel(),
      child: Builder(
        builder: (context) => MaterialApp(
          title: 'Consistency',
          debugShowCheckedModeBanner: false,
          theme: themeLight,
          darkTheme: themeDark,
          themeMode: context.watch<ThemeModel>().themeMode,
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
