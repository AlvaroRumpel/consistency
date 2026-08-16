import 'package:flutter/material.dart';

import '../configs/colors.dart';
import '../configs/text_styles.dart';
import '../configs/utilities.dart';
import '../models/goal_model.dart';

class GoalsListView extends StatefulWidget {
  final List<GoalModel> goals;
  final List<TextEditingController> textControllers;
  final bool hasMarkedToday;
  final void Function(int) onRemove;
  final VoidCallback onAdd;

  const GoalsListView({
    super.key,
    required this.goals,
    required this.textControllers,
    this.hasMarkedToday = false,
    required this.onRemove,
    required this.onAdd,
  });

  @override
  State<GoalsListView> createState() => _GoalsListViewState();
}

class _GoalsListViewState extends State<GoalsListView> {
  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      itemCount: widget.goals.length,
      shrinkWrap: true,
      itemBuilder: (context, index) {
        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: widget.textControllers[index],
                    maxLength: 50,
                    style: context.textStyles.normalText,
                    enabled: !widget.hasMarkedToday,
                    cursorColor:
                        Theme.of(context).textSelectionTheme.cursorColor,
                    decoration: InputDecoration(
                      counterText: '',
                      label: Text(
                        'Goal name',
                        style: context.textStyles.normalText,
                      ),
                    ),
                  ),
                ),
                Visibility(
                  visible: !widget.hasMarkedToday,
                  child: IconButton(
                    onPressed: () => widget.onRemove(index),
                    style: IconButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(100),
                        side: const BorderSide(
                          color: AppColors.redColor,
                          width: 2,
                        ),
                      ),
                    ),
                    icon: const Icon(
                      Icons.remove,
                      color: AppColors.redColor,
                    ),
                  ),
                ),
              ],
            ),
            Slider(
              value: widget.goals[index].percentCompleted,
              max: 100,
              min: 0,
              divisions: 4,
              inactiveColor: Theme.of(context).colorScheme.surfaceContainerLow,
              activeColor:
                  Utilities.activeColor(widget.goals[index].percentCompleted),
              label:
                  '${widget.goals[index].percentCompleted.toStringAsFixed(0)}%',
              onChanged: widget.hasMarkedToday
                  ? null
                  : (v) {
                      setState(() {
                        widget.goals[index].percentCompleted = v;
                      });
                    },
            ),
            Visibility(
              visible:
                  index == widget.goals.length - 1 && !widget.hasMarkedToday,
              child: IconButton(
                onPressed: widget.onAdd,
                style: IconButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(100),
                    side: const BorderSide(
                      color: AppColors.primaryColor,
                      width: 2,
                    ),
                  ),
                ),
                icon: const Icon(
                  Icons.add,
                  color: AppColors.primaryColor,
                ),
              ),
            )
          ],
        );
      },
      separatorBuilder: (context, index) => const SizedBox(height: 4),
    );
  }
}
