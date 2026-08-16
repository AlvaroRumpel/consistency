/// Calendar-day helpers. The app reasons in local calendar days; the JSON
/// stores them as 'yyyy-MM-dd' so DST/timezone shifts never move an entry.
DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

String dateKey(DateTime d) {
  final y = d.year.toString().padLeft(4, '0');
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '$y-$m-$day';
}

DateTime parseDateKey(String s) {
  final parts = s.split('-');
  if (parts.length != 3) throw FormatException('Bad date key: $s');
  return DateTime(
      int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
}
