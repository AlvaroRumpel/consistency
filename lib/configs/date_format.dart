// Locale-aware date formatting via `intl`, driven by the locale tag callers
// pass in (usually `Localizations.localeOf(context).toLanguageTag()`).
//
// `intl` throws if you build a [DateFormat] for a locale whose symbol data
// hasn't been loaded yet. In the app that loading is done by
// flutter_localizations, which calls `initializeDateFormatting` for the
// active locale before the first frame under it — so every call here runs
// from a widget under `Localizations` and finds its data ready. Plain
// `test()`s that format without pumping a tree have to call
// `initializeDateFormatting()` themselves in `setUpAll`.

import 'package:intl/intl.dart';

/// Short numeric day/month, e.g. '8/14' (English) / '14/08' (Portuguese).
String formatDayMonth(DateTime d, String locale) =>
    DateFormat.Md(locale).format(d);

/// Short numeric date, e.g. '8/14/2026' (English) / '14/08/2026' (Portuguese).
String formatDayMonthYear(DateTime d, String locale) =>
    DateFormat.yMd(locale).format(d);

/// e.g. 'Fri, Aug 14' (English) / 'sex., 14 de ago.' (Portuguese)
String formatWeekdayDayMonth(DateTime d, String locale) =>
    DateFormat.MMMEd(locale).format(d);

/// e.g. 'August 2026'
String formatMonthYear(DateTime d, String locale) =>
    DateFormat('MMMM yyyy', locale).format(d);
