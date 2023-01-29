import 'package:consistency/configs/colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_calendar_carousel/flutter_calendar_carousel.dart';

class CalendarPage extends StatelessWidget {
  const CalendarPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Container(
          height: MediaQuery.of(context).size.height * .5,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            color: AppColors.blackColor,
            border: Border.all(
              color: AppColors.primaryColor,
              width: 2,
            ),
          ),
          child: CalendarCarousel(
            pageSnapping: true,
            headerMargin: const EdgeInsets.all(0),
            weekDayMargin: const EdgeInsets.all(0),
            childAspectRatio: 1,
            disableDayPressed: true,
            dayButtonColor: AppColors.blackColor,
            selectedDateTime: DateTime.now(),
            iconColor: AppColors.primaryColor,
            weekDayBackgroundColor: AppColors.blackColor,
            selectedDayButtonColor: AppColors.primaryColor,
            daysTextStyle: const TextStyle(
              color: AppColors.whiteColor,
            ),
            weekdayTextStyle: const TextStyle(
              color: AppColors.whiteColor,
            ),
            weekendTextStyle: const TextStyle(
              color: AppColors.whiteColor,
            ),
            selectedDayTextStyle: const TextStyle(
              color: AppColors.whiteColor,
              fontWeight: FontWeight.bold,
            ),
            headerTextStyle: const TextStyle(
              color: AppColors.primaryColor,
              fontSize: 20,
            ),
            weekDayFormat: WeekdayFormat.short,
          ),
        ),
      ),
    );
  }
}
