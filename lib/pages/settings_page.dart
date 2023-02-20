import 'package:consistency/configs/colors.dart';
import 'package:consistency/configs/exceptions/local_data_exception.dart';
import 'package:consistency/configs/messages_mixin.dart';
import 'package:consistency/configs/text_styles.dart';
import 'package:consistency/controllers/settings_controller.dart';
import 'package:consistency/widgets/list_tile_custom.dart';
import 'package:flutter/material.dart';

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
                  onTap: () {},
                  bottom: true,
                  title: 'Send your opinion',
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Future<String?> _changeNicknameBottomSheet(BuildContext context) async {
    final formKey = GlobalKey<FormState>();
    final nicknameEC = TextEditingController(
        text: controller.nickname.value != 'User'
            ? controller.nickname.value
            : '');

    await showModalBottomSheet<String>(
      backgroundColor: AppColors.blackColor,
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
                  cursorColor: AppColors.whiteColor.shade50,
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
                        style: context.textStyles.normalText,
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
          backgroundColor: AppColors.blackColor,
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
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await controller.clearAllData();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.redColor,
                foregroundColor: AppColors.redColor.shade100,
              ),
              child: Text(
                "Yes! I'm Sure",
                style: context.textStyles.normalText,
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                "Noooo!",
                style: context.textStyles.normalText,
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
          backgroundColor: AppColors.blackColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          title: Text(
            'About the app',
            style: context.textStyles.normalText.copyWith(fontSize: 24),
            textAlign: TextAlign.center,
          ),
          content: Text(
            'Consistency is a simple app, it consists of marking, saving and numbering the days that you have completed your personal daily goals, I hope you enjoy and understand the purpose of the app, any questions you can forward to support.',
            style: context.textStyles.normalText,
            textAlign: TextAlign.justify,
          ),
        );
      },
    );
  }
}
