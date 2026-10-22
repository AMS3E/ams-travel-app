import 'package:ams_travel/core/utils/opening_hours.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const week = {
    'mon': '07:00-22:00',
    'tue': '07:00-22:00',
    'fri': '18:00-02:00',
    'sat': '00:00-24:00',
    'sun': 'closed',
  };

  test('a day in the documented shape reads as a line', () {
    expect(dayHoursText(week, DateTime.monday), '7AM–10PM');
    expect(dayHoursText(week, DateTime.friday), '6PM–2AM', reason: 'past midnight');
    expect(dayHoursText(week, DateTime.saturday), '12AM–12AM');
  });

  test('closed or missing days are shut', () {
    expect(dayHoursText(week, DateTime.sunday), isNull);
    expect(dayHoursText(week, DateTime.wednesday), isNull);
    expect(formatHoursLine('closed'), isNull);
    expect(formatHoursLine(null), isNull);
  });

  test('single times for check-in and check-out', () {
    expect(formatTime('14:00:00'), '2PM');
    expect(formatTime('07:30'), '7:30AM');
    expect(formatTime('noon'), 'noon');
  });
}
