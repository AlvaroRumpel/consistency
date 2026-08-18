import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/widgets.dart';

import '../l10n/app_localizations.dart';
import '../models/date_key.dart';
import '../state/app_store.dart';
import '../state/settings_store.dart';
import 'widget_bridge.dart';
import 'widget_publisher.dart';

/// Keeps the home-screen widget's data in sync with [AppStore]/[SettingsStore],
/// mirroring `ReminderService`'s shape: listeners on both stores, a resume
/// hook, and a serialized queue so bridge calls never run out of order.
class WidgetSyncService with WidgetsBindingObserver {
  final WidgetBridge _bridge;
  final AppStore _store;
  final SettingsStore _settings;
  final DateTime Function() _now;
  final Locale Function() _localeOf;

  Future<void> _chain = Future.value();

  WidgetSyncService({
    required WidgetBridge bridge,
    required AppStore store,
    required SettingsStore settings,
    DateTime Function()? now,
    Locale Function()? localeOf,
  })  : _bridge = bridge,
        _store = store,
        _settings = settings,
        _now = now ?? DateTime.now,
        _localeOf = localeOf ?? (() => PlatformDispatcher.instance.locale);

  Future<void> start() async {
    // Listeners first: a first publish that fails must not leave the service
    // detached from the stores for the rest of the session.
    _store.addListener(_onChange);
    _settings.addListener(_onChange);
    WidgetsBinding.instance.addObserver(this);
    await sync();
  }

  void _onChange() => unawaited(sync());

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The widget was last published for the day the app was backgrounded;
    // after a night away it is stale.
    if (state == AppLifecycleState.resumed) unawaited(sync());
  }

  /// Serializes the platform calls — publishes must land in order. A failed
  /// call is reported and never poisons the queue for the next one, so the
  /// returned future never carries an error.
  Future<void> _enqueue(Future<void> Function() op) {
    final next = _chain.then((_) => op(), onError: (_, __) => op());
    _chain = next.then((_) {}, onError: (_, __) {});
    return next.catchError(
        (e, s) => debugPrint('WidgetSyncService: bridge call failed: $e\n$s'));
  }

  // Deliberately await-free: ChangeNotifier listeners are synchronous, so this
  // must not suspend before handing work to the bridge, or a store/settings
  // mutation that fires notifyListeners() early can finish and be observed by
  // a caller before this reaction has been queued. _enqueue() queues and
  // returns immediately; the future it hands back is only there for callers
  // that want to wait for the queue to drain.
  Future<void> sync() {
    // An unloaded store (or one whose load failed) holds AppData.empty, and
    // publishing that would wipe a good widget down to zeros. A stale widget
    // beats a wrong one, so skip the bridge entirely.
    if (!_store.loaded || _store.loadError != null) return Future.value();

    final today = dateOnly(_now());
    final threshold = _settings.threshold;
    final nickname = _settings.nickname;
    final data = _store.data;

    // No BuildContext out here, so the strings come straight from the
    // delegate — inside the enqueued closure, where suspending is fine.
    var locale = _localeOf();
    if (!AppLocalizations.delegate.isSupported(locale)) {
      locale = const Locale('en');
    }

    return _enqueue(() async {
      // The headless tick has no app locale of its own and reads this back.
      await _settings.setWidgetLocale(locale.languageCode);
      final l10n = await AppLocalizations.delegate.load(locale);
      final snapshot = WidgetPublisher.snapshot(
        data: data,
        threshold: threshold,
        today: today,
        nickname: nickname ?? l10n.defaultNickname,
        l10n: l10n,
      );
      await WidgetPublisher.publish(_bridge, snapshot);
    });
  }

  void dispose() {
    _store.removeListener(_onChange);
    _settings.removeListener(_onChange);
    WidgetsBinding.instance.removeObserver(this);
  }
}
