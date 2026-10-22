import 'package:ams_travel/core/l10n/app_strings.dart';
import 'package:ams_travel/core/utils/location.dart';
import 'package:ams_travel/data/api/ams_api.dart';
import 'package:ams_travel/features/destination/check_in_screen.dart';
import 'package:ams_travel/features/profile/profile_screen.dart';
import 'package:ams_travel/widgets/app_image.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'support/account_harness.dart';

const _food = '8d2f3e4a-5b6c-4d7e-9f0a-1b2c3d4e5f61';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await S.load();
    AppImage.useDiskCache = false;
  });
  setUp(rootBundle.clear);

  // No camera in a test, as on a simulator: the scanner's channels answer
  // nothing, so it reports the camera refused and the code is typed.
  setUp(() {
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const scanner = 'dev.steenbakker.mobile_scanner/scanner';
    messenger.setMockMethodCallHandler(const MethodChannel('$scanner/method'), (_) async => null);
    for (final events in ['$scanner/event', '$scanner/deviceOrientation']) {
      messenger.setMockStreamHandler(EventChannel(events), MockStreamHandler.inline(onListen: (_, _) {}));
    }
  });

  Future<void> big(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }

  testWidgets('a typed code goes with the position, and the result is for the place the code belongs to', (
    tester,
  ) async {
    await big(tester);
    final h = await AccountHarness.start();
    var located = 0;
    Future<DeviceLocation> locate() async {
      located++;
      return const DeviceLocation.at(13.3622, 103.8597);
    }

    await tester.pumpWidget(h.wrap(CheckInScreen(locate: locate)));
    await settle(tester);
    expect(located, 0, reason: 'location is asked for once a code is in, not before');

    await tester.tap(find.text('Type the code instead'));
    await settle(tester, rounds: 3);
    await tester.enterText(find.byType(TextField), 'ABCD-EFGH-JKLM');
    await tester.tap(find.widgetWithText(FilledButton, 'Check in'));
    await settle(tester);

    expect(located, 1);
    expect(h.sent('POST', '/stamps').single, {'code': 'ABCD-EFGH-JKLM', 'latitude': 13.3622, 'longitude': 103.8597});
    // The answer names a food place: its card is read as FOOD and shown.
    final card = h.adapter.requests.lastWhere((r) => r.path == '/search/cards');
    expect(card.queryParameters['type'], 'FOOD');
    expect(card.queryParameters['ids'], _food);
    expect(find.text('Stamp collected'), findsOneWidget);
    expect(find.text('Banteay Kitchen'), findsOneWidget);
    expect(find.text('Silver Adventurer'), findsOneWidget, reason: 'the badge the stamp earned');
    expect(find.text('Open the place'), findsOneWidget);
  });

  test('every outcome is read, with the kind of place', () {
    final far = Stamp.fromJson({
      'targetType': 'ACTIVITY',
      'destinationId': 'a1',
      'outcome': 'TOO_FAR',
      'distanceMeters': 2450,
      'radiusMeters': 200,
    });
    expect(far.outcome, CheckInOutcome.tooFar);
    expect(far.targetType, CardType.activity);
    expect(far.hasPlace, isTrue);

    final unknown = Stamp.fromJson({'outcome': 'INVALID_CODE', 'destinationId': null});
    expect(unknown.outcome, CheckInOutcome.invalidCode);
    expect(unknown.hasPlace, isFalse, reason: 'an unknown code names no place');

    expect(Stamp.fromJson({'outcome': 'ALREADY_COLLECTED', 'destinationId': 'd'}).outcome, CheckInOutcome.alreadyCollected);
  });

  testWidgets("the profile's check-ins read each kind's cards, and offer a scan", (tester) async {
    await big(tester);
    final h = await AccountHarness.start();
    await tester.pumpWidget(h.wrap(const ProfileScreen()));
    await settle(tester);

    await tester.tap(find.text('Check-ins'));
    await settle(tester);

    expect(find.text('Scan a code'), findsOneWidget);
    final types = {
      for (final r in h.adapter.requests)
        if (r.path == '/search/cards') r.queryParameters['type'],
    };
    expect(types, containsAll(['DESTINATION', 'FOOD']));
    expect(find.text('Banteay Kitchen'), findsOneWidget);
  });
}
