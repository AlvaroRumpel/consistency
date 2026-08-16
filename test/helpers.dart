import 'package:consistency/data/in_memory_goals_repository.dart';
import 'package:consistency/data/settings_repository.dart';
import 'package:consistency/main.dart';
import 'package:consistency/models/app_data.dart';
import 'package:consistency/state/app_store.dart';
import 'package:consistency/state/settings_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The whole app over in-memory storage, already loaded.
Future<ConsistencyApp> buildApp({
  Map<String, Object> prefs = const {},
  AppData? data,
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final p = await SharedPreferences.getInstance();
  final store = AppStore(InMemoryGoalsRepository(data));
  await store.load();
  return ConsistencyApp(
    settings: SettingsStore(SettingsRepository(p)),
    store: store,
  );
}
