import 'package:ams_travel/core/l10n/app_strings.dart';
import 'package:ams_travel/data/api/ams_api.dart';
import 'package:ams_travel/features/saved/folders_screen.dart';
import 'package:ams_travel/features/saved/saved_screen.dart';
import 'package:ams_travel/state/collections_provider.dart';
import 'package:ams_travel/widgets/app_image.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'support/account_harness.dart';

const _angkor = '6cd2c24d-a1c1-4bbe-9833-31d30e763ee6';
const _corridor = 'ef52e705-d9ef-4412-a9c4-b14a4b9bd11a';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await S.load();
    GoogleFonts.config.allowRuntimeFetching = false;
    AppImage.useDiskCache = false;
  });
  setUp(rootBundle.clear);

  Future<void> big(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }

  testWidgets('a guest is invited to sign in, and nothing is asked of the API', (tester) async {
    await big(tester);
    final h = await AccountHarness.start(signedIn: false);
    await tester.pumpWidget(h.wrap(const SavedScreen()));
    await settle(tester);

    expect(find.text('Your saved places live here'), findsOneWidget);
    expect(find.text('Log in'), findsOneWidget);
    expect(find.text('Register'), findsOneWidget);
    expect(h.adapter.requests.where((r) => r.path == '/favorites'), isEmpty);
  });

  testWidgets('favourites become cards, one call per kind', (tester) async {
    await big(tester);
    final h = await AccountHarness.start();
    await tester.pumpWidget(h.wrap(const SavedScreen()));
    await settle(tester);

    expect(find.text('Saves (2)'), findsOneWidget);
    expect(find.text('Angkor Wat'), findsOneWidget);
    expect(find.text('Khmer Civilization'), findsOneWidget);

    final cardCalls = h.adapter.requests.where((r) => r.path == '/search/cards').toList();
    expect(cardCalls.map((r) => r.queryParameters['type']).toSet(), {'DESTINATION', 'CORRIDOR'});
    expect(cardCalls, hasLength(2), reason: 'one call per kind, not per row');
    expect(cardCalls.firstWhere((r) => r.queryParameters['type'] == 'DESTINATION').queryParameters['ids'].toString(), contains(_angkor));
  });

  testWidgets('the Regions and Interests tabs group the cards by their own fields', (tester) async {
    await big(tester);
    final h = await AccountHarness.start();
    await tester.pumpWidget(h.wrap(const SavedScreen()));
    await settle(tester);

    await tester.tap(find.text('Regions'));
    await settle(tester);
    expect(find.text('Ancient Capitals & Khmer Civilization'), findsOneWidget);

    await tester.ensureVisible(find.text('Interests'));
    await settle(tester, rounds: 3);
    await tester.tap(find.text('Interests'));
    await settle(tester);
    expect(find.text('Historical Sites'), findsOneWidget, reason: "Angkor Wat's interest");
  });

  testWidgets('folders live on the phone and hold favourites by kind and id', (tester) async {
    await big(tester);
    final h = await AccountHarness.start(
      stored: {
        'ams-travel:folders-v2':
            '{"Temples":["${FoldersProvider.keyOf(CardType.destination, _angkor)}","DESTINATION:not-saved-any-more"]}',
      },
    );
    await tester.pumpWidget(h.wrap(const FolderScreen(name: 'Temples')));
    await settle(tester);

    expect(find.text('Angkor Wat'), findsOneWidget);
    expect(find.text('Khmer Civilization'), findsNothing, reason: 'not in this folder');
    expect(FoldersProvider.parse('CORRIDOR:$_corridor'), (CardType.corridor, _corridor));
    expect(FoldersProvider.parse('siem-reap/angkor-wat'), isNull, reason: 'old mock keys are ignored');
  });
}
