import '../models/app_data.dart';
import 'goals_repository.dart';

/// Test double and a convenient seed for widget tests.
class InMemoryGoalsRepository implements GoalsRepository {
  AppData? stored;
  AppData? undo;
  int saves = 0;

  InMemoryGoalsRepository([this.stored]);

  @override
  Future<bool> exists() async => stored != null;
  @override
  Future<AppData> load() async => stored ?? AppData.empty;
  @override
  Future<void> save(AppData data) async {
    stored = data;
    saves++;
    undo = null;
  }

  @override
  Future<void> moveToUndo() async {
    undo = stored;
    stored = null;
  }

  @override
  Future<bool> restoreFromUndo() async {
    if (undo == null) return false;
    stored = undo;
    undo = null;
    return true;
  }

  @override
  Future<void> purgeUndo() async => undo = null;
}
