# Phase 6 — Daily Reminder Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** One daily local notification at a configurable time that only fires when the day has not been saved yet, with a Settings section (toggle + time) and Android 13+ permission handling; survives reboot.

**Architecture:** `ReminderScheduler` wraps `flutter_local_notifications` + `timezone` behind a tiny interface so all logic is unit-testable with a fake; `ReminderService` decides *what* to schedule from `AppStore` + `SettingsStore` (next unsaved day at the configured time) and is called on app start, after every `saveDay`, and whenever the reminder settings change. UI: one Settings section.

**Tech Stack:** Flutter 3.41, `provider`, new: `flutter_local_notifications`, `timezone`, `flutter_timezone`. Android only (no iOS folder in this repo).

**Spec:** `docs/superpowers/specs/2026-08-15-consistency-v2-design.md` — Seção 4 (Notificações), fase 6. Design (approved): `settings.dc.html` — section `LEMBRETE` with "Lembrete diário" switch, "Horário 20:00 ›" row and the caption "Só avisa se você ainda não salvou o dia." (English strings in code until Phase 8).

## Global Constraints

- Setting keys already exist in `SettingsRepository`: `notifEnabled` (default false), `notifHour` (20), `notifMinute` (0). Do not rename.
- Reminder fires **daily at the configured local time, only if that day has no entry**. Implementation: schedule a single exact-ish notification for the next occurrence; after each `saveDay(today)` (or any settings change / app resume), recompute and reschedule. Body text: `"{nickname}, you haven't saved today — streak: {streak}"`; title `Consistency`.
- Android 13+ (`POST_NOTIFICATIONS`) is requested when the user turns the toggle **on**; if denied, the toggle goes back off and a snackbar explains. Reboot: `RECEIVE_BOOT_COMPLETED` + the plugin's boot receiver.
- Use inexact scheduling (`AndroidScheduleMode.inexactAllowWhileIdle`) — no `SCHEDULE_EXACT_ALARM` permission, no Play Store justification needed.
- `ReminderScheduler` must be injectable; all logic tests use a fake, no platform channels in unit tests.
- No notification logic inside widgets: the service is created in `main()` and provided; Settings calls store setters, the service reacts.
- Lints; `flutter analyze` clean; `flutter test --concurrency=1 --reporter expanded` green; `dart format lib test`; Conventional Commits; no hardcoded colours in the new UI.

---

### Task 1: Dependencies + Android config

**Files:**
- Modify: `pubspec.yaml`, `android/app/build.gradle`, `android/app/src/main/AndroidManifest.xml`
- Test: none (build-only task; `flutter test` must still pass)

- [ ] **Step 1: deps** — add to `pubspec.yaml` dependencies:
```yaml
  flutter_local_notifications: ^18.0.1
  timezone: ^0.9.4
  flutter_timezone: ^3.0.1
```
Run `flutter pub get`.

- [ ] **Step 2: desugaring** — `flutter_local_notifications` v18 needs core library desugaring. In `android/app/build.gradle` inside `android { ... }` add (or merge into the existing blocks):
```gradle
    compileOptions {
        coreLibraryDesugaringEnabled true
        sourceCompatibility JavaVersion.VERSION_17
        targetCompatibility JavaVersion.VERSION_17
    }
```
and at the bottom of the file:
```gradle
dependencies {
    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.4'
}
```
(If a `dependencies { }` block already exists, add the line inside it. If `kotlinOptions { jvmTarget = ... }` exists, leave it.)

- [ ] **Step 3: manifest** — in `android/app/src/main/AndroidManifest.xml`, above `<application>`:
```xml
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
```
and inside `<application>`, after the `</activity>`:
```xml
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED"/>
                <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
                <action android:name="android.intent.action.QUICKBOOT_POWERON"/>
                <action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/>
            </intent-filter>
        </receiver>
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver"/>
```

- [ ] **Step 4: verify** — `flutter analyze`, `flutter test --concurrency=1`, and `flutter build apk --debug` (must succeed; this is the only proof desugaring is right). If the build fails on the desugar version, bump `desugar_jdk_libs` to the version the error names and report it.
- [ ] **Step 5: Commit** — `git add pubspec.yaml pubspec.lock android && git commit -m "chore: add local notification deps and android config"`

---

### Task 2: `ReminderScheduler` (platform wrapper) + fake

**Files:**
- Create: `lib/notifications/reminder_scheduler.dart`, `lib/notifications/fake_reminder_scheduler.dart`
- Test: `test/fake_reminder_scheduler_test.dart` (sanity of the fake only)

**Interfaces (produced):**
```dart
class ReminderRequest {
  final DateTime when;       // local wall-clock instant
  final String title, body;
  const ReminderRequest({required this.when, required this.title, required this.body});
}
abstract class ReminderScheduler {
  Future<void> init();                          // plugin init + timezone database
  Future<bool> ensurePermission();              // Android 13+; true when granted (or not needed)
  Future<void> schedule(ReminderRequest r);     // replaces any pending reminder (fixed id 1)
  Future<void> cancelAll();
}
class LocalReminderScheduler implements ReminderScheduler { ... }   // flutter_local_notifications
class FakeReminderScheduler implements ReminderScheduler {
  bool permissionGranted = true;
  final List<ReminderRequest> scheduled = [];
  int cancels = 0; bool inited = false;
}
```
- `LocalReminderScheduler.init()`: `tz.initializeTimeZones()`, `tz.setLocalLocation(tz.getLocation(await FlutterTimezone.getLocalTimezone()))`, then `FlutterLocalNotificationsPlugin().initialize(InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')))`.
- `schedule`: `zonedSchedule(1, title, body, tz.TZDateTime.from(r.when, tz.local), NotificationDetails(android: AndroidNotificationDetails('daily_reminder', 'Daily reminder', importance: Importance.defaultImportance)), androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle)` — no `matchDateTimeComponents` (we reschedule ourselves).
- `ensurePermission`: `resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission() ?? true`.

- [ ] **Step 1: write the fake + its test** (the real one is not unit-testable):
```dart
test('fake records schedules and cancels', () async {
  final f = FakeReminderScheduler();
  await f.init();
  expect(f.inited, isTrue);
  await f.schedule(ReminderRequest(when: DateTime(2026, 8, 17, 20), title: 't', body: 'b'));
  expect(f.scheduled.single.when, DateTime(2026, 8, 17, 20));
  await f.cancelAll();
  expect(f.cancels, 1);
  expect(f.scheduled, isEmpty); // cancelAll clears the queue
});
```
- [ ] **Step 2–5:** run → fail, implement both classes, green, commit `feat: reminder scheduler wrapper over flutter_local_notifications`.

---

### Task 3: `ReminderService` — decide what to schedule

**Files:**
- Create: `lib/notifications/reminder_service.dart`
- Test: `test/reminder_service_test.dart`

**Interfaces (produced):**
```dart
class ReminderService {
  ReminderService({required ReminderScheduler scheduler, required AppStore store,
    required SettingsStore settings, DateTime Function()? now});
  Future<void> start();      // init scheduler + first sync + subscribe to both stores
  Future<void> sync();       // cancel + (re)schedule according to the current state
  Future<bool> enable();     // ask permission, persist notifEnabled, sync; false when denied
  Future<void> disable();    // persist off + cancelAll
  void dispose();
}
```
Rules (test them all):
- `notifEnabled == false` → `cancelAll`, nothing scheduled.
- Enabled and **today has no entry** and the configured time is still in the future today → schedule today at that time.
- Enabled and today already saved → schedule **tomorrow** at that time.
- Enabled, today unsaved, but the time already passed → schedule **tomorrow** (don't fire immediately).
- Body: `'{nickname}, you haven\'t saved today — streak: {streak}'` using `SettingsStore.nicknameOrDefault` and `ConsistencyEngine.globalStreak()`; title `'Consistency'`.
- Every `sync()` cancels first, so there is never more than one pending reminder.
- Store/settings changes call `sync()` (debounce not needed).

- [ ] **Step 1: failing tests**

`test/reminder_service_test.dart`:
```dart
import 'package:consistency/data/in_memory_goals_repository.dart';
import 'package:consistency/data/settings_repository.dart';
import 'package:consistency/models/app_data.dart';
import 'package:consistency/models/day_entry.dart';
import 'package:consistency/models/goal.dart';
import 'package:consistency/notifications/fake_reminder_scheduler.dart';
import 'package:consistency/notifications/reminder_service.dart';
import 'package:consistency/state/app_store.dart';
import 'package:consistency/state/settings_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final u = DateTime.utc(2026);
  DateTime d(int day) => DateTime(2026, 8, day);
  final goal = Goal(id: 'g', name: 'G', type: GoalType.check, createdAt: d(1), archivedAt: null, updatedAt: u);

  Future<(AppStore, SettingsStore, FakeReminderScheduler, ReminderService)> boot({
    List<DayEntry> entries = const [],
    Map<String, Object> prefs = const {'notifEnabled': true, 'notifHour': 20, 'notifMinute': 0},
    DateTime? now,
  }) async {
    SharedPreferences.setMockInitialValues({'nickname': 'Alvaro', ...prefs});
    final p = await SharedPreferences.getInstance();
    final store = AppStore(InMemoryGoalsRepository(AppData(goals: [goal], entries: entries)));
    await store.load();
    final settings = SettingsStore(SettingsRepository(p));
    final fake = FakeReminderScheduler();
    final service = ReminderService(
      scheduler: fake, store: store, settings: settings,
      now: () => now ?? DateTime(2026, 8, 17, 9),
    );
    await service.start();
    return (store, settings, fake, service);
  }

  test('disabled → nothing scheduled', () async {
    final (_, _, fake, _) = await boot(prefs: {'notifEnabled': false});
    expect(fake.scheduled, isEmpty);
    expect(fake.cancels, greaterThan(0));
  });

  test('unsaved today, time still ahead → today at the configured time', () async {
    final (_, _, fake, _) = await boot();
    expect(fake.scheduled.single.when, DateTime(2026, 8, 17, 20));
    expect(fake.scheduled.single.body, contains('Alvaro'));
  });

  test('time already passed → tomorrow', () async {
    final (_, _, fake, _) = await boot(now: DateTime(2026, 8, 17, 21));
    expect(fake.scheduled.single.when, DateTime(2026, 8, 18, 20));
  });

  test('already saved today → tomorrow', () async {
    final (_, _, fake, _) = await boot(
      entries: [DayEntry(date: d(17), values: {'g': 100}, updatedAt: u)],
    );
    expect(fake.scheduled.single.when, DateTime(2026, 8, 18, 20));
  });

  test('saving today reschedules to tomorrow', () async {
    final (store, _, fake, _) = await boot();
    expect(fake.scheduled.last.when, DateTime(2026, 8, 17, 20));
    await store.saveDay(d(17), {'g': 100});
    expect(fake.scheduled.last.when, DateTime(2026, 8, 18, 20));
  });

  test('changing the time reschedules; disabling cancels', () async {
    final (_, settings, fake, service) = await boot();
    await settings.setNotifTime(7, 30);
    expect(fake.scheduled.last.when, DateTime(2026, 8, 18, 7, 30)); // 7:30 today already passed at 9:00
    await service.disable();
    expect(fake.scheduled, isEmpty);
    expect(settings.notifEnabled, isFalse);
  });

  test('enable asks for permission and gives up when denied', () async {
    final (_, settings, fake, service) = await boot(prefs: {'notifEnabled': false});
    fake.permissionGranted = false;
    expect(await service.enable(), isFalse);
    expect(settings.notifEnabled, isFalse);
    expect(fake.scheduled, isEmpty);

    fake.permissionGranted = true;
    expect(await service.enable(), isTrue);
    expect(settings.notifEnabled, isTrue);
    expect(fake.scheduled.single.when, DateTime(2026, 8, 17, 20));
  });

  test('body carries the current streak', () async {
    final (_, _, fake, _) = await boot(
      entries: [DayEntry(date: d(16), values: {'g': 100}, updatedAt: u)],
    );
    expect(fake.scheduled.single.body, contains('1'));
  });
}
```

- [ ] **Step 2–5:** run → fail, implement, green, commit `feat: reminder service schedules the next unsaved day`.

---

### Task 4: Wire into the app + Settings section

**Files:**
- Modify: `lib/main.dart` (create `LocalReminderScheduler` + `ReminderService`, `start()` after the store loads, provide it), `lib/pages/settings_page.dart` (reminder section), `test/helpers.dart` (`buildApp` uses a `FakeReminderScheduler` so widget tests never touch platform channels)
- Test: `test/settings_reminder_test.dart`

UI (design `settings.dc.html`, English strings): section label `REMINDER`; `SwitchListTile`-like row `Daily reminder` bound to `settings.notifEnabled` (turning on calls `ReminderService.enable()`; if it returns false, show a snackbar `Notifications are blocked in system settings.` and leave it off); row `Time` showing `HH:mm` → `showTimePicker` → `settings.setNotifTime`; caption `We only nudge you if the day isn't saved yet.` Rows disabled (greyed) when the toggle is off.
`main()`: build the service after `store.load()` is kicked off; `unawaited(service.start())`; add `Provider<ReminderService>.value` to the `MultiProvider`. `buildApp` in tests injects `FakeReminderScheduler` (add an optional `ReminderScheduler? scheduler` parameter to `ConsistencyApp`, defaulting to the real one in `main`).

- [ ] **Step 1: failing widget test** — Settings tab shows `Daily reminder` off by default; tapping it turns it on (fake grants) and the `Time` row shows `20:00`; with the fake denying, the switch stays off and the snackbar text appears.
- [ ] **Step 2–5:** run → fail, implement, green, commit `feat: reminder settings section wired to the scheduler`.

---

### Task 5: Device smoke + tag

- [ ] Install on a device: enable the reminder (permission dialog appears on Android 13+), set the time 2 minutes ahead, lock the phone → notification arrives; tap it → app opens. Save the day before the time → no notification. Reboot the phone with a pending reminder → it still fires. `git tag phase-6-done`.

## Self-review

- Spec Seção 4 notificações: horário configurável ✔ (T4), só avisa se não salvou ✔ (T3 rules + reschedule on save), reagenda no boot ✔ (T1 receiver + T4 `start()` on launch), Android 13 permission ✔ (T3 `enable()` + T4 UI), texto com nickname e streak ✔ (T3).
- Names consistent: `ReminderScheduler`/`LocalReminderScheduler`/`FakeReminderScheduler`, `ReminderRequest{when,title,body}`, `ReminderService{start,sync,enable,disable,dispose}`.
- Ruling to ledger: inexact scheduling (no `SCHEDULE_EXACT_ALARM`) — a reminder that can drift a few minutes is fine and avoids the Play Store exact-alarm justification.
