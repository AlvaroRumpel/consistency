import 'widget_bridge.dart';

/// In-memory [WidgetBridge] for tests.
class FakeWidgetBridge implements WidgetBridge {
  final Map<String, Object> data = {};
  int updates = 0;

  @override
  Future<void> save(String key, Object value) async {
    data[key] = value;
  }

  @override
  Future<void> update() async {
    updates++;
  }
}
