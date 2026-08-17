import 'package:consistency/configs/date_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formatWeekdayDayMonth localizes the weekday name', () {
    final d = DateTime(2026, 8, 14); // a Friday
    expect(formatWeekdayDayMonth(d, 'en').startsWith('Fri'), isTrue);
    expect(
      formatWeekdayDayMonth(d, 'pt').toLowerCase().startsWith('sex'),
      isTrue,
    );
  });

  test('formatMonthYear localizes the month name', () {
    expect(formatMonthYear(DateTime(2026, 8, 1), 'pt'), contains('agosto'));
  });
}
