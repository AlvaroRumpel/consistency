import 'package:consistency/configs/theme.dart';
import 'package:consistency/data/in_memory_goals_repository.dart';
import 'package:consistency/data/settings_repository.dart';
import 'package:consistency/main.dart';
import 'package:consistency/models/app_data.dart';
import 'package:consistency/state/app_store.dart';
import 'package:consistency/state/settings_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A repository that loads fine but can never write.
class SaveThrowsRepository extends InMemoryGoalsRepository {
  SaveThrowsRepository([super.stored]);

  @override
  Future<void> save(AppData data) async =>
      throw const FormatException('disk full');
}

Future<(SettingsStore, AppStore)> _stores(
    Map<String, Object> prefs, AppData? data, bool failSaves) async {
  SharedPreferences.setMockInitialValues(prefs);
  final p = await SharedPreferences.getInstance();
  final store = AppStore(
      failSaves ? SaveThrowsRepository(data) : InMemoryGoalsRepository(data));
  await store.load();
  return (SettingsStore(SettingsRepository(p)), store);
}

/// The whole app over in-memory storage, already loaded.
Future<ConsistencyApp> buildApp({
  Map<String, Object> prefs = const {},
  AppData? data,
  bool failSaves = false,
}) async {
  final (settings, store) = await _stores(prefs, data, failSaves);
  return ConsistencyApp(settings: settings, store: store);
}

/// One page under the same providers and theme as [buildApp].
Future<Widget> wrap(
  Widget child, {
  Map<String, Object> prefs = const {},
  AppData? data,
}) async {
  final (settings, store) = await _stores(prefs, data, false);
  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: settings),
      ChangeNotifierProvider.value(value: store),
    ],
    child: MaterialApp(theme: themeLight, home: child),
  );
}

Future<void> pumpFrames(WidgetTester tester, [int n = 10]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}
