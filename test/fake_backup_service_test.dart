import 'package:consistency/data/backup_service.dart';
import 'package:consistency/data/fake_backup_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('exportBackup records the file name and contents', () async {
    final service = FakeBackupService();
    await service.exportBackup('consistency-2026-08-17.json', '{"a":1}');
    expect(service.lastExportName, 'consistency-2026-08-17.json');
    expect(service.lastExportContents, '{"a":1}');
  });

  test('pickBackup returns the queued pick', () async {
    final service = FakeBackupService()
      ..nextPick = const PickedBackup(name: 'backup.json', contents: '{}');
    final picked = await service.pickBackup();
    expect(picked!.name, 'backup.json');
    expect(picked.contents, '{}');
  });

  test('pickBackup returns null when nothing is queued (user cancelled)',
      () async {
    final service = FakeBackupService();
    expect(await service.pickBackup(), isNull);
  });

  test('pickBackup throws when throwOnPick is set', () async {
    final service = FakeBackupService()..throwOnPick = true;
    expect(() => service.pickBackup(), throwsA(anything));
  });
}
