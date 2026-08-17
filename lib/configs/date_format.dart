/// Shared dd/MM/yyyy formatter — no intl dependency needed for this.
String formatDayMonthYear(DateTime d) => '${d.day.toString().padLeft(2, '0')}/'
    '${d.month.toString().padLeft(2, '0')}/${d.year}';
