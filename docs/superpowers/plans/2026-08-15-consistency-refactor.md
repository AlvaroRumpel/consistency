# Consistency Refactor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix nine correctness bugs in the Consistency habit tracker and cut ~350 lines of dead/duplicated code, without changing the on-disk data format.

**Architecture:** The app is a Flutter habit tracker with three pages inside a `PageView` (Calendar / Home / Settings). Each page owns a controller extending `BaseController<State>`, a hand-rolled `ValueNotifier`-based store with sealed state classes. Persistence is a `LocalData` singleton over `SharedPreferences`. This refactor keeps that architecture and changes four things: sealed-state dispatch moves from hand-rolled `when`/`whenNull` methods to Dart 3 `switch` expressions; `GoalModel` instances stop being shared between the live UI state and the persisted history; light/dark branching moves from ~15 inline `ThemeProvider` ternaries into `ThemeData` tokens; and the theme gets a single source of truth (`ThemeModel`) instead of two.

**Tech Stack:** Flutter (Dart 3, SDK `>=3.0.0`), `shared_preferences`, `flutter_calendar_carousel`, `top_snackbar_flutter`, `url_launcher`, `flutter_test`.

**Spec:** This plan is its own spec — it derives from the repo-wide audit recorded in the session that produced it. Every requirement is restated inline below; there is no separate spec document to read.

## Global Constraints

- **Do not change the on-disk `SharedPreferences` format.** Installed users have data. Specifically: `saveUserData` calls `jsonEncode` on a `List<DateGoalModel>`, which invokes `DateGoalModel.toJson()` per element, which returns a **String**. The stored value is therefore a JSON array of JSON *strings*, and `searchUserData` decodes it with `DateGoalModel.fromJson(String)`. `DateGoalModel.toJson`/`fromJson` are load-bearing — never delete them.
- **Keys must not change:** `nickname`, `userData`, `themeDark`, `beforeDelete`.
- Dart SDK floor is `>=3.0.0` — sealed classes, records, and switch expressions are available; `switch` *expressions* over sealed types are exhaustiveness-checked by the compiler.
- Subclass ordering matters in switch expressions: `HomeDataEmpty extends HomeData`, so the `HomeDataEmpty` case MUST come before the `HomeData` case or it is unreachable. The analyzer reports unreachable cases as a warning, not an error — check the analyzer output, do not assume.
- Every task ends with `flutter analyze` reporting **zero** issues except the one pre-existing info: `avoid_types_as_parameter_names` at `lib/controllers/base_controller.dart:6:31`. Do not fix that one — it is out of scope and touching `BaseController`'s type parameter renames every subclass.
- Run commands from the repo root `f:\_geral\Projetos\consistency`.
- Commit at the end of each task. Do not push.

---

## File Structure

| File | Responsibility after this plan |
|---|---|
| `lib/models/goal_model.dart` | Mutable goal (name + percent). Owns `copyWith`, `toMap`, `fromMap`. `toJson`/`fromJson` deleted (unused). |
| `lib/models/date_goal_model.dart` | One day's snapshot. Keeps `toJson`/`fromJson` — load-bearing for the storage format. |
| `lib/models/recovery_model.dart` | Unchanged. |
| `lib/configs/local_data.dart` | `SharedPreferences` access. Loses 8 try/catch blocks. Gains a `revision` notifier for cross-page invalidation. |
| `lib/configs/exceptions/local_data_exception.dart` | **Deleted** — thrown 9×, caught 0×, never displayed. |
| `lib/configs/theme.dart` | `ThemeModel` (single source of truth for theme, persists itself) + `themeDark`/`themeLight` `ThemeData` with `cardColor`/`iconTheme` tokens. |
| `lib/configs/text_styles.dart` | Immutable `TextStyles` built per-call from `Theme.of(context).brightness`. No global mutable `_isDark`. |
| `lib/configs/messages_mixin.dart` | Loses dead `showError`. |
| `lib/configs/utilities.dart` | `activeColor` shrunk. |
| `lib/controllers/base_controller.dart` | Unchanged. |
| `lib/controllers/home_controller.dart` | Sealed states without `when`/`whenNull`/`HomeDataLoading`. Deep-copies goals. Owns `TextEditingController` lifecycle. |
| `lib/controllers/calendar_controller.dart` | Sealed states without `when`/`whenNull`. Guards casts and division by zero. Reloads on `LocalData.revision`. |
| `lib/controllers/settings_controller.dart` | Loses `themeDark` from state and `changeTheme` entirely. Guards casts. |
| `lib/providers/theme_provider.dart` | `of()` asserts instead of silently minting a new `ThemeModel`. |
| `lib/widgets/switch_tile_custom.dart` | **Deleted** — empty file, zero references. |
| `lib/widgets/list_tile_custom.dart` | Loses unused `bottom` param; radius shrunk; reads theme tokens. |
| `lib/widgets/*`, `lib/pages/*` | Ternaries replaced with `Theme.of(context)` tokens. |
| `test/goal_history_test.dart` | **Created** — the one runnable check for the history-corruption fix. |
| `test/widget_test.dart` | **Deleted** — Flutter counter template, currently failing. |

---

### Task 1: Delete dead code

Pure deletion. Nothing in this task changes behavior; if a test or the analyzer disagrees, something listed here was not actually dead — stop and report rather than "fixing" it.

**Files:**
- Delete: `lib/widgets/switch_tile_custom.dart`
- Delete: `lib/configs/exceptions/local_data_exception.dart`
- Modify: `lib/configs/local_data.dart` (remove all try/catch + the exception import)
- Modify: `lib/models/goal_model.dart:26-29` (remove `toJson`/`fromJson`)
- Modify: `lib/configs/messages_mixin.dart:9-28` (remove `showError`)
- Modify: `lib/configs/utilities.dart:6-20`
- Modify: `lib/widgets/list_tile_custom.dart`
- Modify: `lib/pages/settings_page.dart:94` (drop the now-removed `top:`/`bottom:` usage — see step 7)

**Interfaces:**
- Consumes: nothing.
- Produces: `LocalData` methods keep their exact existing signatures — `Future<bool> saveNickname(String)`, `Future<String?> searchNickname()`, `Future<bool> saveUserData(List<DateGoalModel>)`, `Future<List<DateGoalModel>?> searchUserData()`, `Future<bool> saveTheme(bool)`, `bool searchTheme()`, `Future<bool> undoRecoveryData()`, `Future<void> clearAllData()`. Only the bodies shrink. `ListTileCustom({required String title, bool top = false, required VoidCallback onTap})` — the `bottom` parameter is gone.

- [ ] **Step 1: Verify the dead code really is dead**

Run each of these. Every one must print nothing (or only the definition site).

```bash
grep -rn "SwitchTileCustom" lib/
grep -rn "LocalDataException\|LocalDataErrorType" lib/ --include=*.dart | grep -v "exceptions/local_data_exception.dart"
grep -rn "GoalModel.fromJson\|showError\|bottom: true" lib/
```

Expected: the second command prints only lines inside `lib/configs/local_data.dart` (the `throw` sites, which this task removes); the first and third print nothing.

- [ ] **Step 2: Delete the two dead files**

```bash
git rm lib/widgets/switch_tile_custom.dart lib/configs/exceptions/local_data_exception.dart
```

- [ ] **Step 3: Strip the try/catch layer out of `local_data.dart`**

The exception carried a user-facing `message`, but no page ever rendered it — controllers store `e.toString()` in an error state that no widget reads. Errors still surface: `BaseController.emitGuard` catches `Object`, logs with a stack trace, and emits the error state. Replace the whole file with this:

```dart
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/date_goal_model.dart';
import '../models/recovery_model.dart';

class LocalData {
  final String _nickname = 'nickname';
  final String _userData = 'userData';
  final String _themeDark = 'themeDark';
  final String _recoveryData = 'beforeDelete';

  static SharedPreferences? _sharedPreferences;

  static LocalData? _instance;

  LocalData._();
  static Future<LocalData> get i async {
    await _initSharedPreferences();
    return _instance ??= LocalData._();
  }

  static Future<void> _initSharedPreferences() async {
    _sharedPreferences ??= await SharedPreferences.getInstance();
  }

  Future<bool> saveNickname(String nickname) =>
      _sharedPreferences!.setString(_nickname, nickname);

  Future<String?> searchNickname() async =>
      _sharedPreferences!.getString(_nickname);

  // jsonEncode calls DateGoalModel.toJson() per element, which itself returns a
  // JSON String — so the stored value is an array of JSON strings. searchUserData
  // mirrors that. Changing it breaks every installed app's saved history.
  Future<bool> saveUserData(List<DateGoalModel> goalsModel) =>
      _sharedPreferences!.setString(_userData, jsonEncode(goalsModel));

  Future<List<DateGoalModel>?> searchUserData() async {
    final userDataJson = _sharedPreferences!.getString(_userData);
    if (userDataJson == null) return null;

    return [
      for (final data in jsonDecode(userDataJson) as List)
        DateGoalModel.fromJson(data as String),
    ];
  }

  Future<bool> saveTheme(bool value) =>
      _sharedPreferences!.setBool(_themeDark, value);

  bool searchTheme() => _sharedPreferences?.getBool(_themeDark) ?? false;

  Future<RecoveryModel> _saveRecoveryData() async => RecoveryModel(
        nickname: await searchNickname(),
        userData: await searchUserData(),
      );

  Future<bool> undoRecoveryData() async {
    final recoveryModelString = _sharedPreferences!.getString(_recoveryData);
    if (recoveryModelString == null || recoveryModelString.isEmpty) {
      return false;
    }

    final recoveryModel = RecoveryModel.fromJson(recoveryModelString);

    if (recoveryModel.nickname != null) {
      await saveNickname(recoveryModel.nickname!);
    }
    if (recoveryModel.userData != null) {
      await saveUserData(recoveryModel.userData!);
    }

    return true;
  }

  Future<void> clearAllData() async {
    final theme = searchTheme();
    final recoveryModel = await _saveRecoveryData();
    await _sharedPreferences!.clear();
    await saveTheme(theme);
    await _sharedPreferences!.setString(_recoveryData, recoveryModel.toJson());
  }
}
```

- [ ] **Step 4: Remove `GoalModel.toJson`/`fromJson`**

In `lib/models/goal_model.dart`, delete these two members and the now-unused `dart:convert` import:

```dart
  String toJson() => json.encode(toMap());

  factory GoalModel.fromJson(String source) =>
      GoalModel.fromMap(json.decode(source));
```

Keep `toMap`, `fromMap`, and `copyWith` — `toMap` is called by `DateGoalModel.toMap`, and `copyWith` is required by Task 3.

- [ ] **Step 5: Remove the dead `showError`**

In `lib/configs/messages_mixin.dart`, delete the entire `showError` method (lines 9-28). Keep `showMessageUndo`. After the deletion the `AppColors.redColor` reference is gone; check whether the `colors.dart` import is still needed (it is — `showMessageUndo` uses `AppColors.primaryColor` and `AppColors.whiteColor`).

- [ ] **Step 6: Shrink `Utilities.activeColor`**

Each `if` already returned, so the lower bound in every subsequent condition is dead. Replace the body of `lib/configs/utilities.dart`:

```dart
import 'package:flutter/material.dart';

import 'colors.dart';

class Utilities {
  static Color activeColor(double value) {
    if (value < 25.0) return AppColors.redColor.shade900;
    if (value < 50.0) return AppColors.redColor;
    if (value < 75.0) return AppColors.redColor.shade50;
    if (value <= 82.0) return AppColors.primaryColor;
    return AppColors.greenColor;
  }
}
```

Note the original returns `greenColor` for `NaN` (every comparison is false). That behavior is preserved here and the NaN *source* is fixed in Task 4 — do not add a NaN guard here.

- [ ] **Step 7: Drop `ListTileCustom.bottom` and shrink the radius**

`bottom` is never passed as `true` anywhere, so `bottom ? … : …` is always the false branch and `Visibility(visible: !bottom)` is always visible. Replace `lib/widgets/list_tile_custom.dart` with:

```dart
import 'package:flutter/material.dart';

import '../configs/colors.dart';
import '../configs/text_styles.dart';
import '../providers/theme_provider.dart';

class ListTileCustom extends StatelessWidget {
  final String title;
  final bool top;
  final VoidCallback onTap;

  const ListTileCustom({
    super.key,
    required this.title,
    this.top = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeProvider.of(context).themeMode == ThemeMode.dark;

    return Column(
      children: [
        Ink(
          child: InkWell(
            onTap: onTap,
            splashColor: AppColors.primaryColor.shade50,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(top ? 16 : 0),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 8.0,
                vertical: 4,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Flexible(
                    child: Text(
                      title,
                      style: context.textStyles.normalText,
                      textAlign: TextAlign.end,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.arrow_forward_ios,
                    color:
                        isDark ? AppColors.whiteColor : AppColors.blackColor,
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [AppColors.blackColor, AppColors.blackColor.shade200]
                  : [AppColors.whiteColor.shade700, AppColors.blackColor.shade50],
            ),
          ),
          height: 2,
        ),
      ],
    );
  }
}
```

The `ThemeProvider` ternaries stay for now — Task 6 replaces them wholesale.

- [ ] **Step 8: Verify**

Run: `flutter analyze`
Expected: `1 issue found` — only `avoid_types_as_parameter_names` at `base_controller.dart:6:31`. Any other issue means something deleted here was not dead; stop and report which.

- [ ] **Step 9: Commit**

```bash
git add -A
git commit -m "refactor: delete dead code

Removes an empty widget file, an exception type that was thrown nine times
and caught zero, GoalModel JSON helpers with no callers, a dead showError,
and a ListTileCustom flag never set to true. Shrinks activeColor's
redundant lower bounds and the four-ternary border radius.

The eight try/catch blocks in LocalData rethrew as LocalDataException
carrying a user-facing message that no widget ever rendered;
BaseController.emitGuard already catches Object, logs with a stack trace,
and emits the error state."
```

---

### Task 2: Replace hand-rolled union dispatch with switch expressions

`HomeState.when`/`CalendarState.when` have zero callers. `whenNull` reimplements, at runtime and unchecked, what Dart 3 gives you at compile time over a sealed hierarchy. `HomeDataLoading` and `SettingDataLoading` are emitted but no UI branch distinguishes them from their parents.

**Files:**
- Modify: `lib/controllers/home_controller.dart:10-96` (state classes)
- Modify: `lib/controllers/calendar_controller.dart:10-63` (state classes)
- Modify: `lib/controllers/settings_controller.dart:21-23` (drop `SettingDataLoading`)
- Modify: `lib/pages/home_page.dart:52-69, 120-148`
- Modify: `lib/pages/calendar_page.dart:63-105, 114-156`

**Interfaces:**
- Consumes: nothing from Task 1 beyond a green analyzer.
- Produces: the state hierarchies later tasks build on —
  - `sealed class HomeState`; `HomeInitial`, `HomeLoading`, `HomeError({required String message})`, `HomeData({required String nickname, required List<GoalModel> goals, required bool hasMarkedToday})`, `HomeDataEmpty({required String nickname, bool hasMarkedToday = false})` (extends `HomeData` with `goals: []`).
  - `sealed class CalendarState`; `CalendarLoading`, `CalendarError({required String message})`, `CalendarData({required EventList<Event> eventList, required DateGoalModel? selectedDaysGoals, required DateTime selectedDay})`.
  - `sealed class SettingState`; `SettingLoading`, `SettingError({required String message})`, `SettingData({required String nickname, required bool themeDark})`. (`themeDark` survives this task and is removed in Task 5.)

- [ ] **Step 1: Replace the `HomeState` hierarchy**

In `lib/controllers/home_controller.dart`, delete everything from `sealed class HomeState {` through the closing brace of `class HomeError` (lines 10-96) and put this in its place:

```dart
sealed class HomeState {}

class HomeInitial extends HomeState {}

class HomeLoading extends HomeState {}

class HomeError extends HomeState {
  final String message;

  HomeError({required this.message});
}

class HomeData extends HomeState {
  final String nickname;
  final List<GoalModel> goals;
  final bool hasMarkedToday;

  HomeData({
    required this.nickname,
    required this.goals,
    required this.hasMarkedToday,
  });
}

class HomeDataEmpty extends HomeData {
  HomeDataEmpty({required super.nickname, super.hasMarkedToday = false})
      : super(goals: []);
}
```

- [ ] **Step 2: Replace `HomeDataLoading` emissions**

`HomeDataLoading` no longer exists. Three call sites emitted it as a transient state that rendered identically to `HomeData`:

- `saveData()` — replace `emit(HomeDataLoading(...))` with nothing; delete the emit. Task 3 rewrites this method anyway.
- `addNewGoal()` — delete the leading `emit(HomeDataLoading(...))`. It emitted and then synchronously emitted the real state on the next lines; the intermediate value never reached a frame.
- `removeGoal()` — same, delete the leading emit.

- [ ] **Step 3: Replace the `CalendarState` hierarchy**

In `lib/controllers/calendar_controller.dart`, delete lines 10-63 (the `sealed class CalendarState` block with `when`/`whenNull`, plus the three subclasses) and put this in its place:

```dart
sealed class CalendarState {}

class CalendarLoading extends CalendarState {}

class CalendarData extends CalendarState {
  final EventList<Event> eventList;
  final DateGoalModel? selectedDaysGoals;
  final DateTime selectedDay;

  CalendarData({
    required this.eventList,
    required this.selectedDaysGoals,
    required this.selectedDay,
  });
}

class CalendarError extends CalendarState {
  final String message;

  CalendarError({required this.message});
}
```

- [ ] **Step 4: Drop `SettingDataLoading`**

In `lib/controllers/settings_controller.dart`, delete:

```dart
class SettingDataLoading extends SettingData {
  SettingDataLoading({required super.nickname, required super.themeDark});
}
```

Then replace every `SettingDataLoading(` constructor call in that file with `SettingData(` — there are four (in `clearAllData`, `undoClearAllData`, `saveNickname`, `changeTheme`). Nothing reads them differently.

- [ ] **Step 5: Convert `home_page.dart` to switch expressions**

Two `whenNull` call sites. First, the greeting at lines 52-69 — replace the whole `return value.whenNull(...)` with:

```dart
                        final nickname =
                            value is HomeData ? value.nickname : 'user';
                        return Text(
                          '$nickname?',
                          style: context.textStyles.normalText.copyWith(
                            fontSize: 32,
                            color: AppColors.primaryColor,
                          ),
                        );
```

(The original duplicated an identical `Text` in both branches purely to swap the string. This is not a switch because there are only two outcomes and one differs by a single value.)

Second, the goals list at lines 120-148 — replace the whole `return state.whenNull(...)` with a switch expression. **`HomeDataEmpty` must come first**, since it extends `HomeData`:

```dart
                      return switch (state) {
                        HomeDataEmpty() => IconButton(
                            onPressed: _controller.addNewGoal,
                            style: IconButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(100),
                                side: const BorderSide(
                                  color: AppColors.primaryColor,
                                  width: 2,
                                ),
                              ),
                            ),
                            icon: const Icon(
                              Icons.add,
                              color: AppColors.primaryColor,
                            ),
                          ),
                        HomeData(:final goals, :final hasMarkedToday) =>
                          GoalsListView(
                            goals: goals,
                            textControllers: _controller.goalsControllers,
                            hasMarkedToday: hasMarkedToday,
                            onRemove: _controller.removeGoal,
                            onAdd: _controller.addNewGoal,
                          ),
                        HomeInitial() ||
                        HomeLoading() ||
                        HomeError() =>
                          const SizedBox.shrink(),
                      };
```

- [ ] **Step 6: Convert `calendar_page.dart` to switch expressions**

Two `whenNull` call sites. The calendar body at lines 63-105 — replace `return state.whenNull(orElse: ..., data: ...)` with:

```dart
                    if (state is! CalendarData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    return CalendarCarousel(
```

...keeping the entire existing `CalendarCarousel(...)` argument list unchanged, but replacing the two references to `data.` with `state.` (`data.eventList` → `state.eventList`, `data.selectedDay` → `state.selectedDay`). Close with `);` instead of the old `),` + `);`.

The goals-done sliver at lines 114-156 — replace `return state.whenNull(orElse: ..., data: ...)` with:

```dart
              if (state is! CalendarData) {
                return const SliverToBoxAdapter(
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final value = state.selectedDaysGoals;
              return SliverVisibility(
```

...keeping the entire existing `SliverVisibility(...)` body unchanged, and closing with `);`.

(An `if`/early-return beats a switch here: there are exactly two outcomes — data or a spinner — and the data branch is 40 lines long. A switch expression would need those 40 lines inline in a case arm.)

- [ ] **Step 7: Verify**

Run: `flutter analyze`
Expected: `1 issue found` — only the pre-existing `avoid_types_as_parameter_names`. In particular there must be **no** `unreachable_switch_case` warning; if there is, `HomeData` was placed before `HomeDataEmpty` in Step 5.

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "refactor: use sealed-class switch instead of hand-rolled dispatch

when() had zero callers. whenNull() reimplemented at runtime, unchecked,
what Dart 3 switch expressions verify at compile time. HomeDataLoading and
SettingDataLoading were emitted but no UI branch treated them differently
from their parent states."
```

---

### Task 3: Stop the history from being rewritten

The bug: `recoveryData()` builds the live goal list with `[...userGoals.last.goals]`, which copies the *list* but shares the `GoalModel` *instances* with `userData.last.goals`. `GoalsListView`'s slider then mutates `goals[index].percentCompleted` in place, and `saveData()` writes `goals[i].name` in place — both reach into yesterday's persisted record. `saveData()` then appends a new `DateGoalModel` holding those same shared instances, so the two days are permanently aliased until the next app launch re-decodes them.

Three more defects live in the same method and are fixed here because they share a call path:
- `hasMarkedToday` is assigned the return value of `saveUserData`, which is `SharedPreferences.setString`'s success flag, not a statement about today.
- `saveData()` has no re-entrancy guard; the only check is in `home_page.dart`, and it does not hold across the `await`.
- `setGoalsControllers` clears and rebuilds every `TextEditingController` from `goal.name`, discarding text the user typed but has not saved, and no controller is ever disposed.

`completePercent` is also a hardcoded `100.0` that is never assigned, so `Utilities.activeColor` always returns green for the button splash. It becomes a getter.

**Files:**
- Modify: `lib/controllers/home_controller.dart` (the `HomeController` class body)
- Create: `test/goal_history_test.dart`

**Interfaces:**
- Consumes: `HomeData`/`HomeDataEmpty` from Task 2; `GoalModel.copyWith({String? name, double? percentCompleted})` from `lib/models/goal_model.dart` (already exists, previously unused).
- Produces: `HomeController` public surface used by `home_page.dart` — `stateNotifier`, `double get completePercent`, `List<TextEditingController> goalsControllers`, `Future<void> saveData()`, `void addNewGoal()`, `void removeGoal(int index)`, `void onDispose()`. `recoveryData` stays `Future<HomeState> recoveryData([HomeState? oldState])` because `emitGuard` passes the old state positionally.

- [ ] **Step 1: Write the failing test**

This is the one runnable check for this task. It drives the real `HomeController` against a mocked `SharedPreferences`, so it exercises production code rather than a re-implementation of it. `SharedPreferences.setMockInitialValues` ships with the `shared_preferences` package — no new dependency.

Note the two statics `LocalData._sharedPreferences` and `LocalData._instance` are process-global and survive between tests in a file. `setMockInitialValues` must therefore run in `setUp` **before** the first `LocalData.i`, and the seeded value must be the storage format Task 1 documented: a JSON array of JSON **strings**.

Create `test/goal_history_test.dart`:

```dart
import 'package:consistency/controllers/home_controller.dart';
import 'package:consistency/models/date_goal_model.dart';
import 'package:consistency/models/goal_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One saved day, in the on-disk shape: an array of JSON strings.
String seededUserData() {
  final yesterday = DateGoalModel(
    date: DateTime(2026, 1, 1),
    goals: [GoalModel(name: 'Run', percentCompleted: 50)],
  );
  return '[${jsonEncode(yesterday.toJson())}]';
}

/// Spins the microtask queue until the controller's async onInit has settled.
Future<void> settle(HomeController controller) async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(Duration.zero);
    if (controller.state is HomeData) return;
  }
  fail('controller never reached HomeData; state was ${controller.state}');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'nickname': 'Alvaro',
      'userData': seededUserData(),
    });
  });

  test('editing today does not rewrite the saved day', () async {
    final controller = HomeController();
    await settle(controller);

    final live = (controller.state as HomeData).goals;
    expect(live.single.name, 'Run');

    // The user drags the slider and renames the goal.
    live.single.percentCompleted = 100;
    live.single.name = 'Sprint';

    final saved = controller.userData.single.goals.single;
    expect(saved.percentCompleted, 50, reason: 'history was rewritten');
    expect(saved.name, 'Run', reason: 'history was rewritten');

    controller.onDispose();
  });

  test('copyWith produces an independent instance', () {
    final original = GoalModel(name: 'Read', percentCompleted: 25);
    final copy = original.copyWith();

    copy.percentCompleted = 75;

    expect(original.percentCompleted, 25);
    expect(identical(original, copy), isFalse);
  });
}
```

Add `import 'dart:convert';` at the top for `jsonEncode`.

- [ ] **Step 2: Run the test and watch it fail against the current code**

Run: `flutter test test/goal_history_test.dart`
Expected: **FAIL** on `editing today does not rewrite the saved day` — `Expected: <50> Actual: <100>`, with the reason `history was rewritten`. This is the bug, reproduced. The second test passes already (`copyWith` is correct; it was simply never called).

If instead the first test fails inside `settle` with "controller never reached HomeData", the mock seeding is wrong — check that `userData` is an array of JSON *strings*, not an array of objects.

- [ ] **Step 3: (folded into Step 4 — the fix makes it pass)**

No separate action. Proceed to Step 4 and re-run in Step 6.

- [ ] **Step 4: Rewrite the `HomeController` class body**

Replace everything from `class HomeController extends BaseController<HomeState> {` to the end of the file with:

```dart
class HomeController extends BaseController<HomeState> {
  late LocalData localData;
  List<TextEditingController> goalsControllers = <TextEditingController>[];
  final userData = <DateGoalModel>[];

  HomeController() : super(HomeInitial());

  /// Average completion of the goals currently on screen. Drives the splash
  /// colour of the mark-today button.
  double get completePercent {
    final current = state;
    if (current is! HomeData || current.goals.isEmpty) return 100;
    return current.goals
            .map((goal) => goal.percentCompleted)
            .reduce((a, b) => a + b) /
        current.goals.length;
  }

  static DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  @override
  void onInit() async {
    localData = await LocalData.i;
    emitGuard(
      loadingState: HomeLoading(),
      newState: recoveryData,
      errorState: (e) => HomeError(message: e.toString()),
    );
  }

  Future<HomeState> recoveryData([HomeState? oldState]) async {
    final nickname = await localData.searchNickname() ?? 'User';
    final userGoals = await localData.searchUserData();

    userData
      ..clear()
      ..addAll(userGoals ?? []);

    if (userGoals == null || userGoals.isEmpty) {
      return HomeDataEmpty(nickname: nickname);
    }

    final hasMarkedToday = userGoals.any((item) => item.date == _today);

    // Deep copy: the sliders mutate these objects in place, and userData holds
    // the persisted history. Sharing instances lets today's edits rewrite
    // yesterday's record.
    final goals =
        userGoals.last.goals.map((goal) => goal.copyWith()).toList();

    setGoalsControllers(goals);

    return goals.isNotEmpty
        ? HomeData(
            nickname: nickname,
            goals: goals,
            hasMarkedToday: hasMarkedToday,
          )
        : HomeDataEmpty(nickname: nickname);
  }

  void setGoalsControllers(List<GoalModel>? goals) {
    if (goals == null) return;

    for (final controller in goalsControllers) {
      controller.dispose();
    }
    goalsControllers = [
      for (final goal in goals) TextEditingController(text: goal.name),
    ];
  }

  Future<void> saveData() async {
    final current = state;
    if (current is! HomeData ||
        current.hasMarkedToday ||
        current.goals.isEmpty) {
      return;
    }

    // Snapshot, so later slider drags and renames cannot reach the history.
    final snapshot = [
      for (var i = 0; i < current.goals.length; i++)
        current.goals[i].copyWith(name: goalsControllers[i].text),
    ];

    for (var i = 0; i < current.goals.length; i++) {
      current.goals[i].name = goalsControllers[i].text;
    }

    userData.add(DateGoalModel(date: _today, goals: snapshot));
    await localData.saveUserData(userData);

    emit(
      HomeData(
        nickname: current.nickname,
        goals: current.goals,
        hasMarkedToday: true,
      ),
    );
  }

  void addNewGoal() {
    final current = state;
    if (current is! HomeData) return;

    // Read the live text back before rebuilding, so in-progress typing on the
    // other rows survives.
    for (var i = 0; i < current.goals.length; i++) {
      current.goals[i].name = goalsControllers[i].text;
    }

    final goals = [
      ...current.goals,
      GoalModel(name: 'New Goal', percentCompleted: 0),
    ];

    goalsControllers.add(TextEditingController(text: 'New Goal'));

    emit(
      HomeData(
        nickname: current.nickname,
        goals: goals,
        hasMarkedToday: current.hasMarkedToday,
      ),
    );
  }

  void removeGoal(int index) {
    final current = state;
    if (current is! HomeData || current.hasMarkedToday) return;

    final goals = [...current.goals]..removeAt(index);
    goalsControllers.removeAt(index).dispose();

    emit(
      goals.isNotEmpty
          ? HomeData(
              nickname: current.nickname,
              goals: goals,
              hasMarkedToday: current.hasMarkedToday,
            )
          : HomeDataEmpty(
              nickname: current.nickname,
              hasMarkedToday: current.hasMarkedToday,
            ),
    );
  }

  @override
  void onDispose() {
    for (final controller in goalsControllers) {
      controller.dispose();
    }
    goalsControllers = [];
    super.onDispose();
  }
}
```

Note `addNewGoal` appends one controller instead of calling `setGoalsControllers`, which would dispose and rebuild every controller from `goal.name` and lose unsaved typing. `removeGoal` now disposes the one it drops. `onDispose` disposes the rest.

- [ ] **Step 5: Remove the now-dead `completePercent` field**

The old `double completePercent = 100.0;` field is gone from the replacement in Step 4 — confirm no other file assigns it:

Run: `grep -rn "completePercent" lib/`
Expected: the getter in `home_controller.dart`, `GoalModel.percentCompleted` references, and the read in `home_page.dart:83`. No assignment to `_controller.completePercent`.

- [ ] **Step 6: Verify**

Run: `flutter analyze && flutter test test/goal_history_test.dart`
Expected: analyze reports only the pre-existing info; both tests PASS.

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "fix: stop today's edits from rewriting saved history

recoveryData copied the goal list but shared the GoalModel instances with
userData.last.goals, so the slider and the rename both mutated the
already-persisted day in place, and saveData appended a new entry holding
those same instances. Both the load and the save now deep-copy via
copyWith.

Also in the same call path: hasMarkedToday was being assigned
SharedPreferences.setString's success flag rather than a fact about today;
saveData had no re-entrancy guard across its await; addNewGoal rebuilt
every TextEditingController from goal.name and discarded unsaved typing;
and no controller was ever disposed. completePercent was a const 100 that
nothing assigned, so the button splash was always green."
```

---

### Task 4: Guard the unchecked casts and the division by zero

`settings_controller.dart` casts `state as SettingData` in four methods, but the page constructs the controller with `SettingLoading()` and `onInit` is `async` — a tap landing before the load completes throws `TypeError`. `calendar_controller.selectDay` and the old `home_controller` methods had the same shape (Task 3 already fixed Home). `calendar_controller.treatData` divides by `item.goals.length` without checking for zero, producing `NaN`, which falls through every comparison in `Utilities.activeColor` and paints an empty day green.

**Files:**
- Modify: `lib/controllers/settings_controller.dart` (four methods)
- Modify: `lib/controllers/calendar_controller.dart:78-140`

**Interfaces:**
- Consumes: the state hierarchies from Task 2.
- Produces: no signature changes. `SettingsController.clearAllData()`, `undoClearAllData()`, `saveNickname(String?)`, `changeTheme(bool)` keep their return types; they now return early instead of throwing when the state is not `SettingData`.

- [ ] **Step 1: Guard the `SettingsController` casts**

In `lib/controllers/settings_controller.dart`, replace each of the four `final newState = state as SettingData;` lines with a guarded read. `clearAllData`:

```dart
  Future<void> clearAllData() async {
    final current = state;
    if (current is! SettingData) return;

    emitGuard(
      loadingState: SettingData(
        nickname: current.nickname,
        themeDark: current.themeDark,
      ),
      newState: (_) async {
        await _localData.clearAllData();
        return SettingData(nickname: 'User', themeDark: current.themeDark);
      },
      errorState: (e) => SettingError(message: e.toString()),
    );
  }
```

`undoClearAllData` — note it returns `bool`, so the guard returns `false`:

```dart
  Future<bool> undoClearAllData() async {
    final current = state;
    if (current is! SettingData) return false;

    var success = await _localData.undoRecoveryData();

    if (success) {
      final nickname = await _localData.searchNickname() ?? 'User';
      emit(SettingData(nickname: nickname, themeDark: current.themeDark));
    }

    return success;
  }
```

(The leading `emit(SettingDataLoading(...))` is gone — Task 2 removed the class, and it emitted a state identical to the one already showing.)

`saveNickname`:

```dart
  Future<bool> saveNickname(String? newNickname) async {
    final current = state;
    if (current is! SettingData) return false;

    if (newNickname == null ||
        newNickname.isEmpty ||
        newNickname == current.nickname) {
      return true;
    }

    await emitGuard(
      loadingState: SettingData(
        nickname: current.nickname,
        themeDark: current.themeDark,
      ),
      newState: (_) async {
        await _localData.saveNickname(newNickname);
        return SettingData(
          nickname: newNickname,
          themeDark: current.themeDark,
        );
      },
      errorState: (e) => SettingError(message: e.toString()),
    );

    return state is SettingData;
  }
```

`changeTheme` gets the same guard shape. Task 5 deletes this method entirely, but leave it correct in the meantime so this task's commit stands on its own:

```dart
  Future<void> changeTheme(bool value) async {
    final current = state;
    if (current is! SettingData) return;

    emitGuard(
      loadingState: SettingData(
        nickname: current.nickname,
        themeDark: current.themeDark,
      ),
      newState: (_) async {
        await _localData.saveTheme(value);
        return SettingData(nickname: current.nickname, themeDark: value);
      },
      errorState: (e) => SettingError(message: e.toString()),
    );
  }
```

- [ ] **Step 2: Guard `selectDay` and fix the division by zero**

In `lib/controllers/calendar_controller.dart`, replace `treatData` and `selectDay` with:

```dart
  void treatData() {
    emitGuard(
      loadingState: CalendarLoading(),
      newState: (oldState) {
        final eventListTemp = EventList<Event>(events: {});

        for (final item in _userData) {
          if (item.goals.isEmpty) continue;

          final totalPercent = item.goals
              .map((goal) => goal.percentCompleted)
              .reduce((a, b) => a + b);
          final avgPercent = totalPercent / item.goals.length;

          eventListTemp.add(
            item.date,
            Event(
              date: item.date,
              dot: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.rectangle,
                  color: Utilities.activeColor(avgPercent),
                  borderRadius: BorderRadius.circular(10),
                ),
                height: 2.0,
                width: 16.0,
              ),
            ),
          );
        }

        return CalendarData(
          eventList: eventListTemp,
          selectedDaysGoals:
              oldState is CalendarData ? oldState.selectedDaysGoals : null,
          selectedDay: oldState is CalendarData
              ? oldState.selectedDaysGoals?.date ?? DateTime.now()
              : DateTime.now(),
        );
      },
      errorState: (e) => CalendarError(message: e.toString()),
    );
  }

  void selectDay(DateTime date) {
    final current = state;
    if (current is! CalendarData) return;

    emit(
      CalendarData(
        eventList: current.eventList,
        selectedDaysGoals:
            _userData.where((e) => e.date == date).firstOrNull,
        selectedDay: date,
      ),
    );
  }
```

`selectDay`'s two near-identical branches collapse: `where(...).firstOrNull` returns `null` when nothing matches, which is exactly what the old else-branch emitted. `firstOrNull` comes from `dart:collection`'s `Iterable` extension in `package:collection`— it is **not** available by default. Use this instead, which needs no new dependency:

```dart
        selectedDaysGoals: _userData.cast<DateGoalModel?>().firstWhere(
              (e) => e?.date == date,
              orElse: () => null,
            ),
```

The `if (item.goals.isEmpty) continue;` skips days with no goals rather than marking them `NaN`-green.

- [ ] **Step 3: Verify**

Run: `flutter analyze && flutter test`
Expected: analyze reports only the pre-existing info. `flutter test` still fails on `test/widget_test.dart` (the untouched counter template) — that is expected and Task 7 deletes it. `test/goal_history_test.dart` must pass.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "fix: guard state casts and the empty-goals division

SettingsController cast state to SettingData in four methods, but the page
constructs it with SettingLoading and onInit is async, so a tap before the
load finished threw TypeError. CalendarController.selectDay had the same
shape. treatData divided by goals.length without a zero check, and the
resulting NaN falls through every comparison in activeColor, painting an
empty day green."
```

---

### Task 5: One source of truth for the theme

The theme is currently stored in two places that are updated by two different operations. `settings_page.dart:161-162` calls `_controller.changeTheme(value)` — which persists an *absolute* value and updates `SettingData.themeDark` — and then `ThemeProvider.of(context).switchThemeMode()`, which *toggles* `ThemeModel._themeMode`. They agree only as long as they never disagree. Meanwhile `ThemeProvider.of` returns a freshly constructed `ThemeModel()` when it cannot find the provider, so a lookup from the wrong subtree silently yields the default theme and an undisposed `ChangeNotifier` instead of an error.

Resolution: `ThemeModel` owns the theme and persists itself. `SettingState` loses `themeDark`, and `SettingsController.changeTheme` is deleted.

**Files:**
- Modify: `lib/configs/theme.dart:7-27` (`ThemeModel`)
- Modify: `lib/providers/theme_provider.dart`
- Modify: `lib/controllers/settings_controller.dart` (drop `themeDark` from `SettingData`, delete `changeTheme`)
- Modify: `lib/pages/settings_page.dart:123-178` (the switch row)

**Interfaces:**
- Consumes: `LocalData.saveTheme(bool)` / `LocalData.searchTheme()` from Task 1.
- Produces:
  - `ThemeModel` gains `Future<void> setDark(bool value)` — persists and notifies. `switchThemeMode()` is **deleted**; callers pass an explicit value.
  - `ThemeProvider.of(BuildContext)` still returns `ThemeModel` but asserts instead of minting one.
  - `SettingData({required String nickname})` — `themeDark` removed. Every construction site in `settings_controller.dart` drops the argument.
  - `SettingsController.changeTheme` is **deleted**.

- [ ] **Step 1: Make `ThemeModel` own and persist the theme**

In `lib/configs/theme.dart`, replace the `ThemeModel` class:

```dart
class ThemeModel extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.dark;

  ThemeModel() {
    _load();
  }

  ThemeMode get themeMode => _themeMode;

  Future<void> _load() async {
    final localData = await LocalData.i;
    _themeMode = localData.searchTheme() ? ThemeMode.dark : ThemeMode.light;
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

`setThemeMode` is renamed to the private `_load` (it had no external callers) and `switchThemeMode` is replaced by `setDark`, which takes the value the `Switch` already hands you rather than inferring it by toggling.

- [ ] **Step 2: Make `ThemeProvider.of` fail loudly**

Replace `lib/providers/theme_provider.dart`:

```dart
import 'package:flutter/material.dart';

import '../configs/theme.dart';

class ThemeProvider extends InheritedNotifier<ThemeModel> {
  const ThemeProvider({
    super.key,
    required super.child,
    required super.notifier,
  });

  static ThemeModel of(BuildContext context) {
    final notifier =
        context.dependOnInheritedWidgetOfExactType<ThemeProvider>()?.notifier;
    assert(notifier != null, 'No ThemeProvider found in context');
    return notifier!;
  }
}
```

- [ ] **Step 3: Remove `themeDark` from the settings state**

In `lib/controllers/settings_controller.dart`:

```dart
class SettingData extends SettingState {
  final String nickname;

  SettingData({required this.nickname});
}
```

Delete `changeTheme` entirely. Then drop the `themeDark:` argument from every remaining `SettingData(...)` construction — there are five, in `onInit`, `clearAllData` (×2), `undoClearAllData`, and `saveNickname` (×2). `onInit` also stops reading the theme:

```dart
  @override
  void onInit() async {
    _localData = await LocalData.i;
    emitGuard(
      loadingState: SettingLoading(),
      newState: (_) async =>
          SettingData(nickname: await _localData.searchNickname() ?? 'User'),
      errorState: (e) => SettingError(message: e.toString()),
    );
  }
```

- [ ] **Step 4: Point the settings switch at `ThemeModel`**

In `lib/pages/settings_page.dart`, replace the whole `ValueListenableBuilder` wrapping the switch row (lines 123-178) with a plain row that reads the theme from the provider. It no longer needs the controller's state at all:

```dart
                Builder(
                  builder: (context) {
                    final themeDark =
                        ThemeProvider.of(context).themeMode == ThemeMode.dark;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Icon(
                            themeDark
                                ? Icons.light_mode_outlined
                                : Icons.light_mode_rounded,
                            color: themeDark
                                ? AppColors.primaryColor
                                : AppColors.blackColor,
                          ),
                          const SizedBox(width: 8),
                          Switch(
                            thumbColor: WidgetStateProperty.resolveWith<Color>(
                              (states) {
                                if (states.contains(WidgetState.selected)) {
                                  return AppColors.blackColor;
                                }
                                return AppColors.whiteColor.shade700;
                              },
                            ),
                            trackColor: WidgetStateProperty.resolveWith<Color>(
                              (states) {
                                if (states.contains(WidgetState.selected)) {
                                  return AppColors.primaryColor;
                                }
                                return AppColors.primaryColor.shade100;
                              },
                            ),
                            value: themeDark,
                            onChanged: ThemeProvider.of(context).setDark,
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            themeDark
                                ? Icons.dark_mode_rounded
                                : Icons.dark_mode_outlined,
                            color: themeDark
                                ? AppColors.primaryColor
                                : AppColors.blackColor,
                          ),
                        ],
                      ),
                    );
                  },
                ),
```

`ThemeProvider` is an `InheritedNotifier`, so `dependOnInheritedWidgetOfExactType` already rebuilds this `Builder` when `ThemeModel` notifies — that is why the `ValueListenableBuilder` is not replaced with anything.

- [ ] **Step 5: Verify**

Run: `flutter analyze`
Expected: only the pre-existing info. Any `undefined_named_parameter: themeDark` means a `SettingData(...)` site was missed in Step 3.

- [ ] **Step 6: Manual check**

Run: `flutter run -d windows` (or any attached device)
Toggle the theme switch in Settings, then close and relaunch the app. Expected: the chosen theme persists, and the icons either side of the switch reflect it immediately on toggle.

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "fix: single source of truth for the theme

The settings switch called changeTheme (persists an absolute value into
SettingData.themeDark) and switchThemeMode (toggles ThemeModel) on the same
tap; the two agreed only by luck. ThemeModel now owns the theme and
persists itself via setDark, and SettingState drops themeDark entirely.

ThemeProvider.of returned a fresh ThemeModel when the lookup missed, which
silently produced the default theme and an undisposed ChangeNotifier
instead of an error. It asserts now."
```

---

### Task 6: Move light/dark branching into `ThemeData`

`ThemeProvider.of(context).themeMode == ThemeMode.dark ? A : B` appears about fifteen times across five files. The values it selects are surface colours and icon colours — exactly what `ThemeData` exists to carry. Separately, `TextStyles` is a singleton with a **static mutable** `_isDark` that the `BuildContext` extension writes as a side effect of a getter; two widgets reading `context.textStyles` under different themes in the same frame race each other.

**Files:**
- Modify: `lib/configs/theme.dart` (add tokens to both `ThemeData`s)
- Modify: `lib/configs/text_styles.dart`
- Modify: `lib/pages/calendar_page.dart`, `lib/pages/settings_page.dart`, `lib/pages/skeleton_page.dart`
- Modify: `lib/widgets/add_day_button.dart`, `lib/widgets/goals_done_list_view.dart`, `lib/widgets/goals_list_view.dart`, `lib/widgets/list_tile_custom.dart`

**Interfaces:**
- Consumes: `ThemeProvider.of` from Task 5 (still exists; it just stops being the way widgets pick colours).
- Produces:
  - `themeDark`/`themeLight` gain `cardColor` (panel/sheet/dialog background) and `iconTheme.color`.
  - `TextStyles` becomes `TextStyles(this.isDark)` — a plain class with a `final bool isDark`, constructed per call. `TextStyles.i` and `setIsDark` are **deleted**. The `context.textStyles` extension and the four getters (`normalText`, `boldText`, `thinText`, `titleText`) keep their exact names and types, so no call site changes.

- [ ] **Step 1: Add the tokens to both themes**

In `lib/configs/theme.dart`, add these two arguments to the `themeDark` `ThemeData(...)`:

```dart
  cardColor: AppColors.blackColor,
  iconTheme: const IconThemeData(color: AppColors.whiteColor),
```

and these to `themeLight`:

```dart
  cardColor: AppColors.whiteColor.shade700,
  iconTheme: const IconThemeData(color: AppColors.blackColor),
```

`cardColor` is the `dark ? blackColor : whiteColor.shade700` pair that appears nine times; `iconTheme.color` is the `dark ? whiteColor : blackColor` pair.

- [ ] **Step 2: Make `TextStyles` immutable and theme-derived**

Replace `lib/configs/text_styles.dart`:

```dart
import 'package:flutter/material.dart';

import 'colors.dart';

class TextStyles {
  final bool isDark;

  const TextStyles(this.isDark);

  static const String font = 'WorkSans';

  Color get _color => isDark ? AppColors.whiteColor : AppColors.blackColor;

  TextStyle get normalText => TextStyle(
        color: _color,
        fontWeight: FontWeight.w500,
        fontFamily: font,
        fontSize: 16,
      );

  TextStyle get boldText => TextStyle(
        color: _color,
        fontWeight: FontWeight.w700,
        fontFamily: font,
        fontSize: 16,
      );

  TextStyle get thinText => TextStyle(
        color: _color,
        fontWeight: isDark ? FontWeight.w100 : FontWeight.w400,
        fontFamily: font,
        fontSize: 16,
      );

  TextStyle get titleText => boldText.copyWith(fontSize: 32);
}

extension TextStylesExtension on BuildContext {
  TextStyles get textStyles =>
      TextStyles(Theme.of(this).brightness == Brightness.dark);
}
```

This drops the `theme_provider.dart` import (breaking an import cycle between configs and providers) and reads `Theme.of`, which is what `MaterialApp` already resolved from `themeMode`.

`thinText` has no call sites today (`grep -rn "thinText" lib/`); it is kept because it is part of a four-style set and costs six lines. If the grep shows zero uses and you would rather cut it, that is a defensible extra deletion — say so in the commit body rather than doing it silently.

- [ ] **Step 3: Replace the surface-colour ternaries with `Theme.of(context).cardColor`**

Nine sites. In each, delete the whole `ThemeProvider.of(context).themeMode == ThemeMode.dark ? AppColors.blackColor : AppColors.whiteColor.shade700` expression (and its light-first inverse, `… == ThemeMode.light ? AppColors.whiteColor.shade50 : AppColors.blackColor`, which differs only in the light shade) and write `Theme.of(context).cardColor`:

- `lib/pages/calendar_page.dart:52` — container `color:`
- `lib/pages/calendar_page.dart:74` — `dayButtonColor:`
- `lib/pages/calendar_page.dart:80` — `weekDayBackgroundColor:`
- `lib/pages/calendar_page.dart:85` — `selectedDayButtonColor:`
- `lib/pages/calendar_page.dart:133` — container `color:`
- `lib/pages/settings_page.dart:204` — `showModalBottomSheet` `backgroundColor:`
- `lib/pages/settings_page.dart:271` — `_confirmDialog` `backgroundColor:`
- `lib/pages/settings_page.dart:329` — `_aboutTheAppDialog` `backgroundColor:`
- `lib/widgets/list_tile_custom.dart` — the gradient's second stop pair; see Step 5.

For the two dialogs the light value was `AppColors.whiteColor.shade50`, not `.shade700`. Using `cardColor` makes both dialogs match the bottom sheet. That is an intentional visual change — note it in the commit body.

- [ ] **Step 4: Replace the icon-colour and cursor ternaries**

- `lib/widgets/goals_list_view.dart:47-50` — `cursorColor:` → `Theme.of(context).textSelectionTheme.cursorColor`. Both `ThemeData`s already define `textSelectionTheme.cursorColor` (`whiteColor` in dark, `blackColor` in light), so the ternary is redundant.
- `lib/pages/settings_page.dart:219-222` — same `cursorColor:` replacement.
- `lib/widgets/goals_done_list_view.dart:52-55` — the icon colour ternary → `Theme.of(context).iconTheme.color!.withValues(alpha: .5)`.
- `lib/widgets/goals_done_list_view.dart:70-72` — the `Divider` colour ternary → `Theme.of(context).dividerColor`; add `dividerColor: AppColors.whiteColor.shade900.withValues(alpha: .3)` to `themeDark` and `dividerColor: AppColors.blackColor.withValues(alpha: .3)` to `themeLight` in `theme.dart`.
- `lib/widgets/add_day_button.dart:97-99` — the `AnimatedIcon` colour ternary → `Theme.of(context).iconTheme.color`.

- [ ] **Step 5: Handle the sites that do not map to a token**

Three ternaries select values with no natural `ThemeData` slot. Leave the branching but source it from `Theme.of(context).brightness` so `ThemeProvider` is no longer a colour-lookup mechanism. In each file add one local at the top of `build` and use it:

```dart
    final isDark = Theme.of(context).brightness == Brightness.dark;
```

- `lib/widgets/add_day_button.dart:79-81` — the second `BoxShadow` colour (`blackColor.shade500` / `whiteColor.shade700`). Note this is inside an `AnimatedBuilder` builder, so declare `isDark` inside that builder, not in `build`.
- `lib/widgets/list_tile_custom.dart` — the gradient stop list.
- `lib/pages/skeleton_page.dart:134-140` and `:153-160` — the two four-way FAB ternaries (`isDark` × `value == 1`). Keep both dimensions; only swap the `isDark` source.

- [ ] **Step 6: Drop the now-unused `ThemeProvider` imports**

Run: `flutter analyze`
Every file that no longer references `ThemeProvider` will report `unused_import`. Remove those import lines. `lib/main.dart` and `lib/pages/settings_page.dart` still use it (for `notifier:` and the theme switch respectively) — keep theirs.

- [ ] **Step 7: Verify**

Run: `flutter analyze`
Expected: only the pre-existing info.

Run: `grep -rn "ThemeProvider.of" lib/`
Expected: exactly two hits, both in `lib/pages/settings_page.dart` (the switch row), plus `lib/main.dart:34` (`themeMode:`).

- [ ] **Step 8: Manual check**

Run: `flutter run -d windows`
Toggle the theme and visit all three pages. Expected: no unstyled surface, no black-on-black text, dialogs and the bottom sheet share a background.

- [ ] **Step 9: Commit**

```bash
git add -A
git commit -m "refactor: move light/dark branching into ThemeData

Fifteen ThemeProvider ternaries across five files selected surface and icon
colours by hand. Those are now cardColor, iconTheme.color, dividerColor and
textSelectionTheme.cursorColor, read via Theme.of. The three that map to no
token keep their branching but source it from Theme.of(context).brightness.

TextStyles was a singleton whose static mutable _isDark was written as a
side effect of the BuildContext getter, so two widgets reading it under
different themes in one frame raced. It is now an immutable value built per
call from Theme.of(this).brightness; every call site is unchanged.

Visual change: the two AlertDialogs used whiteColor.shade50 in light mode
where the bottom sheet used shade700. Both now use cardColor."
```

---

### Task 7: Propagate "delete all data" across pages, fix the build-time animation, replace the template test

Three unrelated leftovers, grouped because each is small and none has a natural neighbour.

**7a.** Settings' "Delete all data" clears `SharedPreferences`, but `HomeController` and `CalendarController` hold their own in-memory `userData` and were built in their own pages' `initState`. All three pages are alive simultaneously inside the `PageView`, so Home keeps rendering deleted goals until the app restarts.

**7b.** `add_day_button.dart:58-62` calls `_iconAnimationController.forward()`/`reverse()` from inside an `AnimatedBuilder` builder — a side effect during build.

**7c.** `test/widget_test.dart` is the unmodified Flutter counter template and fails.

**Files:**
- Modify: `lib/configs/local_data.dart` (add `revision`)
- Modify: `lib/controllers/home_controller.dart`, `lib/controllers/calendar_controller.dart` (subscribe)
- Modify: `lib/widgets/add_day_button.dart`
- Delete: `test/widget_test.dart`

**Interfaces:**
- Consumes: `LocalData` from Task 1; `HomeController.recoveryData` and `CalendarController.treatData` from Tasks 3 and 4.
- Produces: `static final ValueNotifier<int> LocalData.revision` — bumped by `clearAllData` and `undoRecoveryData` only. `saveUserData` does **not** bump it: `HomeController` is the only caller and it already owns the resulting state, so bumping there would make it reload itself in a loop.

- [ ] **Step 1: Add the revision notifier**

In `lib/configs/local_data.dart`, add the field next to the other statics:

```dart
  /// Bumped when data is wiped or restored from outside the controller that
  /// owns it, so other live pages can reload. Not bumped by saveUserData —
  /// its only caller already holds the resulting state.
  static final ValueNotifier<int> revision = ValueNotifier(0);
```

This needs `import 'package:flutter/foundation.dart';` at the top.

Then bump it at the end of `clearAllData`:

```dart
    await _sharedPreferences!.setString(_recoveryData, recoveryModel.toJson());
    revision.value++;
```

and in `undoRecoveryData`, immediately before `return true;`:

```dart
    revision.value++;
    return true;
```

- [ ] **Step 2: Subscribe `HomeController`**

In `lib/controllers/home_controller.dart`, add the listener in `onInit` and drop it in `onDispose`:

```dart
  @override
  void onInit() async {
    localData = await LocalData.i;
    LocalData.revision.addListener(_reload);
    emitGuard(
      loadingState: HomeLoading(),
      newState: recoveryData,
      errorState: (e) => HomeError(message: e.toString()),
    );
  }

  void _reload() => emitGuard(
        loadingState: HomeLoading(),
        newState: recoveryData,
        errorState: (e) => HomeError(message: e.toString()),
      );
```

and at the top of the existing `onDispose` (which Task 3 added):

```dart
  @override
  void onDispose() {
    LocalData.revision.removeListener(_reload);
    for (final controller in goalsControllers) {
      controller.dispose();
    }
    goalsControllers = [];
    super.onDispose();
  }
```

`recoveryData` already does `userData..clear()..addAll(...)` after Task 3, so a reload picks up the wipe correctly.

- [ ] **Step 3: Subscribe `CalendarController`**

Same shape. In `lib/controllers/calendar_controller.dart`:

```dart
  @override
  void onInit() async {
    _localData = await LocalData.i;
    LocalData.revision.addListener(_reload);
    await _reload();
  }

  Future<void> _reload() async {
    _userData
      ..clear()
      ..addAll(await _localData.searchUserData() ?? []);
    treatData();
  }

  @override
  void onDispose() {
    LocalData.revision.removeListener(_reload);
    super.onDispose();
  }
```

`addListener` takes a `VoidCallback`; `_reload` returns `Future<void>`, which is assignable to `void Function()` in Dart — the analyzer accepts it and the future is fire-and-forget, which is what is wanted here.

- [ ] **Step 4: Move the animation out of `build`**

In `lib/widgets/add_day_button.dart`, delete these five lines from inside the `AnimatedBuilder` builder:

```dart
          if (widget.hasMarkedToday) {
            _iconAnimationController.forward();
          } else {
            _iconAnimationController.reverse();
          }
```

and add, after `initState`:

```dart
  @override
  void didUpdateWidget(AddDayButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.hasMarkedToday != oldWidget.hasMarkedToday) {
      widget.hasMarkedToday
          ? _iconAnimationController.forward()
          : _iconAnimationController.reverse();
    }
  }
```

Also set the initial position in `initState`, since `didUpdateWidget` does not run on the first build — add this line immediately before `super.initState();`:

```dart
    if (widget.hasMarkedToday) _iconAnimationController.value = 1;
```

- [ ] **Step 5: Delete the template test**

```bash
git rm test/widget_test.dart
```

It asserts a counter increments and taps `Icons.add`; the app has no counter. `test/goal_history_test.dart` from Task 3 is the real check.

- [ ] **Step 6: Verify**

Run: `flutter analyze && flutter test`
Expected: analyze reports only the pre-existing info; `flutter test` reports **All tests passed** (only `goal_history_test.dart` remains).

- [ ] **Step 7: Manual check**

Run: `flutter run -d windows`
Add a goal on Home, mark the day, swipe to Settings, "Delete all data", swipe back to Home. Expected: Home shows the empty state, not the deleted goals. Tap the undo snackbar; expected: the goals come back on Home and the marker returns to the Calendar.

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "fix: propagate data wipes across live pages

All three pages live in a PageView simultaneously, each holding its own
in-memory copy of userData, so Settings clearing SharedPreferences left
Home and Calendar rendering deleted goals until restart. LocalData now
exposes a revision notifier bumped by clearAllData and undoRecoveryData,
which both controllers reload from.

AddDayButton drove its icon animation from inside an AnimatedBuilder
builder; that moves to didUpdateWidget, with initState seeding the initial
position.

Deletes the Flutter counter template test, which asserted a counter this
app has never had and failed on every run."
```

---

## Self-Review

**1. Spec coverage.** The audit's nine bugs and thirteen cuts map as follows. Bug 1 (history rewrite) → Task 3. Bug 2 (unchecked casts) → Tasks 3 and 4. Bug 3 (`hasMarkedToday` from `setString`) → Task 3. Bug 4 (controller leak/lost typing) → Task 3. Bug 5 (two theme sources) → Task 5. Bug 6 (division by zero) → Task 4. Bug 7 (`clearAllData` does not propagate) → Task 7a. Bug 8 (animation in build) → Task 7b. Bug 9 (failing template test) → Task 7c. Cuts: empty file, `when()`, `whenNull()`, `LocalDataException`, enum fields, `GoalModel` JSON, `*DataLoading`, `ListTileCustom.bottom`, radius, theme ternaries, triple `ValueListenableBuilder`, `activeColor`, template test → Tasks 1, 2, 5, 6, 7. The triple `ValueListenableBuilder` in `settings_page` is reduced by one in Task 5 (the switch row stops needing controller state); the remaining two read genuinely different things (`nickname` for the greeting and for the tile title) and are left alone — that is a deliberate narrowing of the audit item, not an omission.

**2. Placeholder scan.** No TBDs, no "add error handling", no "similar to Task N". Every code step carries the actual code. Task 6 Steps 3-5 list exact file:line targets rather than repeating nine near-identical replacements verbatim, which is the one place the plan describes rather than shows; the expression to delete and the expression to write are both given literally, so it is mechanical.

**3. Type consistency.** `recoveryData` keeps its optional positional `[HomeState? oldState]` across Tasks 3 and 7 because `emitGuard`'s `newState` parameter is `FutureOr<State> Function(State)`. `setGoalsControllers(List<GoalModel>?)` keeps its nullable parameter. `SettingData` drops `themeDark` in Task 5 only — Task 4 still passes it, and Task 5's Step 3 enumerates all five construction sites to update. `ThemeModel.switchThemeMode` is deleted in Task 5 Step 1 and its only caller is rewritten in Task 5 Step 4. `TextStyles.i`/`setIsDark` are deleted in Task 6 Step 2 and have no callers outside the extension in that same file. `LocalData.revision` is introduced in Task 7 Step 1 and read in Steps 2-3 only.

One inconsistency found and fixed inline: Task 4 Step 2 originally used `firstOrNull`, which requires `package:collection` — not a dependency of this project. The step now uses `cast<DateGoalModel?>().firstWhere(..., orElse: () => null)` instead.
