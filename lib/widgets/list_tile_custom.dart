import 'package:consistency/providers/theme_provider.dart';
import 'package:flutter/material.dart';

import 'package:consistency/configs/colors.dart';
import 'package:consistency/configs/text_styles.dart';

class ListTileCustom extends StatelessWidget {
  final String title;
  final bool top;
  final bool bottom;
  final VoidCallback onTap;

  const ListTileCustom({
    Key? key,
    required this.title,
    this.top = false,
    this.bottom = false,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Ink(
          child: InkWell(
            onTap: onTap,
            splashColor: AppColors.primaryColor.shade50,
            borderRadius: BorderRadius.only(
              topLeft:
                  top ? const Radius.circular(16) : const Radius.circular(0),
              topRight:
                  top ? const Radius.circular(16) : const Radius.circular(0),
              bottomLeft:
                  bottom ? const Radius.circular(16) : const Radius.circular(0),
              bottomRight:
                  bottom ? const Radius.circular(16) : const Radius.circular(0),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 8.0,
                vertical: 4,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Flexible(
                    child: Text(
                      title,
                      style: context.textStyles.normalText,
                      textAlign: TextAlign.end,
                    ),
                  ),
                  const SizedBox(
                    width: 8,
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    color: ThemeProvider.of(context).themeMode == ThemeMode.dark
                        ? AppColors.whiteColor
                        : AppColors.blackColor,
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
        ),
        Visibility(
          visible: !bottom,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: ThemeProvider.of(context).themeMode == ThemeMode.dark
                    ? [
                        AppColors.blackColor,
                        AppColors.blackColor.shade200,
                      ]
                    : [
                        AppColors.whiteColor.shade700,
                        AppColors.blackColor.shade50,
                      ],
              ),
            ),
            height: 2,
          ),
        ),
      ],
    );
  }
}
