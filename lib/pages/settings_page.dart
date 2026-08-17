import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../configs/colors.dart';
import '../configs/l10n_ext.dart';
import '../configs/messages_mixin.dart';
import '../configs/text_styles.dart';
import '../controllers/settings_controller.dart';
import '../data/backup_codec.dart';
import '../data/backup_service.dart';
import '../models/app_data.dart';
import '../notifications/reminder_service.dart';
import '../state/app_store.dart';
import '../state/settings_store.dart';
import '../widgets/error_view.dart';
import '../widgets/import_dialog.dart';
import '../widgets/list_tile_custom.dart';
import 'archived_goals_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> with MessagesMixin {
  late SettingsController _controller;
  // One flag for both backup flows: neither should run twice, nor at the
  // same time as the other.
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _controller = SettingsController(
      context.read<AppStore>(),
      context.read<SettingsStore>(),
    );
  }

  @override
  void dispose() {
    _controller.onDispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    context.l10n.hello,
                    style: context.textStyles.titleText,
                  ),
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 4,
                        horizontal: 16,
                      ),
                      decoration: BoxDecoration(
                        shape: BoxShape.rectangle,
                        border: Border.all(
                          color: AppColors.primaryColor,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: ValueListenableBuilder(
                        valueListenable: _controller.stateNotifier,
                        builder: (context, value, _) {
                          return Text(
                            value is SettingData ? value.nickname : '...',
                            style: context.textStyles.titleText,
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                ValueListenableBuilder(
                  valueListenable: _controller.stateNotifier,
                  builder: (context, value, _) => value is SettingError
                      ? SizedBox(
                          width: double.infinity,
                          child: ErrorView(
                            message: value.message,
                            onRetry: _controller.reload,
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
                ValueListenableBuilder(
                    valueListenable: _controller.stateNotifier,
                    builder: (context, value, _) {
                      return ListTileCustom(
                        onTap: () async {
                          final nickname = await _changeNicknameBottomSheet(
                            context,
                            (value is SettingData ? value.nickname : 'User'),
                          );

                          _controller.saveNickname(nickname);
                        },
                        top: true,
                        title: context.l10n.changeNickname(
                            value is SettingData ? value.nickname : 'User'),
                      );
                    }),
                ListTileCustom(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const ArchivedGoalsPage()),
                  ),
                  title: context.l10n.archivedGoals(context
                      .watch<AppStore>()
                      .data
                      .goals
                      .where((g) => g.isArchived)
                      .length),
                ),
                ListTileCustom(
                  onTap: () => _aboutTheAppDialog(context),
                  title: context.l10n.aboutTheApp,
                ),
                ListTileCustom(
                  onTap: () => _exportBackup(context),
                  title: context.l10n.exportBackup,
                ),
                ListTileCustom(
                  onTap: () => _importBackup(context),
                  title: context.l10n.importBackup,
                ),
                ListTileCustom(
                  onTap: () => _confirmDialog(context),
                  title: context.l10n.deleteAllData,
                ),
                ListTileCustom(
                  onTap: () {
                    launchUrl(
                      Uri(
                        scheme: 'mailto',
                        path: 'alvaroRumpel@gmail.com',
                        query: _encodeQueryParameters(
                          <String, String>{
                            'subject': 'Consistency App Opinion',
                          },
                        ),
                      ),
                    );
                  },
                  title: context.l10n.sendOpinion,
                ),
                const _ThresholdSlider(),
                const _ReminderSection(),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: SegmentedButton<ThemeMode>(
                    segments: [
                      ButtonSegment(
                        value: ThemeMode.system,
                        label: Text(context.l10n.themeSystem),
                        icon: const Icon(Icons.brightness_auto_outlined),
                      ),
                      ButtonSegment(
                        value: ThemeMode.light,
                        label: Text(context.l10n.themeLight),
                        icon: const Icon(Icons.light_mode_outlined),
                      ),
                      ButtonSegment(
                        value: ThemeMode.dark,
                        label: Text(context.l10n.themeDark),
                        icon: const Icon(Icons.dark_mode_outlined),
                      ),
                    ],
                    selected: {context.watch<SettingsStore>().themeMode},
                    onSelectionChanged: (s) =>
                        context.read<SettingsStore>().setThemeMode(s.first),
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  String? _encodeQueryParameters(Map<String, String> params) {
    return params.entries
        .map((MapEntry<String, String> e) =>
            '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
  }

  Future<String?> _changeNicknameBottomSheet(
    BuildContext context,
    String previousName,
  ) async {
    final formKey = GlobalKey<FormState>();
    final nicknameEC = TextEditingController(
      text: previousName != 'User' ? previousName : '',
    );

    return await showModalBottomSheet<String>(
      backgroundColor: Theme.of(context).cardColor,
      context: context,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: formKey,
            child: Column(
              children: [
                TextFormField(
                  maxLength: 25,
                  controller: nicknameEC,
                  style: context.textStyles.normalText,
                  cursorColor: Theme.of(context).textSelectionTheme.cursorColor,
                  decoration: InputDecoration(
                    label: Text(
                      context.l10n.nicknameLabel,
                      style: context.textStyles.normalText,
                    ),
                  ),
                  validator: (value) => value == null || value.isEmpty
                      ? context.l10n.valueCannotBeEmpty
                      : null,
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (formKey.currentState?.validate() ?? false) {
                      Navigator.pop(context, nicknameEC.text);
                    }
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        context.l10n.updateNickname,
                        style: context.textStyles.normalText
                            .copyWith(color: AppColors.whiteColor),
                      ),
                      const Icon(
                        Icons.save_outlined,
                        color: AppColors.whiteColor,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmDialog(BuildContext context) async {
    final undoMessage = context.l10n.undoDeletion;
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          insetPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 24),
          titlePadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          actionsPadding:
              const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          backgroundColor: Theme.of(context).cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          title: Text(
            context.l10n.areYouSure,
            style: context.textStyles.normalText.copyWith(fontSize: 24),
            textAlign: TextAlign.center,
          ),
          content: Text(
            context.l10n.dataWillBeLost,
            style: context.textStyles.normalText,
          ),
          actions: [
            OutlinedButton(
              onPressed: () async {
                Navigator.pop(context);
                await _controller.clearAllData();
                showMessageUndo(
                  message: undoMessage,
                  onTap: _controller.undoClearAllData,
                );
              },
              style: OutlinedButton.styleFrom(
                side: const BorderSide(
                  color: AppColors.redColor,
                ),
              ),
              child: Text(
                context.l10n.yesImSure,
                style: context.textStyles.normalText
                    .copyWith(color: AppColors.redColor),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                context.l10n.noooo,
                style: context.textStyles.normalText
                    .copyWith(color: AppColors.whiteColor),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _exportBackup(BuildContext context) async {
    if (_busy) return;
    _busy = true;
    final store = context.read<AppStore>();
    final backups = context.read<BackupService>();
    try {
      await backups.exportBackup(
        BackupCodec.fileName(DateTime.now()),
        BackupCodec.encode(store.data),
      );
      if (!context.mounted) return;
      _snack(context, context.l10n.backupReady);
    } catch (e, s) {
      debugPrint('exportBackup failed: $e\n$s');
      if (!context.mounted) return;
      _snack(context, context.l10n.couldNotExport, error: true);
    } finally {
      _busy = false;
    }
  }

  Future<void> _importBackup(BuildContext context) async {
    if (_busy) return;
    _busy = true;
    try {
      await _import(context);
    } finally {
      _busy = false;
    }
  }

  Future<void> _import(BuildContext context) async {
    final backups = context.read<BackupService>();
    final PickedBackup? result;
    try {
      result = await backups.pickBackup();
    } catch (e, s) {
      // The picker is platform code: it throws PlatformException on a denied
      // permission, FormatException on undecodable bytes, and more.
      debugPrint('pickBackup failed: $e\n$s');
      if (!context.mounted) return;
      _snack(context, context.l10n.couldNotReadFile, error: true);
      return;
    }
    if (result == null || !context.mounted) return;
    // Rebound so the non-null type survives into the dialog builder below.
    final picked = result;

    final AppData imported;
    try {
      imported = BackupCodec.decode(picked.contents);
    } on FormatException {
      if (!context.mounted) return;
      _snack(context, context.l10n.notABackup, error: true);
      return;
    }

    final store = context.read<AppStore>();
    final choice = await showDialog<ImportChoice>(
      context: context,
      builder: (_) => ImportDialog(
        fileName: picked.name,
        summary: BackupCodec.summarize(imported),
      ),
    );
    if (choice == null || !context.mounted) return;

    await store.replaceAll(choice == ImportChoice.replace
        ? imported
        : BackupCodec.merge(store.data, imported));
    if (!context.mounted) return;
    _snack(
      context,
      store.saveError == null
          ? context.l10n.backupImported
          : context.l10n.backupImportedButSaveFailed,
      error: store.saveError != null,
    );
  }

  void _snack(BuildContext context, String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: error ? Theme.of(context).colorScheme.error : null,
    ));
  }

  Future<void> _aboutTheAppDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          insetPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 24),
          titlePadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          backgroundColor: Theme.of(context).cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          title: Text(
            context.l10n.aboutTheApp,
            style: context.textStyles.normalText.copyWith(fontSize: 24),
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                context.l10n.aboutBody,
                style: context.textStyles.normalText,
                textAlign: TextAlign.justify,
              ),
              const SizedBox(
                height: 16,
              ),
              Text(
                context.l10n.madeWithLove,
                style: context.textStyles.normalText.copyWith(fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ThresholdSlider extends StatefulWidget {
  const _ThresholdSlider();

  @override
  State<_ThresholdSlider> createState() => _ThresholdSliderState();
}

class _ThresholdSliderState extends State<_ThresholdSlider> {
  double? _dragging;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<SettingsStore>();
    final t = (_dragging ?? store.threshold).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(context.l10n.dailyTarget(t), style: context.textStyles.normalText),
        Slider(
          value: _dragging ?? store.threshold.toDouble(),
          min: 0,
          max: 100,
          divisions: 20,
          label: '$t%',
          onChanged: (v) => setState(() => _dragging = v),
          onChangeEnd: (v) {
            context.read<SettingsStore>().setThreshold(v.round());
            setState(() => _dragging = null);
          },
        ),
        Text(
          context.l10n.thresholdCaption,
          style: context.textStyles.thinText.copyWith(fontSize: 12),
          textAlign: TextAlign.end,
        ),
      ],
    );
  }
}

class _ReminderSection extends StatelessWidget {
  const _ReminderSection();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsStore>();
    final enabled = settings.notifEnabled;
    final (hour, minute) = settings.notifTime;
    final time =
        '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child:
              Text(context.l10n.reminder, style: context.textStyles.boldText),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Switch(
              value: enabled,
              onChanged: (v) => v
                  ? _enable(context)
                  : context.read<ReminderService>().disable(),
            ),
            Text(context.l10n.dailyReminder,
                style: context.textStyles.normalText),
          ],
        ),
        Opacity(
          opacity: enabled ? 1 : 0.4,
          child: IgnorePointer(
            ignoring: !enabled,
            child: InkWell(
              onTap: () => _pickTime(context, hour, minute),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(time, style: context.textStyles.normalText),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.arrow_forward_ios,
                          color: Theme.of(context).colorScheme.onSurface,
                          size: 16,
                        ),
                      ],
                    ),
                    Text(context.l10n.time,
                        style: context.textStyles.normalText),
                  ],
                ),
              ),
            ),
          ),
        ),
        Text(
          context.l10n.reminderCaption,
          style: context.textStyles.thinText.copyWith(fontSize: 12),
          textAlign: TextAlign.end,
        ),
      ],
    );
  }

  Future<void> _enable(BuildContext context) async {
    final message = context.l10n.notificationsBlocked;
    final ok = await context.read<ReminderService>().enable();
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ));
    }
  }

  Future<void> _pickTime(BuildContext context, int hour, int minute) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: hour, minute: minute),
    );
    if (picked == null || !context.mounted) return;
    await context
        .read<SettingsStore>()
        .setNotifTime(picked.hour, picked.minute);
  }
}
