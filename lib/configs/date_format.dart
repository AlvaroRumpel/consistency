// Locale-aware date formatting via `intl`, driven by the locale tag callers
// pass in (usually `Localizations.localeOf(context).toLanguageTag()`).

import 'package:intl/date_symbol_data_local.dart' show initializeDateFormatting;
import 'package:intl/intl.dart';

/// `intl` throws if you build a [DateFormat] for a locale whose symbol data
/// hasn't been loaded yet. `initializeDateFormatting` does that loading
/// synchronously (its Future wrapper is just for API symmetry) and is a
/// no-op after the first call, for every locale at once — so calling it
/// before every format needs no bootstrap step in `main()`. That matters
/// because plain `test()`s (like this file's own test) never pump a widget
/// tree, so nothing else would trigger flutter_localizations into doing it.
void ensureDateSymbols() => initializeDateFormatting();

/// dd/MM
String formatDayMonth(DateTime d, String locale) {
  ensureDateSymbols();
  return DateFormat('dd/MM', locale).format(d);
}

/// dd/MM/yyyy
String formatDayMonthYear(DateTime d, String locale) {
  ensureDateSymbols();
  return DateFormat('dd/MM/yyyy', locale).format(d);
}

/// e.g. 'Fri, 14 August' (English) / 'sex., 14 de agosto' (Portuguese)
String formatWeekdayDayMonth(DateTime d, String locale) {
  ensureDateSymbols();
  final pattern = locale.startsWith('pt') ? "EEE, d 'de' MMMM" : 'EEE, d MMMM';
  return DateFormat(pattern, locale).format(d);
}

/// e.g. 'August 2026'
String formatMonthYear(DateTime d, String locale) {
  ensureDateSymbols();
  return DateFormat('MMMM yyyy', locale).format(d);
}
