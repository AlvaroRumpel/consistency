import 'package:consistency/configs/colors.dart';
import 'package:consistency/configs/text_styles.dart';
import 'package:consistency/controllers/calendar_controller.dart';
import 'package:consistency/providers/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_calendar_carousel/flutter_calendar_carousel.dart';

import '../configs/utilities.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({Key? key}) : super(key: key);

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  late CalendarController controller;

  @override
  void initState() {
    super.initState();
    controller = CalendarController();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24.0),
      child: ValueListenableBuilder(
        valueListenable: controller.selectedDay,
        child: SliverList(
          delegate: SliverChildListDelegate(
            [
              Text(
                "How's it going",
                style: context.textStyles.normalText.copyWith(fontSize: 32),
                textAlign: TextAlign.center,
              ),
              const SizedBox(
                height: 24,
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Container(
                  height: MediaQuery.of(context).size.height * .5,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    color: ThemeProvider.of(context).themeMode == ThemeMode.dark
                        ? AppColors.blackColor
                        : AppColors.whiteColor.shade700,
                    border: Border.all(
                      color: AppColors.primaryColor,
                      width: 2,
                    ),
                  ),
                  child: ValueListenableBuilder(
                    valueListenable: controller.eventList,
                    builder: (context, value, _) {
                      return CalendarCarousel(
                        markedDatesMap: value,
                        pageSnapping: true,
                        headerMargin: const EdgeInsets.all(0),
                        weekDayMargin: const EdgeInsets.all(0),
                        childAspectRatio: 1,
                        dayButtonColor: ThemeProvider.of(context).themeMode ==
                                ThemeMode.dark
                            ? AppColors.blackColor
                            : AppColors.whiteColor.shade700,
                        selectedDateTime: DateTime.now(),
                        iconColor: AppColors.primaryColor,
                        weekDayBackgroundColor:
                            ThemeProvider.of(context).themeMode ==
                                    ThemeMode.dark
                                ? AppColors.blackColor
                                : AppColors.whiteColor.shade700,
                        selectedDayButtonColor:
                            ThemeProvider.of(context).themeMode ==
                                    ThemeMode.dark
                                ? AppColors.blackColor
                                : AppColors.whiteColor.shade700,
                        selectedDayBorderColor: AppColors.primaryColor,
                        daysHaveCircularBorder: true,
                        daysTextStyle: context.textStyles.normalText,
                        weekdayTextStyle: context.textStyles.normalText,
                        weekendTextStyle: context.textStyles.normalText,
                        selectedDayTextStyle: context.textStyles.boldText,
                        headerTextStyle: context.textStyles.normalText.copyWith(
                          fontSize: 20,
                        ),
                        weekDayFormat: WeekdayFormat.short,
                        onDayPressed: (date, eventList) =>
                            controller.selectDay(date),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        builder: (context, value, sliverList) {
          return CustomScrollView(
            slivers: [
              sliverList!,
              SliverVisibility(
                visible: value != null,
                sliver: SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      color:
                          ThemeProvider.of(context).themeMode == ThemeMode.dark
                              ? AppColors.blackColor
                              : AppColors.whiteColor.shade700,
                      border: Border.all(
                        color: AppColors.primaryColor,
                        width: 2,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Goals completed in ${value?.date.month}/${value?.date.day}',
                          style: context.textStyles.boldText,
                        ),
                        const SizedBox(height: 8),
                        ListView.separated(
                          physics: const NeverScrollableScrollPhysics(),
                          shrinkWrap: true,
                          itemBuilder: (context, index) {
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${index + 1}. ',
                                        style: context.textStyles.thinText,
                                      ),
                                      Expanded(
                                        child: Text(
                                          maxLines: 3,
                                          value!.goals[index].name,
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
                                      value:
                                          value.goals[index].percentCompleted *
                                              .01,
                                      strokeWidth: 2,
                                      color: Utilities.activeColor(
                                          value.goals[index].percentCompleted),
                                      backgroundColor:
                                          (ThemeProvider.of(context)
                                                          .themeMode ==
                                                      ThemeMode.dark
                                                  ? AppColors.whiteColor
                                                  : AppColors.blackColor)
                                              .withOpacity(.5),
                                    ),
                                    Text(
                                      '${value.goals[index].percentCompleted.toStringAsFixed(0)}%',
                                      style: context.textStyles.normalText
                                          .copyWith(
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
                            color: ThemeProvider.of(context).themeMode ==
                                    ThemeMode.dark
                                ? AppColors.whiteColor.shade900.withOpacity(.3)
                                : AppColors.blackColor.withOpacity(.3),
                          ),
                          itemCount: value?.goals.length ?? 0,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
