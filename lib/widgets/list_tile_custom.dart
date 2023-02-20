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
                  const Icon(
                    Icons.arrow_forward_ios,
                    color: AppColors.whiteColor,
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
                colors: [
                  AppColors.blackColor,
                  AppColors.blackColor.shade200,
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
