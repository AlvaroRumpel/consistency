import 'package:consistency/configs/date_format.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  // No widget tree here, so flutter_localizations never loads the symbols.
  setUpAll(initializeDateFormatting);
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
