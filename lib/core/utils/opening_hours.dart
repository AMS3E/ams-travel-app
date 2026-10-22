/// Showing a food place's hours. The API writes them as
/// `{"mon": "07:00-22:00", …, "sun": "closed"}`: keys `mon`…`sun`, one range
/// `HH:mm-HH:mm` (a close before its open runs past midnight, `24:00` is
/// midnight), `closed` or a missing day for a shut day. Whether it is open now
/// and today's line come from the server (`openNow`, `todayHours`); the app
/// only formats.
library;

/// The API's day keys, Monday first.
const weekdayKeys = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];

/// Today's weekday in Cambodia (UTC+7, no daylight saving), 1 = Monday, to
/// highlight today's row.
int cambodiaWeekday() => DateTime.now().toUtc().add(const Duration(hours: 7)).weekday;

/// A day's hours ready to show ("7AM–10PM"), or null when it is shut.
String? dayHoursText(Map<String, String> hours, int weekday) => formatHoursLine(hours[weekdayKeys[weekday - 1]]);

/// "07:00-22:00" → "7AM–10PM"; null for `closed` or nothing. Text in another
/// shape is shown as it came.
String? formatHoursLine(String? value) {
  final v = value?.trim() ?? '';
  if (v.isEmpty || v.toLowerCase() == 'closed') return null;
  final parts = v.split('-');
  if (parts.length != 2) return v;
  return '${formatTime(parts[0])}–${formatTime(parts[1])}';
}

/// "14:00:00" or "14:00" → "2PM", "07:30" → "7:30AM", "24:00" → "12AM".
/// Anything else comes back as it was.
String formatTime(String hhmm) {
  final parts = hhmm.trim().split(':');
  final h = parts.isNotEmpty ? int.tryParse(parts[0]) : null;
  final m = parts.length > 1 ? int.tryParse(parts[1]) : null;
  if (h == null || m == null || h > 24 || m > 59) return hhmm;
  final hour = h % 24;
  final h12 = hour % 12 == 0 ? 12 : hour % 12;
  final suffix = hour < 12 ? 'AM' : 'PM';
  return m == 0 ? '$h12$suffix' : '$h12:${m.toString().padLeft(2, '0')}$suffix';
}
