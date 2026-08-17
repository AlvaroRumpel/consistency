import 'backup_service.dart';

/// In-memory [BackupService] for tests: records the export instead of
/// touching the OS, and returns a queued pick instead of opening a picker.
class FakeBackupService implements BackupService {
  PickedBackup? nextPick;
  String? lastExportName;
  String? lastExportContents;
  bool throwOnPick = false;
  bool throwOnExport = false;

  @override
  Future<void> exportBackup(String fileName, String contents) async {
    if (throwOnExport) throw StateError('exportBackup failed');
    lastExportName = fileName;
    lastExportContents = contents;
  }

  @override
  Future<PickedBackup?> pickBackup() async {
    if (throwOnPick) throw StateError('pickBackup failed');
    return nextPick;
  }
}
