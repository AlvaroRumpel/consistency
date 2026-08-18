import 'package:consistency/data/fake_backup_service.dart';
import 'package:consistency/data/in_memory_goals_repository.dart';
import 'package:consistency/models/app_data.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// A repository whose load() always fails, so the error screen (and its
/// export-raw button) shows up regardless of what readRaw() returns.
class _LoadThrows extends InMemoryGoalsRepository {
  @override
  Future<AppData> load() async => throw const FormatException('boom');
}

void main() {
  testWidgets(
      'error screen offers raw export and hands the corrupt bytes to the '
      'backup service', (tester) async {
    final repo = _LoadThrows()..rawOverride = '{corrupt';
    final backups = FakeBackupService();
    await tester.pumpWidget(await buildApp(repo: repo, backups: backups));
    // Two rounds: the first only gets us mid-way through the splash→home
    // route transition, and a snackbar shown before it settles renders in
    // both the outgoing and incoming Scaffold.
    await pumpFrames(tester);
    await pumpFrames(tester);

    expect(find.text('Try again'), findsOneWidget);
    expect(find.text('Export raw file'), findsOneWidget);

    await tester.tap(find.text('Export raw file'));
    await pumpFrames(tester);

    expect(backups.lastExportContents, '{corrupt');
    expect(
      backups.lastExportName,
      matches(RegExp(r'^consistency-raw-\d{4}-\d{2}-\d{2}\.json$')),
    );
    expect(find.text('Raw file ready to share.'), findsOneWidget);
  });

  testWidgets('nothing to export when readRaw comes back empty',
      (tester) async {
    final repo = _LoadThrows();
    final backups = FakeBackupService();
    await tester.pumpWidget(await buildApp(repo: repo, backups: backups));
    await pumpFrames(tester);
    await pumpFrames(tester);

    await tester.tap(find.text('Export raw file'));
    await pumpFrames(tester);

    expect(backups.lastExportContents, isNull);
    expect(find.text("There's nothing to export."), findsOneWidget);
  });
}
