import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../configs/l10n_ext.dart';
import '../data/backup_service.dart';
import '../models/date_key.dart';
import '../state/app_store.dart';

/// Shares the raw data file straight off disk, even when it's corrupt — the
/// last resort offered from the error screen when the app can't parse it.
Future<void> exportRawFile(BuildContext context) async {
  final store = context.read<AppStore>();
  final raw = await store.readRaw();
  if (!context.mounted) return;

  if (raw == null || raw.isEmpty) {
    _snack(context, context.l10n.rawExportEmpty);
    return;
  }

  final backups = context.read<BackupService>();
  try {
    await backups.exportBackup(
      'consistency-raw-${dateKey(DateTime.now())}.json',
      raw,
    );
    if (!context.mounted) return;
    _snack(context, context.l10n.rawExportReady);
  } catch (e, s) {
    debugPrint('exportRawFile failed: $e\n$s');
    if (!context.mounted) return;
    _snack(context, context.l10n.couldNotExportRaw, error: true);
  }
}

void _snack(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(message),
    backgroundColor: error ? Theme.of(context).colorScheme.error : null,
  ));
}
