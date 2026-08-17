import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// A backup file the user picked to import, already decoded to text.
class PickedBackup {
  final String name;
  final String contents;
  const PickedBackup({required this.name, required this.contents});
}

/// Platform I/O for backup export/import, kept free of app-state.
abstract class BackupService {
  /// Writes [contents] to a temp file named [fileName] and opens the share sheet.
  Future<void> exportBackup(String fileName, String contents);

  /// Opens the file picker; null when the user cancels.
  Future<PickedBackup?> pickBackup();
}

/// Wraps share_plus (export) and file_picker (import).
class PlatformBackupService implements BackupService {
  @override
  Future<void> exportBackup(String fileName, String contents) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(contents, flush: true);
    // share_plus 10.x: the SharePlus.instance/ShareParams API arrived in 11.x.
    await Share.shareXFiles([XFile(file.path)], fileNameOverrides: [fileName]);
  }

  @override
  Future<PickedBackup?> pickBackup() async {
    final result =
        await FilePicker.platform.pickFiles(type: FileType.any, withData: true);
    if (result == null) return null;
    final f = result.files.single;
    return PickedBackup(name: f.name, contents: utf8.decode(f.bytes!));
  }
}
