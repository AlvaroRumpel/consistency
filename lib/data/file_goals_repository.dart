import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/app_data.dart';
import 'goals_repository.dart';

class FileGoalsRepository implements GoalsRepository {
  final Directory dir;
  Future<void> _chain = Future.value();

  FileGoalsRepository(this.dir);

  static Future<FileGoalsRepository> open() async =>
      FileGoalsRepository(await getApplicationDocumentsDirectory());

  File get _main => File('${dir.path}/consistency.json');
  File get _tmp => File('${dir.path}/consistency.json.tmp');
  File get _bak => File('${dir.path}/consistency.json.bak');
  File get _deleted => File('${dir.path}/consistency.json.deleted');

  @override
  Future<bool> exists() => _main.exists();

  @override
  Future<AppData> load() async {
    final fromMain = await _tryRead(_main);
    if (fromMain != null) return fromMain;
    final fromBak = await _tryRead(_bak);
    if (fromBak != null) return fromBak;
    if (await _main.exists()) {
      throw const FormatException(
          'consistency.json unreadable and no valid .bak');
    }
    return AppData.empty;
  }

  Future<AppData?> _tryRead(File f) async {
    if (!await f.exists()) return null;
    try {
      final j = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      return AppData.fromJson(j);
    } catch (_) {
      // Any parse or shape failure (bad JSON, wrong schema, unknown enum
      // value via GoalType.values.byName, etc.) means this file is
      // unreadable — fall through to the next candidate.
      return null;
    }
  }

  /// Serializes disk operations. A failed op still surfaces to its caller,
  /// but never poisons the queue for the next one.
  Future<T> _enqueue<T>(Future<T> Function() op) {
    final next = _chain.then((_) => op(), onError: (_, __) => op());
    _chain = next.then((_) {}, onError: (_, __) {});
    return next;
  }

  @override
  Future<void> save(AppData data) => _enqueue(() => _save(data));

  Future<void> _save(AppData data) async {
    await dir.create(recursive: true);
    await _tmp.writeAsString(jsonEncode(data.toJson()), flush: true);
    if (await _main.exists()) {
      // Keep the last good file; overwrite any older backup.
      if (await _bak.exists()) await _bak.delete();
      await _main.rename(_bak.path);
    }
    await _tmp.rename(_main.path);
    // Call the unserialized body directly: the public purgeUndo() would
    // enqueue onto the queue this call is already running in, and deadlock.
    await _purgeUndo();
  }

  @override
  Future<void> moveToUndo() => _enqueue(_moveToUndo);

  Future<void> _moveToUndo() async {
    if (!await _main.exists()) return;
    if (await _deleted.exists()) await _deleted.delete();
    if (await _bak.exists()) await _bak.delete();
    await _main.rename(_deleted.path);
  }

  @override
  Future<bool> restoreFromUndo() => _enqueue(_restoreFromUndo);

  Future<bool> _restoreFromUndo() async {
    if (!await _deleted.exists()) return false;
    await _deleted.rename(_main.path);
    return true;
  }

  @override
  Future<void> purgeUndo() => _enqueue(_purgeUndo);

  Future<void> _purgeUndo() async {
    if (await _deleted.exists()) await _deleted.delete();
  }
}
