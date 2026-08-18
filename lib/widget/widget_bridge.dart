/// Write side of the Android home-screen widget. Pure interface — no
/// plugin import here, so the engine/publisher stay testable without a
/// platform channel. The real (home_widget-backed) implementation lands
/// in a later task.
abstract class WidgetBridge {
  Future<void> save(String key, Object value);

  /// Asks Android to redraw both widget sizes.
  Future<void> update();
}
