import 'package:flutter/material.dart';

import 'app_tokens.dart';
import 'colors.dart';
import 'local_data.dart';
import 'text_styles.dart';

class ThemeModel extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;

  ThemeModel() {
    _load();
  }

  ThemeMode get themeMode => _themeMode;

  Future<void> _load() async {
    final localData = await LocalData.i;
    _themeMode = switch (localData.searchTheme()) {
      null => ThemeMode.system,
      true => ThemeMode.dark,
      false => ThemeMode.light,
    };
    notifyListeners();
  }

  Future<void> setMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    final localData = await LocalData.i;
    await localData.saveThemeDark(switch (mode) {
      ThemeMode.system => null,
      ThemeMode.dark => true,
      ThemeMode.light => false,
    });
  }
}

ThemeData buildTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final tokens = dark ? AppTokens.dark : AppTokens.light;
  final onSurface = dark ? AppColors.textDark : AppColors.textLight;
  final onSurfaceVariant = dark ? AppColors.text2Dark : AppColors.text2Light;
  final surface = dark ? AppColors.surfaceDark : AppColors.surfaceLight;
  final card = dark ? AppColors.cardDark : AppColors.cardLight;
  final inset = dark ? AppColors.insetDark : AppColors.insetLight;
  final divider = dark ? AppColors.dividerDark : AppColors.dividerLight;
  final text = TextStyles(onSurface);

  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.primaryColor,
    brightness: brightness,
  ).copyWith(
    primary: AppColors.primaryColor.shade500,
    onPrimary: Colors.white,
    surface: surface,
    onSurface: onSurface,
    onSurfaceVariant: onSurfaceVariant,
    surfaceContainer: card,
    surfaceContainerLow: inset,
    outline: AppColors.primaryColor,
    outlineVariant: divider,
    error: AppColors.redColor,
    onError: Colors.white,
  );

  OutlineInputBorder border(Color c) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(30),
        borderSide: BorderSide(color: c, width: 2),
      );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    primaryColor: AppColors.primaryColor,
    scaffoldBackgroundColor: surface,
    cardColor: card,
    dividerColor: divider,
    fontFamily: TextStyles.font,
    iconTheme: IconThemeData(color: onSurface),
    extensions: [tokens],
    inputDecorationTheme: InputDecorationTheme(
      disabledBorder: border(divider),
      enabledBorder: border(onSurfaceVariant),
      focusedBorder: border(AppColors.primaryColor),
      errorBorder: border(AppColors.redColor.shade200),
      focusedErrorBorder: border(AppColors.redColor),
      contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
      labelStyle: text.normalText,
      floatingLabelStyle: text.normalText,
      errorStyle: text.normalText.copyWith(color: AppColors.redColor),
    ),
    progressIndicatorTheme:
        const ProgressIndicatorThemeData(color: AppColors.primaryColor),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primaryColor,
        foregroundColor: Colors.white,
        textStyle: text.normalText,
        alignment: Alignment.center,
        shape: const StadiumBorder(),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    ),
    textSelectionTheme: TextSelectionThemeData(
      selectionColor: AppColors.primaryColor.withValues(alpha: .35),
      selectionHandleColor: AppColors.primaryColor,
      cursorColor: onSurface,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: inset,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      indicatorColor: AppColors.primaryColor,
      indicatorShape: const StadiumBorder(),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => text.normalText.copyWith(
          fontSize: 12,
          color:
              s.contains(WidgetState.selected) ? onSurface : onSurfaceVariant,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(
          color: s.contains(WidgetState.selected)
              ? Colors.white
              : onSurfaceVariant,
        ),
      ),
    ),
  );
}

final ThemeData themeLight = buildTheme(Brightness.light);
final ThemeData themeDark = buildTheme(Brightness.dark);
