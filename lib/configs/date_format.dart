// Shared date formatting — no intl dependency needed for these.
// English only; Phase 8 localizes.

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _months = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// dd/MM
String formatDayMonth(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

/// dd/MM/yyyy
String formatDayMonthYear(DateTime d) => '${formatDayMonth(d)}/${d.year}';

/// e.g. 'Fri, 14 August'
String formatWeekdayDayMonth(DateTime d) =>
    '${_weekdays[d.weekday - 1]}, ${d.day} ${_months[d.month - 1]}';
