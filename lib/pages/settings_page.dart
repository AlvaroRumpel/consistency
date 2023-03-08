import 'package:consistency/configs/colors.dart';
import 'package:consistency/configs/exceptions/local_data_exception.dart';
import 'package:consistency/configs/messages_mixin.dart';
import 'package:consistency/configs/text_styles.dart';
import 'package:consistency/controllers/settings_controller.dart';
import 'package:consistency/providers/theme_provider.dart';
import 'package:consistency/widgets/list_tile_custom.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> with MessagesMixin {
  late SettingsController controller;

  @override
  void initState() {
    controller = SettingsController();
    super.initState();
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
                    'Hello, ',
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
                        valueListenable: controller.nickname,
                        builder: (context, value, _) {
                          return Text(
                            value,
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
          SliverFillRemaining(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                ValueListenableBuilder(
                    valueListenable: controller.nickname,
                    builder: (context, value, _) {
                      return ListTileCustom(
                        onTap: () async {
                          controller.nickname.value =
                              await _changeNicknameBottomSheet(context) ??
                                  value;
                        },
                        top: true,
                        title: 'Change your nickname, $value',
                      );
                    }),
                ListTileCustom(
                  onTap: () => _aboutTheAppDialog(context),
                  title: 'About the app',
                ),
                ListTileCustom(
                  onTap: () => _confirmDialog(context),
                  title: 'Delete all data',
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
                  title: 'Send your opinion',
                ),
                ValueListenableBuilder(
                  valueListenable: controller.themeDark,
                  builder: (context, themeDark, _) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Icon(
                            themeDark
                                ? Icons.light_mode_outlined
                                : Icons.light_mode_rounded,
                            color: themeDark
                                ? AppColors.primaryColor
                                : AppColors.blackColor,
                          ),
                          const SizedBox(width: 8),
                          Switch(
                            thumbColor:
                                MaterialStateProperty.resolveWith<Color>(
                              (states) {
                                if (states.contains(MaterialState.selected)) {
                                  return AppColors.blackColor;
                                }
                                return AppColors.whiteColor.shade700;
                              },
                            ),
                            trackColor:
                                MaterialStateProperty.resolveWith<Color>(
                              (states) {
                                if (states.contains(MaterialState.selected)) {
                                  return AppColors.primaryColor;
                                }
                                return AppColors.primaryColor.shade100;
                              },
                            ),
                            value: themeDark,
                            onChanged: (value) {
                              controller.changeTheme(value);
                              ThemeProvider.of(context).switchThemeMode();
                            },
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            themeDark
                                ? Icons.dark_mode_rounded
                                : Icons.dark_mode_outlined,
                            color: themeDark
                                ? AppColors.primaryColor
                                : AppColors.blackColor,
                          ),
                        ],
                      ),
                    );
                  },
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

  Future<String?> _changeNicknameBottomSheet(BuildContext context) async {
    final formKey = GlobalKey<FormState>();
    final nicknameEC = TextEditingController(
        text: controller.nickname.value != 'User'
            ? controller.nickname.value
            : '');

    await showModalBottomSheet<String>(
      backgroundColor: ThemeProvider.of(context).themeMode == ThemeMode.dark
          ? AppColors.blackColor
          : AppColors.whiteColor.shade700,
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
                  cursorColor:
                      ThemeProvider.of(context).themeMode == ThemeMode.dark
                          ? AppColors.whiteColor.shade50
                          : AppColors.blackColor,
                  decoration: InputDecoration(
                    label: Text(
                      'Nickname',
                      style: context.textStyles.normalText,
                    ),
                  ),
                  validator: (value) => value == null || value.isEmpty
                      ? 'Value cannot be empty'
                      : null,
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (formKey.currentState?.validate() ?? false) {
                      Navigator.pop(context);
                      try {
                        await controller.localData
                            .saveNickname(nicknameEC.text);
                      } on LocalDataException catch (e) {
                        showError(e.message);
                      }
                    }
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Update nickname',
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

    return formKey.currentState?.validate() ?? false ? nicknameEC.text : null;
  }

  Future<void> _confirmDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          insetPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 24),
          titlePadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          actionsPadding:
              const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          backgroundColor:
              ThemeProvider.of(context).themeMode == ThemeMode.light
                  ? AppColors.whiteColor.shade50
                  : AppColors.blackColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          title: Text(
            'Are you sure?',
            style: context.textStyles.normalText.copyWith(fontSize: 24),
            textAlign: TextAlign.center,
          ),
          content: Text(
            'All of your data will be lost!\nAre you sure?',
            style: context.textStyles.normalText,
          ),
          actions: [
            OutlinedButton(
              onPressed: () async {
                Navigator.pop(context);
                await controller.clearAllData();
                showMessageUndo(
                  message: 'Click here to undo the deletion',
                  onTap: controller.undoClearAllData,
                );
              },
              style: OutlinedButton.styleFrom(
                side: const BorderSide(
                  color: AppColors.redColor,
                ),
              ),
              child: Text(
                "Yes! I'm Sure",
                style: context.textStyles.normalText
                    .copyWith(color: AppColors.redColor),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                "Noooo!",
                style: context.textStyles.normalText
                    .copyWith(color: AppColors.whiteColor),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _aboutTheAppDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          insetPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 24),
          titlePadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          backgroundColor:
              ThemeProvider.of(context).themeMode == ThemeMode.light
                  ? AppColors.whiteColor.shade50
                  : AppColors.blackColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          title: Text(
            'About the app',
            style: context.textStyles.normalText.copyWith(fontSize: 24),
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Consistency is a simple app, it consists of marking, saving and numbering the days that you have completed your personal daily goals, I hope you enjoy and understand the purpose of the app, any questions you can forward to support.',
                style: context.textStyles.normalText,
                textAlign: TextAlign.justify,
              ),
              const SizedBox(
                height: 16,
              ),
              Text(
                'Made with ♥ by Álvaro Rumpel',
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
