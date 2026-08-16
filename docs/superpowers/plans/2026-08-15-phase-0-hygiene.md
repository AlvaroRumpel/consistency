# Phase 0 — Hygiene Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove repo junk and fix the small, self-contained UX defects (theme default, immersive mode, fake splash delay, invisible errors, stale undo blob) without touching the data model.

**Architecture:** Every task is a local edit to an existing file plus one test. No new dependencies, no new abstractions except one tiny `ErrorView` widget reused by three pages. Data format on disk is unchanged (Phase 2 owns migration).

**Tech Stack:** Flutter 3.41 / Dart 3, `shared_preferences`, `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-08-15-consistency-v2-design.md` — section "Fases", row 0.

## Global Constraints

- Do not change the on-disk JSON shape of `userData` (array of JSON strings). Phase 2 migrates it.
- Do not add packages.
- Lints: `prefer_single_quotes`, `prefer_relative_imports` (see `analysis_options.yaml`). Run `flutter analyze` before each commit; must be clean.
- Tests: `LocalData` caches `SharedPreferences` in a static. `SharedPreferences.setMockInitialValues` only affects the **first** `LocalData.i` in a test file. Inside one file, reseed through `LocalData` setters (see `test/goal_history_test.dart:84-92`), or put the test in its own file.
- Commit after every task with a Conventional Commit subject.

---

### Task 1: Repo junk + pubspec metadata

**Files:**
- Move: `1024.png`, `play_store_512.png`, `consistency-banner.png` → `store/`
- Delete: `Flycricket-Screenshots.zip`
- Modify: `pubspec.yaml:1-2`, `pubspec.yaml:19` (`version`)
- Modify: `README.md` (add banner reference)

- [ ] **Step 1: Move store assets, delete zip**

```bash
mkdir -p store
git mv 1024.png store/icon-1024.png
git mv play_store_512.png store/play-store-512.png
git mv consistency-banner.png store/banner.png
git rm Flycricket-Screenshots.zip
```

- [ ] **Step 2: Fix pubspec header and bump version**

Replace lines 1-2 of `pubspec.yaml`:
```yaml
name: consistency
description: Daily habit tracker — mark your goals, keep your streak.
```
Replace the `version:` line:
```yaml
version: 0.1.0+4
```

- [ ] **Step 3: Reference banner in README**

Insert as the very first line of `README.md`:
```markdown
![Consistency](store/banner.png)

```

- [ ] **Step 4: Verify build still resolves**

Run: `flutter pub get && flutter analyze`
Expected: `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "chore: move store assets, drop screenshots zip, real pubspec metadata"
```

---

### Task 2: Theme defaults to system

**Files:**
- Modify: `lib/configs/local_data.dart:66-68` (`searchTheme`, `clearAllData`)
- Modify: `lib/configs/theme.dart:7-27` (`ThemeModel`)
- Modify: `lib/pages/settings_page.dart:129-131` (switch reads effective brightness)
- Test: `test/theme_mode_default_test.dart` (new)

**Interfaces:**
- Produces: `bool? LocalData.searchTheme()` — `null` when the user never chose. `ThemeModel.themeMode` starts as `ThemeMode.system`.

- [ ] **Step 1: Write the failing test**

`test/theme_mode_default_test.dart`:
```dart
import 'package:consistency/configs/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Own file on purpose: LocalData caches SharedPreferences in a static, so
// the empty seed below must be the first one this isolate sees.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('ThemeModel resolves to system when the user never picked a theme',
      () async {
    SharedPreferences.setMockInitialValues({});
    final model = ThemeModel();
    expect(model.themeMode, ThemeMode.system);
    // Let _load() finish; it must not flip system → light/dark on its own.
    for (var i = 0; i < 10; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(model.themeMode, ThemeMode.system);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/theme_mode_default_test.dart`
Expected: FAIL — `Expected: ThemeMode:<ThemeMode.system> Actual: ThemeMode:<ThemeMode.dark>`

- [ ] **Step 3: Make `searchTheme` nullable and keep `clearAllData` honest**

In `lib/configs/local_data.dart` replace:
```dart
  bool searchTheme() => _sharedPreferences?.getBool(_themeDark) ?? false;
```
with:
```dart
  /// null = user never chose; caller falls back to ThemeMode.system.
  bool? searchTheme() => _sharedPreferences?.getBool(_themeDark);
```
and in `clearAllData` replace:
```dart
    final theme = searchTheme();
    final recoveryModel = await _saveRecoveryData();
    await _sharedPreferences!.clear();
    await saveTheme(theme);
```
with:
```dart
    final theme = searchTheme();
    final recoveryModel = await _saveRecoveryData();
    await _sharedPreferences!.clear();
    if (theme != null) await saveTheme(theme);
```

- [ ] **Step 4: ThemeModel starts at system, loads tri-state**

In `lib/configs/theme.dart` replace the `ThemeModel` class with:
```dart
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

  Future<void> setDark(bool value) async {
    _themeMode = value ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
    final localData = await LocalData.i;
    await localData.saveTheme(value);
  }
}
```

- [ ] **Step 5: Settings switch reflects effective brightness**

In `lib/pages/settings_page.dart` replace:
```dart
                    final themeDark =
                        ThemeProvider.of(context).themeMode == ThemeMode.dark;
```
with:
```dart
                    // Effective brightness, so "system" shows the right side.
                    final themeDark =
                        Theme.of(context).brightness == Brightness.dark;
```
Keep `onChanged: ThemeProvider.of(context).setDark` as is (choosing on the switch pins light/dark; Phase 1 adds the explicit "system" option).

- [ ] **Step 6: Run all tests**

Run: `flutter test`
Expected: all PASS (existing `theme_tokens_test.dart` seeds `themeDark: true` and still resolves dark; `theme_tokens_light_test.dart` seeds `false` → light).

- [ ] **Step 7: Commit**

```bash
git add lib/configs/local_data.dart lib/configs/theme.dart lib/pages/settings_page.dart test/theme_mode_default_test.dart
git commit -m "fix: default theme follows the system"
```

---

### Task 3: Drop immersive mode; splash waits for storage, not a timer

**Files:**
- Modify: `lib/main.dart:1-12`
- Modify: `lib/pages/splash_page.dart:1-27`
- Modify: `test/theme_tokens_test.dart:33-41`, `test/theme_tokens_light_test.dart:14-21` (remove 1600ms pumps)
- Test: `test/splash_navigation_test.dart` (new)

- [ ] **Step 1: Write the failing test**

`test/splash_navigation_test.dart`:
```dart
import 'package:consistency/main.dart';
import 'package:consistency/pages/skeleton_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('splash navigates as soon as storage is ready, no fixed delay',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const ConsistencyApp());
    // A handful of frames — far less than the old 1500ms timer.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(find.byType(SkelentonPage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/splash_navigation_test.dart`
Expected: FAIL — `Expected: exactly one matching candidate Actual: _TypeWidgetFinder:<Found 0 widgets>` (and a pending-timer error from the 1500ms delay).

- [ ] **Step 3: Remove immersive mode**

`lib/main.dart` — delete `import 'package:flutter/services.dart';` and replace:
```dart
void main() {
  runApp(const ConsistencyApp());
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
}
```
with:
```dart
void main() {
  runApp(const ConsistencyApp());
}
```

- [ ] **Step 4: Splash waits for LocalData**

`lib/pages/splash_page.dart` — add `import '../configs/local_data.dart';` and replace `initState` with:
```dart
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Warm the storage singleton; that's the only thing worth waiting for.
      await LocalData.i;
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/manager', (_) => false);
      }
    });
  }
```

- [ ] **Step 5: Update the two smoke tests**

In `test/theme_tokens_test.dart` and `test/theme_tokens_light_test.dart` replace:
```dart
      await tester.pump();
      // Fires the splash screen's Future.delayed(1500ms) navigation timer
      // so it doesn't leak into the next pump/test as a pending timer.
      await tester.pump(const Duration(milliseconds: 1600));
      await tester.pump();
      await tester.pump();
```
with:
```dart
      await tester.pump();
      await tester.pump();
      await tester.pump();
```
(Indentation differs slightly between the two files; keep each file's.)

- [ ] **Step 6: Run all tests + analyze**

Run: `flutter test && flutter analyze`
Expected: all PASS, `No issues found!`

- [ ] **Step 7: Commit**

```bash
git add lib/main.dart lib/pages/splash_page.dart test/
git commit -m "fix: drop immersive mode; splash waits for storage instead of 1.5s"
```

---

### Task 4: Visible error state with retry on Home, Calendar, Settings

**Files:**
- Create: `lib/widgets/error_view.dart`
- Modify: `lib/controllers/home_controller.dart:70-74` (`_reload` → public `reload`)
- Modify: `lib/controllers/calendar_controller.dart:41-52` (`_reload` → public `reload`)
- Modify: `lib/controllers/settings_controller.dart:22-32` (add `reload`)
- Modify: `lib/pages/home_page.dart:143-147`
- Modify: `lib/pages/calendar_page.dart:60-63, 98-103`
- Modify: `lib/pages/settings_page.dart:78-84`
- Test: `test/error_view_test.dart` (new)

**Interfaces:**
- Produces: `ErrorView({required String message, required VoidCallback onRetry})`; `HomeController.reload()`, `CalendarController.reload()`, `SettingsController.reload()` — all `void`/`Future<void>`, idempotent, re-run the initial load.

- [ ] **Step 1: Write the failing test**

`test/error_view_test.dart`:
```dart
import 'package:consistency/widgets/error_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('ErrorView shows the message and fires onRetry', (tester) async {
    var retries = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ErrorView(message: 'boom', onRetry: () => retries++),
      ),
    ));
    expect(find.text('boom'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    expect(retries, 1);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/error_view_test.dart`
Expected: FAIL — `Error: Couldn't resolve the package 'consistency/widgets/error_view.dart'` (or "Target of URI doesn't exist").

- [ ] **Step 3: Create ErrorView**

`lib/widgets/error_view.dart`:
```dart
import 'package:flutter/material.dart';

import '../configs/colors.dart';
import '../configs/text_styles.dart';

class ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const ErrorView({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: AppColors.redColor, size: 40),
          const SizedBox(height: 8),
          Text(
            message,
            style: context.textStyles.normalText,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, color: AppColors.whiteColor),
            label: Text(
              'Try again',
              style: context.textStyles.normalText
                  .copyWith(color: AppColors.whiteColor),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/error_view_test.dart`
Expected: PASS

- [ ] **Step 5: Expose `reload` on the three controllers**

`lib/controllers/home_controller.dart` — rename `_reload` to `reload` (declaration and both `LocalData.revision.addListener/removeListener` call sites):
```dart
  void reload() => emitGuard(
        loadingState: HomeLoading(),
        newState: recoveryData,
        errorState: (e) => HomeError(message: e.toString()),
      );
```

`lib/controllers/calendar_controller.dart` — rename `_reload` to `reload` (declaration, `addListener`, `removeListener`):
```dart
  Future<void> reload() async {
    _userData
      ..clear()
      ..addAll(await _localData.searchUserData() ?? []);
    treatData();
  }
```

`lib/controllers/settings_controller.dart` — replace `onInit` with:
```dart
  @override
  void onInit() => reload();

  Future<void> reload() async {
    _localData = await LocalData.i;
    await emitGuard(
      loadingState: SettingLoading(),
      newState: (_) async =>
          SettingData(nickname: await _localData.searchNickname() ?? 'User'),
      errorState: (e) => SettingError(message: e.toString()),
    );
  }
```

- [ ] **Step 6: Wire ErrorView into the pages**

`lib/pages/home_page.dart` — add `import '../widgets/error_view.dart';` and replace:
```dart
                        HomeInitial() ||
                        HomeLoading() ||
                        HomeError() =>
                          const SizedBox.shrink(),
```
with:
```dart
                        HomeError(:final message) => ErrorView(
                            message: message,
                            onRetry: _controller.reload,
                          ),
                        HomeInitial() || HomeLoading() =>
                          const SizedBox.shrink(),
```

`lib/pages/calendar_page.dart` — add `import '../widgets/error_view.dart';`. In the first `ValueListenableBuilder` replace:
```dart
                    if (state is! CalendarData) {
                      return const Center(child: CircularProgressIndicator());
                    }
```
with:
```dart
                    if (state is CalendarError) {
                      return ErrorView(
                        message: state.message,
                        onRetry: _controller.reload,
                      );
                    }
                    if (state is! CalendarData) {
                      return const Center(child: CircularProgressIndicator());
                    }
```
In the second builder replace:
```dart
              if (state is! CalendarData) {
                return const SliverToBoxAdapter(
                  child: Center(child: CircularProgressIndicator()),
                );
              }
```
with:
```dart
              if (state is! CalendarData) {
                // Error is already shown by the calendar box above.
                return const SliverToBoxAdapter(child: SizedBox.shrink());
              }
```

`lib/pages/settings_page.dart` — add `import '../widgets/error_view.dart';`. Inside `SliverFillRemaining` → `Column(children: [` insert as the **first** child:
```dart
                ValueListenableBuilder(
                  valueListenable: _controller.stateNotifier,
                  builder: (context, value, _) => value is SettingError
                      ? ErrorView(
                          message: value.message,
                          onRetry: _controller.reload,
                        )
                      : const SizedBox.shrink(),
                ),
```

- [ ] **Step 7: Run all tests + analyze**

Run: `flutter test && flutter analyze`
Expected: all PASS, `No issues found!`

- [ ] **Step 8: Commit**

```bash
git add lib/widgets/error_view.dart lib/controllers lib/pages test/error_view_test.dart
git commit -m "feat: visible error state with retry on every page"
```

---

### Task 5: Undo blob is dropped after the next write

**Files:**
- Modify: `lib/configs/local_data.dart:36-46` (`saveNickname`, `saveUserData`)
- Test: `test/recovery_expiry_test.dart` (new)

- [ ] **Step 1: Write the failing test**

`test/recovery_expiry_test.dart`:
```dart
import 'package:consistency/configs/local_data.dart';
import 'package:consistency/models/date_goal_model.dart';
import 'package:consistency/models/goal_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a new save after clearAllData invalidates the undo snapshot', () async {
    SharedPreferences.setMockInitialValues({});
    final localData = await LocalData.i;
    await localData.saveNickname('Alvaro');
    await localData.saveUserData([
      DateGoalModel(
        date: DateTime(2026, 1, 1),
        goals: [GoalModel(name: 'Run', percentCompleted: 100)],
      ),
    ]);

    await localData.clearAllData();
    expect(await localData.searchUserData(), isNull);

    // User starts fresh: this write must make the old snapshot unrecoverable.
    await localData.saveUserData([
      DateGoalModel(
        date: DateTime(2026, 2, 2),
        goals: [GoalModel(name: 'Read', percentCompleted: 50)],
      ),
    ]);

    expect(await localData.undoRecoveryData(), isFalse);
    final data = await localData.searchUserData();
    expect(data!.single.goals.single.name, 'Read');
  });

  test('undo still works when nothing was written after the wipe', () async {
    final localData = await LocalData.i;
    await localData.saveNickname('Alvaro');
    await localData.saveUserData([
      DateGoalModel(
        date: DateTime(2026, 1, 1),
        goals: [GoalModel(name: 'Run', percentCompleted: 100)],
      ),
    ]);
    await localData.clearAllData();
    expect(await localData.undoRecoveryData(), isTrue);
    expect(await localData.searchNickname(), 'Alvaro');
    expect((await localData.searchUserData())!.single.goals.single.name, 'Run');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/recovery_expiry_test.dart`
Expected: first test FAIL — `Expected: false Actual: <true>`.

- [ ] **Step 3: Clear the snapshot on every user write**

In `lib/configs/local_data.dart` replace:
```dart
  Future<bool> saveNickname(String nickname) =>
      _sharedPreferences!.setString(_nickname, nickname);
```
with:
```dart
  Future<bool> saveNickname(String nickname) async {
    await _forgetRecovery();
    return _sharedPreferences!.setString(_nickname, nickname);
  }
```
and replace:
```dart
  Future<bool> saveUserData(List<DateGoalModel> goalsModel) =>
      _sharedPreferences!.setString(_userData, jsonEncode(goalsModel));
```
with:
```dart
  Future<bool> saveUserData(List<DateGoalModel> goalsModel) async {
    await _forgetRecovery();
    return _sharedPreferences!.setString(_userData, jsonEncode(goalsModel));
  }

  /// The wipe snapshot only makes sense until the user writes something new;
  /// after that, undo would silently overwrite fresh data.
  Future<void> _forgetRecovery() async {
    await _sharedPreferences!.remove(_recoveryData);
  }
```

`undoRecoveryData` itself calls `saveNickname`/`saveUserData`, so a successful undo also consumes the snapshot — that is intended (undo is one-shot). It reads the snapshot into `recoveryModel` **before** calling them, so nothing is lost.

- [ ] **Step 4: Run all tests + analyze**

Run: `flutter test && flutter analyze`
Expected: all PASS (`goal_history_test.dart` covers wipe → undo → reload; still valid), `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add lib/configs/local_data.dart test/recovery_expiry_test.dart
git commit -m "fix: forget the wipe snapshot after the next write"
```

---

### Task 6: Manual smoke on device + tag

- [ ] **Step 1: Run on a device/emulator**

Run: `flutter run`
Check: status bar visible; splash goes straight to Home; theme follows system when nothing chosen; Settings switch matches actual brightness; "Delete all data" → undo works; delete → add goal → save → undo snackbar tap does nothing destructive.

- [ ] **Step 2: Tag**

```bash
git tag phase-0-done
```

---

## Self-review

- Spec row 0 items: `.gitignore` build/ — already ignored (verified), nothing to do; `.iml`/zip/PNGs — Task 1; pubspec — Task 1; `ThemeMode.system` — Task 2; `immersiveSticky` — Task 3; splash — Task 3; error state ×3 — Task 4; `beforeDelete` — Task 5. Covered.
- Names: `reload` used consistently in Task 4 controllers and pages. `searchTheme` nullable in Task 2, consumed only by `ThemeModel` and `clearAllData` (both updated).
- No placeholders.
