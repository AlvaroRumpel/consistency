import 'package:flutter/material.dart';
import 'package:flutter_calendar_carousel/flutter_calendar_carousel.dart';

import '../configs/colors.dart';
import '../configs/text_styles.dart';
import '../controllers/calendar_controller.dart';
import '../widgets/error_view.dart';
import '../widgets/goals_done_list_view.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  late CalendarController _controller;

  @override
  void initState() {
    super.initState();
    _controller = CalendarController(CalendarLoading());
  }

  @override
  void dispose() {
    _controller.onDispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24.0),
      child: CustomScrollView(
        slivers: [
          SliverList.list(
            children: [
              Text(
                "How's it going",
                style: context.textStyles.normalText.copyWith(fontSize: 32),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Container(
                height: MediaQuery.sizeOf(context).height * 0.4,
                margin: const EdgeInsets.all(16.0),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  color: Theme.of(context).cardColor,
                  border: Border.all(
                    color: AppColors.primaryColor,
                    width: 2,
                  ),
                ),
                child: ValueListenableBuilder(
                  valueListenable: _controller.stateNotifier,
                  builder: (context, state, _) {
                    if (state is CalendarError) {
                      return ErrorView(
                        message: state.message,
                        onRetry: _controller.reload,
                      );
                    }
                    if (state is! CalendarData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    return CalendarCarousel(
                      scrollDirection: Axis.horizontal,
                      markedDatesMap: state.eventList,
                      pageSnapping: true,
                      headerMargin: const EdgeInsets.all(0),
                      weekDayMargin: const EdgeInsets.all(0),
                      childAspectRatio: 1,
                      dayButtonColor: Theme.of(context).cardColor,
                      selectedDateTime: state.selectedDay,
                      iconColor: AppColors.primaryColor,
                      weekDayBackgroundColor: Theme.of(context).cardColor,
                      selectedDayButtonColor: Theme.of(context).cardColor,
                      selectedDayBorderColor: AppColors.primaryColor,
                      daysHaveCircularBorder: true,
                      daysTextStyle: context.textStyles.normalText,
                      weekdayTextStyle: context.textStyles.normalText,
                      weekendTextStyle: context.textStyles.normalText,
                      selectedDayTextStyle: context.textStyles.boldText,
                      headerTextStyle: context.textStyles.normalText.copyWith(
                        fontSize: 20,
                      ),
                      todayButtonColor: Colors.transparent,
                      todayBorderColor:
                          Theme.of(context).colorScheme.onSurfaceVariant,
                      weekDayFormat: WeekdayFormat.short,
                      onDayPressed: (date, eventList) =>
                          _controller.selectDay(date),
                    );
                  },
                ),
              ),
            ],
          ),
          ValueListenableBuilder(
            valueListenable: _controller.stateNotifier,
            builder: (context, state, _) {
              if (state is! CalendarData) {
                // Error is already shown by the calendar box above.
                return const SliverToBoxAdapter(child: SizedBox.shrink());
              }
              final value = state.selectedDaysGoals;
              return SliverVisibility(
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
                      color: Theme.of(context).cardColor,
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
                        GoalsDoneListView(goals: value?.goals ?? [])
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
