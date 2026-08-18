import 'dart:ui' show Locale;

import 'package:consistency/data/in_memory_goals_repository.dart';
import 'package:consistency/data/settings_repository.dart';
import 'package:consistency/l10n/app_localizations_pt.dart';
import 'package:consistency/models/app_data.dart';
import 'package:consistency/state/app_store.dart';
import 'package:consistency/state/settings_store.dart';
import 'package:consistency/widget/fake_widget_bridge.dart';
import 'package:consistency/widget/widget_tick.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _LoadThrowsRepository extends InMemoryGoalsRepository {
  @override
  Future<AppData> load() async => throw const FormatException('boom');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final pt = AppLocalizationsPt();

  test('the tick is booked for the next 00:05 local', () {
    expect(delayToNextTick(DateTime(2026, 8, 17, 23)),
        const Duration(hours: 1, minutes: 5));
    expect(delayToNextTick(DateTime(2026, 8, 17, 0, 3)),
        const Duration(minutes: 2));
    // Exactly on the mark books the next day, not a zero-delay loop.
    expect(delayToNextTick(DateTime(2026, 8, 17, 0, 5)),
        const Duration(hours: 24));
  });

  test('an untranslated tag falls back to English', () {
    expect(resolveWidgetLocale('xx'), const Locale('en'));
    expect(resolveWidgetLocale('pt'), const Locale('pt'));
  });

  test('the persisted locale drives the headless publish', () async {
    SharedPreferences.setMockInitialValues({'widgetLocale': 'pt'});
    final p = await SharedPreferences.getInstance();
    final store = AppStore(InMemoryGoalsRepository(AppData.empty));
    await store.load();
    final bridge = FakeWidgetBridge();

    await publishTick(
      bridge: bridge,
      store: store,
      settings: SettingsStore(SettingsRepository(p)),
      now: DateTime(2026, 8, 17, 0, 5),
    );

    expect(bridge.updates, 1);
    expect(bridge.data['line1'], pt.widgetStreak(0));
    expect(bridge.data['line2'], 'Hoje: pendente');
    expect(bridge.data['nickname'], pt.defaultNickname);
  });

  test('a store that failed to load publishes nothing', () async {
    SharedPreferences.setMockInitialValues({});
    final p = await SharedPreferences.getInstance();
    final store = AppStore(_LoadThrowsRepository());
    await store.load();
    final bridge = FakeWidgetBridge();

    await publishTick(
      bridge: bridge,
      store: store,
      settings: SettingsStore(SettingsRepository(p)),
      now: DateTime(2026, 8, 17, 0, 5),
    );

    expect(bridge.updates, 0);
    expect(bridge.data, isEmpty);
  });
}
