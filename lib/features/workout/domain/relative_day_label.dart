/// "hoy", "ayer" or "hace N días", counted in calendar days of the device's
/// time zone (a session last night at 23 h is "ayer", not "hoy").
String relativeDayLabel(DateTime? date, {DateTime? now}) {
  if (date == null) return 'Nunca';
  final today = (now ?? DateTime.now()).toLocal();
  final local = date.toLocal();
  final days = DateTime.utc(today.year, today.month, today.day)
      .difference(DateTime.utc(local.year, local.month, local.day))
      .inDays;
  if (days <= 0) return 'hoy';
  if (days == 1) return 'ayer';
  return 'hace $days días';
}
