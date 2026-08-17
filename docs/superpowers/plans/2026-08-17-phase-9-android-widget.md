# Phase 9 — Android Home-Screen Widget Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A home-screen widget showing the current streak and whether today is saved, in 2×1 and 2×2 sizes, updated whenever the app writes and once after midnight, opening the app on tap.

**Architecture:** `WidgetPublisher` (pure Dart, testable) turns `AppData` + settings + engine into a small `WidgetState` (streak, todayDone, nickname, last-7-day qualities) and pushes it through `home_widget`'s key/value bridge; a `WidgetSyncService` subscribes to `AppStore`/`SettingsStore` exactly like `ReminderService` does. Android side: two `AppWidgetProvider`s (or one provider with two layouts) reading those keys via `HomeWidgetPlugin.getData`, plus a `workmanager` daily tick at 00:05 so an unopened app still flips to "pending".

**Tech Stack:** Flutter 3.41, `provider`; new: `home_widget`, `workmanager`. Android XML layouts + Kotlin provider.

**Spec:** `docs/superpowers/specs/2026-08-15-consistency-v2-design.md` — Seção 3/4 (widget), fase 9. Design (approved): `widget.dc.html` in project `b473eda8-1101-4699-a494-6390baa9a37e` — 2×1: flame in tier colour + streak number + "dias" + a dot for today's state; 2×2: flame + "12 dias seguidos" + "Hoje: pendente" + a 7-square week strip; card background, radius 20, hairline border.

## Global Constraints

- Widget data keys (String): `streak` (int), `todayDone` (bool), `nickname` (String), `week` (String — 7 chars, one per day oldest→newest, `-` no data, `0`..`4` quality tier), `updatedAt` (ISO-8601). Names are contract with the Kotlin side; do not rename without changing both.
- The widget shows **localised** text; since a widget can't read `AppLocalizations` from Kotlin, Dart publishes the fully-rendered strings too: `line1` (e.g. `12 dias seguidos` / `12 day streak`) and `line2` (`Hoje: pendente` / `Today: pending`). Kotlin renders strings, never composes them.
- Publish on: app start (after load), every `AppStore` notification, every `SettingsStore` notification, and the WorkManager daily tick at 00:05 local.
- Tap → open the app (`home_widget`'s `HomeWidgetLaunchIntent` / `android:clickable` PendingIntent to `MainActivity`). No in-widget marking (spec explicitly defers it).
- Dart logic must be unit-testable without platform channels: `WidgetPublisher` takes a `WidgetBridge` interface (`Future<void> save(String key, Object value)`, `Future<void> update()`), with `FakeWidgetBridge` for tests.
- Colours in the Kotlin/XML layer come from a small `colors.xml` mirroring the design tokens (primary `#2CA8CB`, card dark `#434345`, card light `#F6F8FA`, flame tiers `#8A9299/#E0862E/#E85D2A/#CB2E33/#2CA8CB`, quality `#C4CFD6/#CB2E33/#E0862E/#2CA8CB/#418F3F`). Light/dark via `values/` + `values-night/`.
- `flutter analyze` clean; `flutter test --concurrency=1 --reporter expanded` green; `dart format lib test`; `flutter build apk --debug` must succeed after each task that touches Android; Conventional Commits; the raw-string guard (`test/no_raw_strings_test.dart`) must stay green (widget strings come from ARB).

---

### Task 1: `WidgetPublisher` + bridge (pure Dart)

**Files:**
- Create: `lib/widget/widget_bridge.dart`, `lib/widget/fake_widget_bridge.dart`, `lib/widget/widget_publisher.dart`
- Modify: `lib/l10n/app_en.arb`, `lib/l10n/app_pt.arb` (keys `widgetStreak(count)`, `widgetTodayPending`, `widgetTodayDone`)
- Test: `test/widget_publisher_test.dart`

**Interfaces (produced):**
```dart
abstract class WidgetBridge {
  Future<void> save(String key, Object value);
  Future<void> update(); // asks Android to redraw both widget sizes
}
class FakeWidgetBridge implements WidgetBridge { final Map<String, Object> data = {}; int updates = 0; }
class WidgetSnapshot {
  final int streak; final bool todayDone; final String nickname; final String week;
  final String line1; final String line2;
}
class WidgetPublisher {
  static WidgetSnapshot snapshot({required AppData data, required int threshold, required DateTime today,
      required String nickname, required AppLocalizations l10n});
  static Future<void> publish(WidgetBridge bridge, WidgetSnapshot s);
}
```
- `week`: 7 chars for `today-6 … today`; `-` when `dayAverage` is null, else the quality tier index `0..4` using the same thresholds as `AppTokens.qualityFor` (<25 → 1, <50 → 2, <75 → 3, else 4; and 0 is unused — keep `-` for no data, tiers 1..4 for data; document it).
- `line1` = `l10n.widgetStreak(streak)`, `line2` = `todayDone ? l10n.widgetTodayDone : l10n.widgetTodayPending`.

- [ ] **Step 1: failing tests** — cover: empty data (streak 0, `week` all `-`, pending); a saved today (todayDone true, last char is a tier); a 3-day streak; `publish` writes all seven keys and calls `update()` once; PT locale produces PT lines.
- [ ] **Steps 2–5:** run → fail, implement, green, commit `feat: widget snapshot and bridge (pure dart)`.

---

### Task 2: `home_widget` + `workmanager` wiring

**Files:**
- Modify: `pubspec.yaml` (`home_widget: ^0.7.0`, `workmanager: ^0.5.2` — verify the versions that resolve with this SDK and report), `lib/main.dart`, `test/helpers.dart`
- Create: `lib/widget/home_widget_bridge.dart`, `lib/widget/widget_sync_service.dart`
- Test: `test/widget_sync_service_test.dart`

**Interfaces:**
```dart
class HomeWidgetBridge implements WidgetBridge { ... }   // home_widget calls, appGroupId not needed on Android
class WidgetSyncService {
  WidgetSyncService({required WidgetBridge bridge, required AppStore store, required SettingsStore settings,
      DateTime Function()? now, Locale Function()? localeOf});
  Future<void> start();  // first publish + listeners (+ WidgetsBindingObserver resume, like ReminderService)
  Future<void> sync();
  void dispose();
}
```
- Same shape as `ReminderService`: serialize bridge calls through an `_enqueue` chain, `debugPrint` errors, never throw into `unawaited`.
- WorkManager: register a periodic task (`Workmanager().registerPeriodicTask('widget-tick', 'widgetTick', frequency: Duration(hours: 24), initialDelay: <until 00:05>)`) in `main()` behind `Workmanager().initialize(callbackDispatcher)`; the dispatcher rebuilds the stores headlessly (prefs + `FileGoalsRepository`) and publishes. Keep the headless path tiny and guarded with try/catch.
- `test/helpers.dart` injects a `FakeWidgetBridge` so widget tests never touch the plugin.

- [ ] **Step 1: failing tests** — service publishes on start, on a store change, and on a settings change; `dispose()` detaches; a bridge failure is logged and does not throw.
- [ ] **Steps 2–5:** run → fail, implement, green, `flutter build apk --debug`, commit `feat: publish widget state on every change`.

---

### Task 3: Android widget (layouts, provider, colours)

**Files:**
- Create: `android/app/src/main/res/layout/widget_small.xml`, `widget_large.xml`; `android/app/src/main/res/xml/widget_small_info.xml`, `widget_large_info.xml`; `android/app/src/main/res/values/colors.xml` + `values-night/colors.xml`; `android/app/src/main/res/drawable/widget_bg.xml`; `android/app/src/main/kotlin/com/acr/consistency/ConsistencyWidgetProvider.kt` (one class, two `<receiver>`s with different info XML, or two thin subclasses)
- Modify: `android/app/src/main/AndroidManifest.xml` (receivers + `APPWIDGET_UPDATE` intent filters)
- Test: none automatable — Task 4 is the device smoke

Provider reads with `HomeWidgetPlugin.getData(context)`: `line1`, `line2`, `streak`, `todayDone`, `week`; sets the flame tint from the tier (`streak` → 0/1–6/7–29/30–99/100+ → the five colours), paints the 7 week squares in the 2×2 layout from `week`, and sets a `PendingIntent` opening `MainActivity` on the root view. Empty/missing data → a neutral "—" state, never a crash.
Layouts follow `widget.dc.html`: 2×1 = flame + big number + label; 2×2 = flame + `line1` + `line2` + week strip. Card background via `widget_bg.xml` (rounded 20dp, `@color/widget_card`, 1dp stroke `@color/widget_hairline`).

- [ ] **Step 1: write the XML/Kotlin; Step 2: `flutter build apk --debug`; Step 3: install and add both widgets by hand (this is the only real verification); Step 4: commit** `feat: android home-screen widget in two sizes`.

---

### Task 4: Smoke + release check + tag

- [ ] Add both widget sizes to the home screen: streak and today's state match the app; save the day in the app → widget updates within a second; change the nickname/threshold → updates; tap → app opens; leave overnight (or set the device clock past midnight) → the daily tick flips it to pending; remove and re-add the widget → no crash with empty data.
- [ ] `flutter build apk --release` (a keystore is needed; if unavailable, `--debug` + note it) and `flutter build appbundle` if you intend to publish.
- [ ] `git tag phase-9-done`, then `git tag v0.2.0` if you want a release marker.

## Self-review

- Spec fase 9: `home_widget` ✔ (T2), streak + estado de hoje ✔ (T1/T3), tap abre o app ✔ (T3), atualiza ao salvar ✔ (T2) e 00:05 ✔ (T2 WorkManager).
- Localisation: strings rendered in Dart and published (Kotlin never composes) — keeps the widget honest in PT and EN.
- Names: `WidgetBridge`, `FakeWidgetBridge`, `HomeWidgetBridge`, `WidgetSnapshot`, `WidgetPublisher.{snapshot,publish}`, `WidgetSyncService.{start,sync,dispose}`, keys `streak/todayDone/nickname/week/updatedAt/line1/line2`.
- Ruling to ledger: no in-widget marking (spec defers it); the widget is read-only.
