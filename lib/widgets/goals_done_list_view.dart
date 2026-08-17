import 'package:flutter/material.dart';

import '../configs/text_styles.dart';
import '../configs/utilities.dart';
import '../controllers/day_editor_controller.dart';

class GoalsDoneListView extends StatelessWidget {
  final List<GoalRow> goals;
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
                  value: goals[index].value * .01,
                  strokeWidth: 2,
                  color: Utilities.activeColor(
                    goals[index].value,
                  ),
                  backgroundColor:
                      Theme.of(context).iconTheme.color!.withValues(alpha: .5),
                ),
                Text(
                  '${goals[index].value.toStringAsFixed(0)}%',
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
        color: Theme.of(context).dividerColor,
      ),
      itemCount: goals.length,
    );
  }
}
