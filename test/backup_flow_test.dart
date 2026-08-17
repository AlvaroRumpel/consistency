import 'package:consistency/data/backup_codec.dart';
import 'package:consistency/data/backup_service.dart';
import 'package:consistency/data/fake_backup_service.dart';
import 'package:consistency/models/app_data.dart';
import 'package:consistency/models/day_entry.dart';
import 'package:consistency/models/goal.dart';
import 'package:consistency/pages/settings_page.dart';
import 'package:consistency/state/app_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'helpers.dart';

Goal _goal(String id) => Goal(
      id: id,
      name: id,
      type: GoalType.check,
      createdAt: DateTime(2026, 8, 1),
      archivedAt: null,
      updatedAt: DateTime.utc(2026, 8, 1),
    );

DayEntry _entry(int day) => DayEntry(
    date: DateTime(2026, 8, day),
    values: const {},
    updatedAt: DateTime.utc(2026, 8, day));

// 2 goals, 3 days — matches the summary the dialog is expected to show.
AppData _backupData() => AppData(
      goals: [_goal('a'), _goal('b')],
      entries: [_entry(1), _entry(2), _entry(3)],
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('valid backup: dialog shows the summary, Replace swaps the store',
      (tester) async {
    final backups = FakeBackupService()
      ..nextPick = PickedBackup(
        name: 'their-backup.json',
        contents: BackupCodec.encode(_backupData()),
      );
    final app = await buildApp(backups: backups);
    await tester.pumpWidget(app);
    await pumpFrames(tester);
    await tester.tap(find.text('Settings'));
    await pumpFrames(tester);

    await tester.tap(find.text('Import backup'));
    await pumpFrames(tester);

    expect(find.textContaining('2 goals · 3 days'), findsOneWidget);

    await tester.tap(find.text('Import'));
    await pumpFrames(tester);

    final store = tester.element(find.byType(SettingsPage)).read<AppStore>();
    expect(store.data.goals.map((g) => g.id).toSet(), {'a', 'b'});
    expect(store.data.entries.length, 3);
    expect(find.text('Backup imported.'), findsOneWidget);
  });

  testWidgets('invalid file: error snackbar, store unchanged', (tester) async {
    final backups = FakeBackupService()
      ..nextPick =
          const PickedBackup(name: 'not-a-backup.txt', contents: 'nope');
    final app = await buildApp(backups: backups);
    await tester.pumpWidget(app);
    await pumpFrames(tester);
    await tester.tap(find.text('Settings'));
    await pumpFrames(tester);

    final store = tester.element(find.byType(SettingsPage)).read<AppStore>();
    final before = store.data;

    await tester.tap(find.text('Import backup'));
    await pumpFrames(tester);

    expect(find.text("That file isn't a Consistency backup."), findsOneWidget);
    expect(store.data, same(before));
  });

  testWidgets('export writes the dated file with the store contents',
      (tester) async {
    final backups = FakeBackupService();
    final app = await buildApp(data: _backupData(), backups: backups);
    await tester.pumpWidget(app);
    await pumpFrames(tester);
    await tester.tap(find.text('Settings'));
    await pumpFrames(tester);

    await tester.tap(find.text('Export backup'));
    await pumpFrames(tester);

    expect(backups.lastExportName, BackupCodec.fileName(DateTime.now()));
    final decoded = BackupCodec.decode(backups.lastExportContents!);
    expect(decoded.goals.map((g) => g.id).toSet(), {'a', 'b'});
    expect(decoded.entries.length, 3);
    expect(find.text('Backup ready to share.'), findsOneWidget);
  });
}
