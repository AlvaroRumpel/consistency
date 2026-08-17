import 'package:consistency/data/in_memory_goals_repository.dart';
import 'package:consistency/data/settings_repository.dart';
import 'package:consistency/models/app_data.dart';
import 'package:consistency/models/day_entry.dart';
import 'package:consistency/models/goal.dart';
import 'package:consistency/state/app_store.dart';
import 'package:consistency/state/settings_store.dart';
import 'package:consistency/widget/fake_widget_bridge.dart';
import 'package:consistency/widget/widget_bridge.dart';
import 'package:consistency/widget/widget_sync_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Lets the service's serialized bridge queue drain. The queue is pure
/// microtasks, so a single event-loop hop always empties it.
Future<void> drain() => Future<void>.delayed(Duration.zero);

/// A [WidgetBridge] whose every call throws, to exercise the failure path.
class ThrowingWidgetBridge implements WidgetBridge {
  @override
  Future<void> save(String key, Object value) async =>
      throw const FormatException('bridge down');

  @override
  Future<void> update() async => throw const FormatException('bridge down');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final u = DateTime.utc(2026);
  DateTime d(int day) => DateTime(2026, 8, day);
  final goal = Goal(
      id: 'g',
      name: 'G',
      type: GoalType.check,
      createdAt: d(1),
      archivedAt: null,
      updatedAt: u);

  Future<(AppStore, SettingsStore, FakeWidgetBridge, WidgetSyncService)> boot({
    List<DayEntry> entries = const [],
    Map<String, Object> prefs = const {},
  }) async {
    SharedPreferences.setMockInitialValues({'nickname': 'Alvaro', ...prefs});
    final p = await SharedPreferences.getInstance();
    final store = AppStore(
        InMemoryGoalsRepository(AppData(goals: [goal], entries: entries)));
    await store.load();
    final settings = SettingsStore(SettingsRepository(p));
    final bridge = FakeWidgetBridge();
    final service = WidgetSyncService(
      bridge: bridge,
      store: store,
      settings: settings,
      now: () => DateTime(2026, 8, 17, 9),
    );
    await service.start();
    return (store, settings, bridge, service);
  }

  test('start publishes a snapshot', () async {
    final (_, _, bridge, _) = await boot();
    expect(bridge.updates, 1);
    expect(bridge.data['nickname'], 'Alvaro');
    expect(bridge.data['todayDone'], isFalse);
  });

  test('a store change republishes', () async {
    final (store, _, bridge, _) = await boot();
    await store.saveDay(d(17), {'g': 100});
    await drain();
    expect(bridge.updates, 2);
    expect(bridge.data['todayDone'], isTrue);
  });

  test('a settings change republishes', () async {
    final (_, settings, bridge, _) = await boot();
    await settings.setNickname('Bea');
    await drain();
    expect(bridge.updates, 2);
    expect(bridge.data['nickname'], 'Bea');
  });

  test('dispose detaches from the stores', () async {
    final (store, _, bridge, service) = await boot();
    service.dispose();
    final before = bridge.updates;
    await store.saveDay(d(17), {'g': 100});
    await drain();
    expect(bridge.updates, before);
  });

  test('a bridge failure is logged and does not throw', () async {
    SharedPreferences.setMockInitialValues({'nickname': 'Alvaro'});
    final p = await SharedPreferences.getInstance();
    final store = AppStore(
        InMemoryGoalsRepository(AppData(goals: [goal], entries: const [])));
    await store.load();
    final settings = SettingsStore(SettingsRepository(p));
    final service = WidgetSyncService(
      bridge: ThrowingWidgetBridge(),
      store: store,
      settings: settings,
      now: () => DateTime(2026, 8, 17, 9),
    );
    await expectLater(service.start(), completes);
    await expectLater(service.sync(), completes);
  });
}
