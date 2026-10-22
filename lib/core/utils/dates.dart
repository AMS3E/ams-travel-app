/// Dates as the app writes them, in the phone's own time.
class Dates {
  const Dates._();

  static const _months = [
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

  /// "14 Oct 2026".
  static String short(DateTime d) {
    final l = d.toLocal();
    return '${l.day} ${_months[l.month - 1].substring(0, 3)} ${l.year}';
  }

  /// "October 14, 2026".
  static String long(DateTime d) {
    final l = d.toLocal();
    return '${_months[l.month - 1]} ${l.day}, ${l.year}';
  }

  /// "October 2026".
  static String monthYear(DateTime d) => '${_months[d.month - 1]} ${d.year}';

  /// Midnight at the start of [d]'s day.
  static DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// "2026-10-14", as the API takes a day.
  static String isoDay(DateTime d) => '${isoMonth(d)}-${_two(d.day)}';

  /// "2026-10", as the API takes a month.
  static String isoMonth(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${_two(d.month)}';

  static String _two(int n) => n.toString().padLeft(2, '0');
}
