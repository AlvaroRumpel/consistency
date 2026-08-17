import 'dart:async';

import '../engine/consistency_engine.dart';
import '../models/date_key.dart';
import '../state/app_store.dart';
import '../state/settings_store.dart';
import 'reminder_scheduler.dart';

/// Decides what reminder (if any) should be pending, given the current
/// data and settings, and keeps the scheduler in sync as they change.
class ReminderService {
  final ReminderScheduler _scheduler;
  final AppStore _store;
  final SettingsStore _settings;
  final DateTime Function() _now;

  ReminderService({
    required ReminderScheduler scheduler,
    required AppStore store,
    required SettingsStore settings,
    DateTime Function()? now,
  })  : _scheduler = scheduler,
        _store = store,
        _settings = settings,
        _now = now ?? DateTime.now;

  Future<void> start() async {
    await _scheduler.init();
    await sync();
    _store.addListener(_onChange);
    _settings.addListener(_onChange);
  }

  void _onChange() => sync();

  // Fire-and-forget on purpose: ChangeNotifier listeners are synchronous, so
  // this must not suspend on `await` before touching the scheduler, or a
  // store/settings mutation that fires notifyListeners() early (e.g.
  // AppStore._commit) can finish and be observed by a caller before this
  // reaction has actually run. The fake/real schedulers both start their
  // work synchronously when called; only their completion is async.
  Future<void> sync() async {
    unawaited(_scheduler.cancelAll());
    if (!_settings.notifEnabled) return;

    final now = _now();
    final today = dateOnly(now);
    final (hour, minute) = _settings.notifTime;
    final todayAt = DateTime(today.year, today.month, today.day, hour, minute);
    final when = (_store.data.entryOn(today) == null && todayAt.isAfter(now))
        ? todayAt
        : DateTime(today.year, today.month, today.day + 1, hour, minute);

    final streak = ConsistencyEngine(
      data: _store.data,
      threshold: _settings.threshold,
      today: today,
    ).globalStreak();

    unawaited(_scheduler.schedule(ReminderRequest(
      when: when,
      title: 'Consistency',
      body:
          "${_settings.nicknameOrDefault}, you haven't saved today — streak: $streak",
    )));
  }

  Future<bool> enable() async {
    if (!await _scheduler.ensurePermission()) return false;
    await _settings.setNotifEnabled(true);
    await sync();
    return true;
  }

  Future<void> disable() async {
    await _settings.setNotifEnabled(false);
    await _scheduler.cancelAll();
  }

  void dispose() {
    _store.removeListener(_onChange);
    _settings.removeListener(_onChange);
  }
}
