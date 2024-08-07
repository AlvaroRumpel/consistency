import 'package:flutter/material.dart';

import '../configs/theme.dart';

class ThemeProvider extends InheritedNotifier<ThemeModel> {
  const ThemeProvider({
    super.key,
    required super.child,
    required super.notifier,
  });

  static ThemeModel of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ThemeProvider>()?.notifier ??
      ThemeModel();
}
