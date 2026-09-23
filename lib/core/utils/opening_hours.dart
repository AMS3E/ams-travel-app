import '../../data/models/destination.dart';

enum OpenStatus { open, closed, unknown }

/// Current time in Cambodia (UTC+7, no daylight saving).
DateTime cambodiaNow() => DateTime.now().toUtc().add(const Duration(hours: 7));

int? _minutes(String? hhmm) {
  if (hhmm == null) return null;
  final parts = hhmm.split(':');
  if (parts.length != 2) return null;
  final h = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  if (h == null || m == null) return null;
  return h * 60 + m;
}

/// Open / closed right now. Handles hours that run past midnight
/// (e.g. 17:00–01:00).
OpenStatus openStatus(Destination d, {DateTime? now}) {
  if (d.open24h) return OpenStatus.open;
  final open = _minutes(d.openTime);
  final close = _minutes(d.closeTime);
  if (open == null || close == null) return OpenStatus.unknown;
  final t = now ?? cambodiaNow();
  final m = t.hour * 60 + t.minute;
  final isOpen = close > open ? m >= open && m < close : m >= open || m < close;
  return isOpen ? OpenStatus.open : OpenStatus.closed;
}

/// "07:00" → "7AM", "17:30" → "5:30PM".
String _format(int minutes) {
  final h24 = (minutes ~/ 60) % 24;
  final m = minutes % 60;
  final suffix = h24 < 12 ? 'AM' : 'PM';
  final h12 = h24 % 12 == 0 ? 12 : h24 % 12;
  return m == 0 ? '$h12$suffix' : '$h12:${m.toString().padLeft(2, '0')}$suffix';
}

/// "14:00" → "2PM". For single times such as check-in and check-out.
String formatTime(String hhmm) {
  final m = _minutes(hhmm);
  return m == null ? hhmm : _format(m);
}

/// "7AM–7PM", or null when the hours aren't listed. 24-hour places return
/// null too — the status line already says so.
String? formatHours(Destination d) {
  if (d.open24h) return null;
  final open = _minutes(d.openTime);
  final close = _minutes(d.closeTime);
  if (open == null || close == null) return null;
  return '${_format(open)}–${_format(close)}';
}
