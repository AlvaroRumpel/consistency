import 'package:flutter/material.dart';

import '../configs/colors.dart';
import '../configs/text_styles.dart';
import '../configs/utilities.dart';
import '../models/goal_model.dart';
import '../providers/theme_provider.dart';

class GoalsDoneListView extends StatelessWidget {
  final List<GoalModel> goals;
  const GoalsDoneListView({super.key, required this.goals});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemBuilder: (context, index) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Text(
                    '${index + 1}. ',
                    style: context.textStyles.thinText,
                  ),
                  Expanded(
                    child: Text(
                      maxLines: 3,
                      goals[index].name,
                      style: context.textStyles.normalText,
                    ),
                  ),
                ],
              ),
            ),
            Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: goals[index].percentCompleted * .01,
                  strokeWidth: 2,
                  color: Utilities.activeColor(
                    goals[index].percentCompleted,
                  ),
                  backgroundColor:
                      (ThemeProvider.of(context).themeMode == ThemeMode.dark
                              ? AppColors.whiteColor
                              : AppColors.blackColor)
                          .withValues(alpha: .5),
                ),
                Text(
                  '${goals[index].percentCompleted.toStringAsFixed(0)}%',
                  style: context.textStyles.normalText.copyWith(
                    fontSize: 12,
                  ),
                )
              ],
            ),
          ],
        );
      },
      separatorBuilder: (context, index) => Divider(
        height: 16,
        color: ThemeProvider.of(context).themeMode == ThemeMode.dark
            ? AppColors.whiteColor.shade900.withValues(alpha: .3)
            : AppColors.blackColor.withValues(alpha: .3),
      ),
      itemCount: goals.length,
    );
  }
}
