import 'package:flutter/material.dart';

import '../configs/colors.dart';
import '../configs/text_styles.dart';
import '../providers/theme_provider.dart';

class ListTileCustom extends StatelessWidget {
  final String title;
  final bool top;
  final VoidCallback onTap;

  const ListTileCustom({
    super.key,
    required this.title,
    this.top = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeProvider.of(context).themeMode == ThemeMode.dark;

    return Column(
      children: [
        Ink(
          child: InkWell(
            onTap: onTap,
            splashColor: AppColors.primaryColor.shade50,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(top ? 16 : 0),
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
                  const SizedBox(width: 8),
                  Icon(
                    Icons.arrow_forward_ios,
                    color:
                        isDark ? AppColors.whiteColor : AppColors.blackColor,
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [AppColors.blackColor, AppColors.blackColor.shade200]
                  : [AppColors.whiteColor.shade700, AppColors.blackColor.shade50],
            ),
          ),
          height: 2,
        ),
      ],
    );
  }
}
