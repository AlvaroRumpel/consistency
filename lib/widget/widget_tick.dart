import 'dart:ui' show Locale, PlatformDispatcher;

import '../l10n/app_localizations.dart';
import '../models/date_key.dart';
import '../state/app_store.dart';
import '../state/settings_store.dart';
import 'widget_bridge.dart';
import 'widget_publisher.dart';

/// Time until the next 00:05 local — just after the widget's "today" flips.
/// Built from calendar fields rather than `+ 24h` so a DST jump still lands
/// on 00:05 wall clock.
Duration delayToNextTick(DateTime now) {
  var next = DateTime(now.year, now.month, now.day, 0, 5);
  if (!next.isAfter(now)) {
    next = DateTime(now.year, now.month, now.day + 1, 0, 5);
  }
  return next.difference(now);
}

/// The locale the widget's strings are built in. The headless tick runs with
/// no app locale, so it prefers the tag the foreground app last published
/// with over the platform's, and falls back to English when neither is
/// translated.
Locale resolveWidgetLocale(String? tag) {
  final locale = tag == null ? PlatformDispatcher.instance.locale : Locale(tag);
  return AppLocalizations.delegate.isSupported(locale)
      ? locale
      : const Locale('en');
}

/// One publish from freshly built stores — the body of the WorkManager tick,
/// out here so it is testable without a headless engine.
///
/// A store that never loaded (or whose load failed) holds `AppData.empty`,
/// which would publish a zeroed widget over good data. A stale widget beats
/// a wrong one, so that case leaves the last published snapshot alone.
Future<void> publishTick({
  required WidgetBridge bridge,
  required AppStore store,
  required SettingsStore settings,
  required DateTime now,
}) async {
  if (!store.loaded || store.loadError != null) return;
  final l10n = await AppLocalizations.delegate
      .load(resolveWidgetLocale(settings.widgetLocale));
  await WidgetPublisher.publish(
    bridge,
    WidgetPublisher.snapshot(
      data: store.data,
      threshold: settings.threshold,
      today: dateOnly(now),
      nickname: settings.nickname ?? l10n.defaultNickname,
      l10n: l10n,
    ),
  );
}
