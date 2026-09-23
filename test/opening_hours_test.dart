import 'package:ams_travel/core/utils/opening_hours.dart';
import 'package:ams_travel/data/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

Destination _place({String? open, String? close, bool open24h = false}) => Destination(
  slug: 'x',
  region: 'r',
  name: 'X',
  province: 'Kep',
  category: 'Coffee',
  blurb: '',
  lat: 10.5,
  lng: 104.3,
  image: '',
  openTime: open,
  closeTime: close,
  open24h: open24h,
);

DateTime _at(int h, int m) => DateTime(2026, 9, 15, h, m);

void main() {
  test('daytime hours', () {
    final cafe = _place(open: '07:00', close: '19:00');
    expect(openStatus(cafe, now: _at(6, 59)), OpenStatus.closed);
    expect(openStatus(cafe, now: _at(7, 0)), OpenStatus.open);
    expect(openStatus(cafe, now: _at(18, 59)), OpenStatus.open);
    expect(openStatus(cafe, now: _at(19, 0)), OpenStatus.closed);
    expect(formatHours(cafe), '7AM–7PM');
  });

  test('hours past midnight', () {
    final bar = _place(open: '17:00', close: '01:00');
    expect(openStatus(bar, now: _at(16, 0)), OpenStatus.closed);
    expect(openStatus(bar, now: _at(23, 30)), OpenStatus.open);
    expect(openStatus(bar, now: _at(0, 30)), OpenStatus.open);
    expect(openStatus(bar, now: _at(1, 0)), OpenStatus.closed);
    expect(formatHours(bar), '5PM–1AM');
  });

  test('24 hours and unknown', () {
    expect(openStatus(_place(open24h: true), now: _at(3, 0)), OpenStatus.open);
    expect(formatHours(_place(open24h: true)), isNull);
    expect(openStatus(_place()), OpenStatus.unknown);
    expect(formatHours(_place(open: '07:30', close: '17:30')), '7:30AM–5:30PM');
  });
}
