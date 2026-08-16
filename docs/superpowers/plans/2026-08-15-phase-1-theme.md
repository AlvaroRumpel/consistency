# Phase 1 — Theme / M3 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** One source of truth for colors/type (the approved design tokens) exposed through `ThemeData` + a `ThemeExtension`, `provider` for the theme state with an explicit System/Light/Dark choice, and zero `isDark ? a : b` branching outside the theme files.

**Architecture:** `AppTokens` (a `ThemeExtension`) carries the day-quality scale, streak-flame tiers and success color; `buildTheme(Brightness)` builds both `ThemeData`s from token constants. `ThemeModel` stays a `ChangeNotifier` but is provided via `ChangeNotifierProvider`; widgets read `context.watch<ThemeModel>()`. `TextStyles` derives its color from `colorScheme.onSurface`. Visual output must match the approved design tokens, not the old palette.

**Tech Stack:** Flutter 3.41 (Material 3), `provider`, `shared_preferences`.

**Spec:** `docs/superpowers/specs/2026-08-15-consistency-v2-design.md` — fase 1. Tokens: Claude Design project `b473eda8-1101-4699-a494-6390baa9a37e`, file `tokens.md` (values copied verbatim below so this plan is self-contained).

## Global Constraints

- Token values (light / dark): surface `#E8EEF2` / `#39393A`; surfaceContainer (cards) `#F6F8FA` / `#434345`; surfaceContainerLow (inset, nav, inactive track) `#DCE4EA` / `#2E2E30`; divider `#B9C6CF` / `#5A5A5C`; onSurface `#26282B` / `#F2F5F7`; onSurfaceVariant `#5C646B` / `#B4BAC0`; primary `#2CA8CB` (both); onPrimary `#FFFFFF`; error `#CB2E33`; success `#418F3F`; quality q0 `#C4CFD6` / `#55585B`, q1 `#CB2E33`, q2 `#E0862E`, q3 `#2CA8CB`, q4 `#418F3F`; flame f0 `#8A9299`, f1 `#E0862E`, f2 `#E85D2A`, f3 `#CB2E33`, f4 `#2CA8CB`. Radii: card 28, pill 999, button 16.
- Quality rule: `<25 → q1`, `<50 → q2`, `<75 → q3`, else `q4`; `null` (no data) → q0. Flame tier: `0 → 0`, `1–6 → 1`, `7–29 → 2`, `30–99 → 3`, `≥100 → 4`.
- Persisted key `themeDark` stays a nullable bool: `null` = system, `true` = dark, `false` = light (backward compatible with installed apps).
- Only new package: `provider`. Do not touch data models or `LocalData` beyond `saveThemeMode`.
- Lints `prefer_single_quotes`, `prefer_relative_imports`; `flutter analyze` clean and `flutter test` green before every commit; Conventional Commit subjects.
- Test caveat: `LocalData` caches `SharedPreferences` in a static; `setMockInitialValues` only affects the first `LocalData.i` per test file.

---

### Task 1: `provider` replaces the custom `ThemeProvider`; explicit System/Light/Dark

**Files:**
- Modify: `pubspec.yaml` (add `provider: ^6.1.2` under dependencies)
- Modify: `lib/configs/local_data.dart` (add `saveThemeMode`)
- Modify: `lib/configs/theme.dart` (`ThemeModel.setMode`)
- Modify: `lib/main.dart`
- Modify: `lib/pages/settings_page.dart` (theme row → `SegmentedButton<ThemeMode>`)
- Delete: `lib/providers/theme_provider.dart`
- Test: `test/theme_mode_default_test.dart` (extend)

**Interfaces:**
- Produces: `Future<void> LocalData.saveThemeMode(ThemeMode mode)`; `Future<void> ThemeModel.setMode(ThemeMode mode)`; app tree wraps `MaterialApp` in `ChangeNotifierProvider<ThemeModel>`.
- `ThemeModel.setDark(bool)` is removed (only caller was the settings switch).

- [ ] **Step 1: Add the dependency**

In `pubspec.yaml` under `dependencies:` after `cupertino_icons: ^1.0.2` add:
```yaml
  provider: ^6.1.2
```
Run: `flutter pub get`

- [ ] **Step 2: Write the failing test**

Append to `test/theme_mode_default_test.dart` inside `main()`:
```dart
  test('setMode persists tri-state on the legacy themeDark key', () async {
    final model = ThemeModel();
    final prefs = await SharedPreferences.getInstance();

    await model.setMode(ThemeMode.dark);
    expect(model.themeMode, ThemeMode.dark);
    expect(prefs.getBool('themeDark'), isTrue);

    await model.setMode(ThemeMode.light);
    expect(prefs.getBool('themeDark'), isFalse);

    await model.setMode(ThemeMode.system);
    expect(model.themeMode, ThemeMode.system);
    expect(prefs.containsKey('themeDark'), isFalse);
  });
```

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/theme_mode_default_test.dart`
Expected: FAIL — `The method 'setMode' isn't defined for the type 'ThemeModel'`.

- [ ] **Step 4: `LocalData.saveThemeMode`**

In `lib/configs/local_data.dart` (no new imports; `LocalData` stays free of `material.dart`) replace the `saveTheme` method with:
```dart
  /// null = follow the system. Stored on the legacy `themeDark` bool key so
  /// installed apps keep their choice.
  Future<void> saveThemeDark(bool? dark) => dark == null
      ? _sharedPreferences!.remove(_themeDark)
      : _sharedPreferences!.setBool(_themeDark, dark);
```
and update `clearAllData`'s `if (theme != null) await saveTheme(theme);` to `await saveThemeDark(theme);`.

- [ ] **Step 5: `ThemeModel.setMode`**

In `lib/configs/theme.dart` replace `setDark` with:
```dart
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
```

- [ ] **Step 6: Provide with `provider`**

`lib/main.dart` — full new content:
```dart
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
```
Delete `lib/providers/theme_provider.dart` (`git rm`).

- [ ] **Step 7: Settings row → segmented Sistema / Claro / Escuro**

In `lib/pages/settings_page.dart`: remove `import '../providers/theme_provider.dart';`, add `import 'package:provider/provider.dart';`. Replace the whole `Builder(builder: (context) { final themeDark = ... Switch ... })` block (the last child of the `Column`) with:
```dart
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(
                        value: ThemeMode.system,
                        label: Text('System'),
                        icon: Icon(Icons.brightness_auto_outlined),
                      ),
                      ButtonSegment(
                        value: ThemeMode.light,
                        label: Text('Light'),
                        icon: Icon(Icons.light_mode_outlined),
                      ),
                      ButtonSegment(
                        value: ThemeMode.dark,
                        label: Text('Dark'),
                        icon: Icon(Icons.dark_mode_outlined),
                      ),
                    ],
                    selected: {context.watch<ThemeModel>().themeMode},
                    onSelectionChanged: (s) =>
                        context.read<ThemeModel>().setMode(s.first),
                  ),
                ),
```
Add `import '../configs/theme.dart';` if not already imported (for `ThemeModel`).

- [ ] **Step 8: Run all tests + analyze**

Run: `flutter test && flutter analyze`
Expected: all PASS, `No issues found!`. (Smoke tests seed `themeDark` true/false and still resolve.)

- [ ] **Step 9: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/main.dart lib/configs lib/pages/settings_page.dart test/theme_mode_default_test.dart
git rm lib/providers/theme_provider.dart
git commit -m "feat: theme via provider with explicit system/light/dark"
```

---

### Task 2: `AppTokens` ThemeExtension + `buildTheme` from design tokens

**Files:**
- Create: `lib/configs/app_tokens.dart`
- Modify: `lib/configs/colors.dart` (append token constants)
- Modify: `lib/configs/theme.dart` (replace the two hand-written `ThemeData` with `buildTheme`)
- Modify: `lib/configs/text_styles.dart` (color from `onSurface`; drop the 100 weight)
- Modify: `pubspec.yaml` (remove `WorkSans-Thin.ttf` entry), Delete: `assets/fonts/WorkSans-Thin.ttf`
- Test: `test/app_tokens_test.dart` (new), `test/theme_tokens_test.dart` + `test/theme_tokens_light_test.dart` (update expected values)

**Interfaces:**
- Produces:
```dart
class AppTokens extends ThemeExtension<AppTokens> {
  final Color success, cardBorder;
  final List<Color> quality; // 5: q0..q4
  final List<Color> flame;   // 5: f0..f4
  Color qualityFor(double? avgPercent);
  static int flameTier(int streakDays);
  Color flameFor(int streakDays);
  static const light = AppTokens(...); static const dark = AppTokens(...);
}
extension AppTokensX on BuildContext { AppTokens get tokens; }
ThemeData buildTheme(Brightness b);
final themeLight = buildTheme(Brightness.light); final themeDark = buildTheme(Brightness.dark);
```
- `TextStyles` constructor becomes `const TextStyles(Color color)`; `context.textStyles` unchanged for callers.

- [ ] **Step 1: Write the failing tests**

`test/app_tokens_test.dart`:
```dart
import 'package:consistency/configs/app_tokens.dart';
import 'package:consistency/configs/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('qualityFor follows the 25/50/75 scale and grey for no data', () {
    final t = AppTokens.light;
    expect(t.qualityFor(null), t.quality[0]);
    expect(t.qualityFor(0), t.quality[1]);
    expect(t.qualityFor(24.9), t.quality[1]);
    expect(t.qualityFor(25), t.quality[2]);
    expect(t.qualityFor(50), t.quality[3]);
    expect(t.qualityFor(74.9), t.quality[3]);
    expect(t.qualityFor(75), t.quality[4]);
    expect(t.qualityFor(100), t.quality[4]);
  });

  test('flame tiers', () {
    expect(AppTokens.flameTier(0), 0);
    expect(AppTokens.flameTier(1), 1);
    expect(AppTokens.flameTier(6), 1);
    expect(AppTokens.flameTier(7), 2);
    expect(AppTokens.flameTier(29), 2);
    expect(AppTokens.flameTier(30), 3);
    expect(AppTokens.flameTier(99), 3);
    expect(AppTokens.flameTier(100), 4);
    expect(AppTokens.flameTier(365), 4);
  });

  test('both themes expose AppTokens and the design surface values', () {
    expect(themeLight.extension<AppTokens>(), same(AppTokens.light));
    expect(themeDark.extension<AppTokens>(), same(AppTokens.dark));
    expect(themeLight.colorScheme.surface, const Color(0xFFE8EEF2));
    expect(themeDark.colorScheme.surface, const Color(0xFF39393A));
    expect(themeLight.cardColor, const Color(0xFFF6F8FA));
    expect(themeDark.cardColor, const Color(0xFF434345));
    expect(themeLight.colorScheme.primary, const Color(0xFF2CA8CB));
    expect(themeDark.colorScheme.onSurface, const Color(0xFFF2F5F7));
  });
}
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/app_tokens_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:consistency/configs/app_tokens.dart'`.

- [ ] **Step 3: Token constants in `colors.dart`**

Append inside `extension AppColors on Colors { ... }` (before the closing `}`):
```dart
  // ---- v2 design tokens (Claude Design tokens.md) ----
  static const surfaceLight = Color(0xFFE8EEF2);
  static const surfaceDark = Color(0xFF39393A);
  static const cardLight = Color(0xFFF6F8FA);
  static const cardDark = Color(0xFF434345);
  static const insetLight = Color(0xFFDCE4EA);
  static const insetDark = Color(0xFF2E2E30);
  static const dividerLight = Color(0xFFB9C6CF);
  static const dividerDark = Color(0xFF5A5A5C);
  static const textLight = Color(0xFF26282B);
  static const textDark = Color(0xFFF2F5F7);
  static const text2Light = Color(0xFF5C646B);
  static const text2Dark = Color(0xFFB4BAC0);
  static const amber = Color(0xFFE0862E);
  static const orange = Color(0xFFE85D2A);
  static const flameGrey = Color(0xFF8A9299);
  static const q0Light = Color(0xFFC4CFD6);
  static const q0Dark = Color(0xFF55585B);
```

- [ ] **Step 4: Create `lib/configs/app_tokens.dart`**

```dart
import 'package:flutter/material.dart';

import 'colors.dart';

/// Design tokens that don't fit ColorScheme: day-quality scale, streak
/// flame tiers, success. Values come from the approved tokens.md.
class AppTokens extends ThemeExtension<AppTokens> {
  final Color success;
  final Color cardBorder;
  final List<Color> quality; // q0 (no data) .. q4 (>= 75 %)
  final List<Color> flame; // f0 (0 days) .. f4 (100+ days)

  const AppTokens({
    required this.success,
    required this.cardBorder,
    required this.quality,
    required this.flame,
  });

  static const _flame = <Color>[
    AppColors.flameGrey,
    AppColors.amber,
    AppColors.orange,
    AppColors.redColor,
    AppColors.primaryColor,
  ];

  static const light = AppTokens(
    success: AppColors.greenColor,
    cardBorder: AppColors.primaryColor,
    quality: [
      AppColors.q0Light,
      AppColors.redColor,
      AppColors.amber,
      AppColors.primaryColor,
      AppColors.greenColor,
    ],
    flame: _flame,
  );

  static const dark = AppTokens(
    success: AppColors.greenColor,
    cardBorder: AppColors.primaryColor,
    quality: [
      AppColors.q0Dark,
      AppColors.redColor,
      AppColors.amber,
      AppColors.primaryColor,
      AppColors.greenColor,
    ],
    flame: _flame,
  );

  /// null = no data for that day.
  Color qualityFor(double? avgPercent) {
    if (avgPercent == null) return quality[0];
    if (avgPercent < 25) return quality[1];
    if (avgPercent < 50) return quality[2];
    if (avgPercent < 75) return quality[3];
    return quality[4];
  }

  static int flameTier(int streakDays) {
    if (streakDays <= 0) return 0;
    if (streakDays < 7) return 1;
    if (streakDays < 30) return 2;
    if (streakDays < 100) return 3;
    return 4;
  }

  Color flameFor(int streakDays) => flame[flameTier(streakDays)];

  @override
  AppTokens copyWith({
    Color? success,
    Color? cardBorder,
    List<Color>? quality,
    List<Color>? flame,
  }) =>
      AppTokens(
        success: success ?? this.success,
        cardBorder: cardBorder ?? this.cardBorder,
        quality: quality ?? this.quality,
        flame: flame ?? this.flame,
      );

  @override
  AppTokens lerp(AppTokens? other, double t) {
    if (other == null) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppTokens(
      success: l(success, other.success),
      cardBorder: l(cardBorder, other.cardBorder),
      quality: [for (var i = 0; i < 5; i++) l(quality[i], other.quality[i])],
      flame: [for (var i = 0; i < 5; i++) l(flame[i], other.flame[i])],
    );
  }
}

extension AppTokensX on BuildContext {
  AppTokens get tokens => Theme.of(this).extension<AppTokens>()!;
}
```

- [ ] **Step 5: `TextStyles` keyed by color, no 100 weight**

`lib/configs/text_styles.dart` — full new content:
```dart
import 'package:flutter/material.dart';

class TextStyles {
  final Color color;

  const TextStyles(this.color);

  static const String font = 'WorkSans';

  TextStyle get normalText => TextStyle(
        color: color,
        fontWeight: FontWeight.w500,
        fontFamily: font,
        fontSize: 16,
      );

  TextStyle get boldText => normalText.copyWith(fontWeight: FontWeight.w700);

  TextStyle get thinText => normalText.copyWith(fontWeight: FontWeight.w400);

  TextStyle get titleText => boldText.copyWith(fontSize: 32);
}

extension TextStylesExtension on BuildContext {
  TextStyles get textStyles => TextStyles(Theme.of(this).colorScheme.onSurface);
}
```
Remove the `WorkSans-Thin.ttf` font entry (the two lines `- asset: assets/fonts/WorkSans-Thin.ttf` / `weight: 100`) from `pubspec.yaml` and `git rm assets/fonts/WorkSans-Thin.ttf`.

- [ ] **Step 6: `buildTheme` in `theme.dart`**

Replace everything from `ThemeData themeDark = ThemeData(` to the end of `lib/configs/theme.dart` with:
```dart
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
    primary: AppColors.primaryColor,
    onPrimary: Colors.white,
    surface: surface,
    onSurface: onSurface,
    onSurfaceVariant: onSurfaceVariant,
    surfaceContainer: card,
    surfaceContainerLow: inset,
    outline: AppColors.primaryColor,
    outlineVariant: divider,
    error: AppColors.redColor,
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
          color: s.contains(WidgetState.selected) ? onSurface : onSurfaceVariant,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(
          color: s.contains(WidgetState.selected) ? Colors.white : onSurfaceVariant,
        ),
      ),
    ),
  );
}

final ThemeData themeLight = buildTheme(Brightness.light);
final ThemeData themeDark = buildTheme(Brightness.dark);
```
Add `import 'app_tokens.dart';` at the top of `theme.dart` (keep `colors.dart`, `local_data.dart`, `text_styles.dart` imports).

- [ ] **Step 7: Update the two existing token tests**

`test/theme_tokens_test.dart` — replace the `group('ThemeData tokens', ...)` body with:
```dart
    test('themeDark carries the design token values', () {
      expect(themeDark.brightness, Brightness.dark);
      expect(themeDark.cardColor, AppColors.cardDark);
      expect(themeDark.scaffoldBackgroundColor, AppColors.surfaceDark);
      expect(themeDark.iconTheme.color, AppColors.textDark);
      expect(themeDark.dividerColor, AppColors.dividerDark);
      expect(themeDark.textSelectionTheme.cursorColor, AppColors.textDark);
    });

    test('themeLight carries the design token values', () {
      expect(themeLight.brightness, Brightness.light);
      expect(themeLight.cardColor, AppColors.cardLight);
      expect(themeLight.scaffoldBackgroundColor, AppColors.surfaceLight);
      expect(themeLight.iconTheme.color, AppColors.textLight);
      expect(themeLight.dividerColor, AppColors.dividerLight);
      expect(themeLight.textSelectionTheme.cursorColor, AppColors.textLight);
    });
```
`test/theme_tokens_light_test.dart` needs no change (asserts brightness only).

- [ ] **Step 8: Run all tests + analyze**

Run: `flutter test && flutter analyze`
Expected: all PASS, `No issues found!`. If `analyze` flags unused imports in `theme.dart` (e.g. `text_styles.dart` if no longer referenced), remove them.

- [ ] **Step 9: Commit**

```bash
git add lib/configs pubspec.yaml test/app_tokens_test.dart test/theme_tokens_test.dart
git rm assets/fonts/WorkSans-Thin.ttf
git commit -m "feat: AppTokens ThemeExtension and token-driven ThemeData"
```

---

### Task 3: Kill every `isDark ? :` outside the theme; route colors through tokens

**Files:**
- Modify: `lib/configs/utilities.dart` (delegate to `AppTokens`)
- Modify: `lib/widgets/list_tile_custom.dart`, `lib/widgets/add_day_button.dart`, `lib/pages/skeleton_page.dart`, `lib/widgets/goals_list_view.dart`, `lib/widgets/goals_done_list_view.dart`, `lib/pages/home_page.dart`, `lib/controllers/calendar_controller.dart`
- Test: `test/no_isdark_test.dart` (new) — a guard that greps `lib/` for the pattern

**Interfaces:**
- `Utilities.activeColor(double)` keeps its signature but returns `AppTokens.light.qualityFor(value)` (q1–q4 are identical in both themes; only q0 differs and `activeColor` never returns q0). Phase 5 deletes `Utilities`.

- [ ] **Step 1: Write the failing guard test**

`test/no_isdark_test.dart`:
```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Phase 1 rule: light/dark branching lives only in the ThemeData builders.
void main() {
  test('no isDark branching outside lib/configs/theme.dart', () {
    final offenders = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      if (f.path.replaceAll('\\', '/').endsWith('lib/configs/theme.dart')) {
        continue;
      }
      final src = f.readAsStringSync();
      if (src.contains('Brightness.dark') || src.contains('isDark')) {
        offenders.add(f.path);
      }
    }
    expect(offenders, isEmpty);
  });
}
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/no_isdark_test.dart`
Expected: FAIL listing `list_tile_custom.dart`, `add_day_button.dart`, `skeleton_page.dart`, `settings_page.dart` (if the Task 1 comment survived — it doesn't reference `Brightness.dark` anymore after Task 1's segmented button; verify).

- [ ] **Step 3: `Utilities.activeColor` → tokens**

`lib/configs/utilities.dart` — full new content:
```dart
import 'package:flutter/material.dart';

import 'app_tokens.dart';

/// Kept for callers that have no BuildContext (calendar controller). q1–q4
/// are theme-independent, so the light table is safe here.
class Utilities {
  static Color activeColor(double value) => AppTokens.light.qualityFor(value);
}
```

- [ ] **Step 4: `list_tile_custom.dart`**

Remove `final isDark = ...`. Replace the arrow icon color with `Theme.of(context).colorScheme.onSurface`. Replace the gradient `Container` with:
```dart
        Divider(height: 2, thickness: 1, color: Theme.of(context).dividerColor),
```
Remove the now-unused `colors.dart` import if `AppColors` is no longer referenced (it still is, for `splashColor: AppColors.primaryColor.shade50` — keep).

- [ ] **Step 5: `add_day_button.dart`**

Remove `final isDark = ...`. Replace the second `BoxShadow`'s `color:` with `Theme.of(context).scaffoldBackgroundColor`.

- [ ] **Step 6: `skeleton_page.dart`**

Remove `final isDark = ...`. In the `FloatingActionButton`:
```dart
                  backgroundColor: value == 1
                      ? AppColors.primaryColor
                      : Theme.of(context).colorScheme.surfaceContainerLow,
```
and the `Icon(Icons.home_outlined, color: ...)`:
```dart
                          color: value == 1
                              ? Colors.white
                              : Theme.of(context).colorScheme.onSurfaceVariant,
```
(Phase 4 replaces this whole nav; this is the minimum to remove the branch.)

- [ ] **Step 7: Slider/track colors from the scheme**

`lib/widgets/goals_list_view.dart`: `inactiveColor: AppColors.whiteColor,` → `inactiveColor: Theme.of(context).colorScheme.surfaceContainerLow,`.
`lib/widgets/goals_done_list_view.dart`: leave `Utilities.activeColor(...)` (now token-backed).
`lib/pages/home_page.dart`: leave `Utilities.activeColor(...)`.
`lib/controllers/calendar_controller.dart`: leave `Utilities.activeColor(...)`.

- [ ] **Step 8: Run all tests + analyze**

Run: `flutter test && flutter analyze`
Expected: all PASS incl. `no_isdark_test`, `No issues found!`.

- [ ] **Step 9: Commit**

```bash
git add lib test/no_isdark_test.dart
git commit -m "refactor: route all colors through the theme; no isDark branching in widgets"
```

---

### Task 4: Visual check + tag

- [ ] **Step 1:** `flutter run` (any device incl. `-d windows` or `-d edge`): compare Home/Calendar/Settings light+dark against the design tokens (surfaces `#E8EEF2`/`#39393A`, cards `#F6F8FA`/`#434345`, nav `#DCE4EA`/`#2E2E30`); Settings shows System/Light/Dark segmented; picking System follows OS.
- [ ] **Step 2:** `git tag phase-1-done`.

## Self-review

- Spec fase 1 items: `ColorScheme.fromSeed` (T2), `ThemeExtension` (T2), delete `isDark ? :` outside ThemeData (T3, guarded by test), `provider` instead of `ThemeProvider` (T1). Explicit "system" option (spec Settings → Aparência) (T1).
- Names consistent: `AppTokens.light/dark`, `qualityFor`, `flameTier`, `flameFor`, `context.tokens`, `saveThemeDark`, `setMode` used identically across tasks. `Utilities.activeColor` signature unchanged for its 4 callers.
- No placeholders.
