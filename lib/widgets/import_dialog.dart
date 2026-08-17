import 'package:flutter/material.dart';

import '../configs/colors.dart';
import '../configs/l10n_ext.dart';
import '../configs/text_styles.dart';
import '../data/backup_codec.dart';

enum ImportChoice { replace, merge }

/// Confirms how to apply a picked backup: replace everything or merge it
/// with the current data. Returns the chosen [ImportChoice], or null if the
/// user cancels.
class ImportDialog extends StatefulWidget {
  final String fileName;
  final BackupSummary summary;

  const ImportDialog(
      {super.key, required this.fileName, required this.summary});

  @override
  State<ImportDialog> createState() => _ImportDialogState();
}

class _ImportDialogState extends State<ImportDialog> {
  ImportChoice _choice = ImportChoice.merge;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 24),
      titlePadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      actionsPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      backgroundColor: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      title: Text(
        context.l10n.importBackupTitle,
        style: context.textStyles.normalText.copyWith(fontSize: 24),
        textAlign: TextAlign.center,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${widget.fileName} · '
            '${context.l10n.backupSummary(widget.summary.goals, widget.summary.days)}',
            style: context.textStyles.thinText,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          _OptionTile(
            title: context.l10n.replaceOption,
            selected: _choice == ImportChoice.replace,
            onTap: () => setState(() => _choice = ImportChoice.replace),
          ),
          _OptionTile(
            title: context.l10n.mergeOption,
            selected: _choice == ImportChoice.merge,
            onTap: () => setState(() => _choice = ImportChoice.merge),
          ),
        ],
      ),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.pop(context),
          child:
              Text(context.l10n.cancel, style: context.textStyles.normalText),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _choice),
          child: Text(context.l10n.import),
        ),
      ],
    );
  }
}

class _OptionTile extends StatelessWidget {
  final String title;
  final bool selected;
  final VoidCallback onTap;

  const _OptionTile({
    required this.title,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? AppColors.primaryColor
                : Theme.of(context).dividerColor,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected
                  ? AppColors.primaryColor
                  : Theme.of(context).colorScheme.onSurface,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(title, style: context.textStyles.normalText)),
          ],
        ),
      ),
    );
  }
}
