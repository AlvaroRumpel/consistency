import 'package:flutter/foundation.dart' show debugPrint;
import 'package:home_widget/home_widget.dart';

import 'widget_bridge.dart';

/// [WidgetBridge] backed by the `home_widget` plugin. No iOS App Group id is
/// needed here — Android widget data lives in the plugin's own
/// SharedPreferences file.
///
/// [update] targets both `AppWidgetProvider` classes Task 3 adds under
/// `android/.../ConsistencyWidgetProvider*.kt` — one per widget size. A class
/// that doesn't exist yet (or no longer exists) just fails that one call; the
/// other size still redraws.
class HomeWidgetBridge implements WidgetBridge {
  static const _androidNames = [
    'ConsistencyWidgetProviderSmall',
    'ConsistencyWidgetProviderLarge',
  ];

  @override
  Future<void> save(String key, Object value) async {
    await HomeWidget.saveWidgetData(key, value);
  }

  @override
  Future<void> update() async {
    for (final name in _androidNames) {
      try {
        await HomeWidget.updateWidget(androidName: name);
      } catch (e, s) {
        // One missing/misconfigured provider must not stop the other size
        // from redrawing.
        debugPrint('HomeWidgetBridge.update($name) failed: $e\n$s');
      }
    }
  }
}
