// Walks the screens on a simulator or phone against the real server, so each
// can be looked at (or screenshotted) with live data. Not part of `flutter test`.
//
//   flutter test integration_test/screen_tour_test.dart -d <device> \
//     --dart-define=INITIAL_ROUTE=/ --dart-define=TOUR=/,/popular,/provinces/explore
//
// Each stop prints `TOUR-SHOT <name>` once the page has settled, then holds
// still for a few seconds. A stop written `/route!Label` taps the text
// "Label" first, `/route!=ABCD` types "ABCD" into the text field in focus;
// `/route>800` also scrolls 800 px down and shoots again.
import 'package:ams_travel/main.dart' as app;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';

const _tour = String.fromEnvironment('TOUR', defaultValue: '/');

Future<void> _wait(WidgetTester tester, Duration d) async {
  final end = DateTime.now().add(d);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _shot(WidgetTester tester, String name) async {
  // ignore: avoid_print
  print('TOUR-SHOT $name');
  await _wait(tester, const Duration(seconds: 4));
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('screen tour', (tester) async {
    app.main();
    await _wait(tester, const Duration(seconds: 6));

    final stops = _tour.split(',').where((s) => s.isNotEmpty).toList();
    for (var i = 0; i < stops.length; i++) {
      final parts = stops[i].split('>');
      final scroll = parts.length > 1 ? double.tryParse(parts[1]) : null;
      final [route, ...taps] = parts.first.split('!');
      final navigator = tester.element(find.byType(Navigator).first);
      GoRouter.of(navigator).go(route);
      await _wait(tester, const Duration(seconds: 7));
      for (final label in taps) {
        if (label.startsWith('=')) {
          await tester.enterText(find.byType(EditableText).last, label.substring(1));
          await _wait(tester, const Duration(seconds: 1));
          continue;
        }
        final target = find.text(label);
        if (target.evaluate().isNotEmpty) {
          // The last match is the one on top, such as a dialog's button.
          await tester.tap(target.last, warnIfMissed: false);
          await _wait(tester, const Duration(seconds: 5));
        }
      }
      await _shot(tester, 'stop$i');
      if (scroll != null) {
        final vertical = find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down);
        if (vertical.evaluate().isNotEmpty) {
          await tester.drag(vertical.last, Offset(0, -scroll), warnIfMissed: false);
          await _wait(tester, const Duration(seconds: 4));
          await _shot(tester, 'stop${i}b');
        }
      }
    }
  });
}
