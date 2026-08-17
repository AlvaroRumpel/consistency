import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/widgets.dart';

import '../engine/consistency_engine.dart';
import '../l10n/app_localizations.dart';
import '../models/date_key.dart';
import '../state/app_store.dart';
import '../state/settings_store.dart';
import 'reminder_scheduler.dart';

/// Decides what reminder (if any) should be pending, given the current
/// data and settings, and keeps the scheduler in sync as they change.
class ReminderService with WidgetsBindingObserver {
  final ReminderScheduler _scheduler;
  final AppStore _store;
  final SettingsStore _settings;
  final DateTime Function() _now;
  final Locale Function() _localeOf;

  Future<void> _chain = Future.value();

  ReminderService({
    required ReminderScheduler scheduler,
    required AppStore store,
    required SettingsStore settings,
    DateTime Function()? now,
    Locale Function()? localeOf,
  })  : _scheduler = scheduler,
        _store = store,
        _settings = settings,
        _now = now ?? DateTime.now,
        _localeOf = localeOf ?? (() => PlatformDispatcher.instance.locale);

  Future<void> start() async {
    // Listeners first: a scheduler that fails to initialise must not leave the
    // service detached from the stores for the rest of the session.
    _store.addListener(_onChange);
    _settings.addListener(_onChange);
    WidgetsBinding.instance.addObserver(this);
    try {
      await _scheduler.init();
      await sync();
    } catch (e, s) {
      // start() is called from `unawaited(...)`; an escaping error would be
      // an unhandled async error and take the zone down.
      debugPrint('ReminderService.start failed: $e\n$s');
    }
  }

  void _onChange() => unawaited(sync());

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The pending reminder was computed for the day the app was last used;
    // after a night in the background it is stale.
    if (state == AppLifecycleState.resumed) unawaited(sync());
  }

  /// Serializes the platform calls — a cancel must not overtake the schedule
  /// that follows it. A failed call is reported and never poisons the queue
  /// for the next one, so the returned future never carries an error.
  Future<void> _enqueue(Future<void> Function() op) {
    final next = _chain.then((_) => op(), onError: (_, __) => op());
    _chain = next.then((_) {}, onError: (_, __) {});
    return next.catchError(
        (e, s) => debugPrint('ReminderService: scheduler call failed: $e\n$s'));
  }

  // Deliberately await-free: ChangeNotifier listeners are synchronous, so this
  // must not suspend before handing work to the scheduler, or a store/settings
  // mutation that fires notifyListeners() early (e.g. AppStore._commit) can
  // finish and be observed by a caller before this reaction has been queued.
  // _enqueue() queues and returns immediately; the future it hands back is
  // only there for callers that want to wait for the queue to drain.
  Future<void> sync() {
    final cancelled = _enqueue(_scheduler.cancel);
    if (!_settings.notifEnabled) return cancelled;

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

    // No BuildContext out here, so the strings come straight from the
    // delegate — inside the enqueued closure, where suspending is fine.
    var locale = _localeOf();
    if (!AppLocalizations.delegate.isSupported(locale)) {
      locale = const Locale('en');
    }
    final name = _settings.nickname;

    return _enqueue(() async {
      final l10n = await AppLocalizations.delegate.load(locale);
      return _scheduler.schedule(ReminderRequest(
        when: when,
        title: l10n.reminderTitle,
        body: l10n.reminderBody(name ?? l10n.defaultNickname, streak),
      ));
    });
  }

  Future<bool> enable() async {
    if (!await _scheduler.ensurePermission()) return false;
    // The setter notifies, which runs _onChange -> sync(); no second sync here.
    await _settings.setNotifEnabled(true);
    return true;
  }

  Future<void> disable() async {
    await _settings.setNotifEnabled(false);
    // sync() already cancelled the reminder; sweep anything else we posted.
    await _enqueue(_scheduler.cancelAll);
  }

  void dispose() {
    _store.removeListener(_onChange);
    _settings.removeListener(_onChange);
    WidgetsBinding.instance.removeObserver(this);
  }
}
