import '../models/app_data.dart';

/// Persistence boundary. Swap the implementation (file today, cloud later)
/// without touching the store or the UI.
abstract class GoalsRepository {
  Future<bool> exists();
  Future<AppData> load();
  Future<String?> readRaw();
  Future<void> save(AppData data);
  Future<void> moveToUndo();
  Future<bool> restoreFromUndo();
  Future<void> purgeUndo();
}
