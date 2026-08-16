import 'package:flutter/material.dart';

import '../configs/colors.dart';
import '../configs/text_styles.dart';

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
                    color: Theme.of(context).colorScheme.onSurface,
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
        ),
        Divider(height: 2, thickness: 1, color: Theme.of(context).dividerColor),
      ],
    );
  }
}
