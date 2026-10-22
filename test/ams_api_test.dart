import 'package:ams_travel/core/config/api_config.dart';
import 'package:ams_travel/core/network/api_client.dart';
import 'package:ams_travel/data/api/ams_api.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_api.dart';

void main() {
  final api = fakeAmsApi();

  test('picture paths get the server origin, not the base URL', () {
    expect(ApiConfig.mediaUrl('/api/v1/media/files/a.jpg'), 'https://api.travel.ams.com.kh/api/v1/media/files/a.jpg');
    expect(ApiConfig.mediaUrl(null), '');
  });

  test('a paged answer reads as content plus its page', () async {
    final page = await api.search(type: CardType.corridor);
    expect(page.content, isNotEmpty);
    expect(page.content.first.type, CardType.corridor);
    expect(page.content.first.durationDays, isNotNull);
    expect(page.content.first.coverUrl, startsWith('https://api.travel.ams.com.kh/api/v1/media/'));
    expect(page.totalElements, greaterThanOrEqualTo(page.content.length));
  });

  test('popular ids come back as their cards, in rank order', () async {
    final cards = await api.popular();
    expect(cards.map((c) => c.name), ['Angkor Wat']);
  });

  test('interests fall into the six chip groups, in the design order', () async {
    final groups = InterestGroup.of(await api.interests());
    expect(groups.map((g) => g.name), InterestGroup.order);
  });

  test('provinces carry their picture, centre, bounds and counts', () async {
    final battambang = (await api.provinces()).firstWhere((p) => p.name == 'Battambang');
    expect(battambang.placeCount, 4);
    expect(battambang.hasPin, isTrue);
    expect(battambang.bounds, isNotNull);
  });

  test('the Provinces page is one by-province answer', () async {
    final groups = await api.searchByProvince(perProvince: 8);
    expect(groups.map((g) => g.provinceName), contains('Battambang'));
    expect(groups.firstWhere((g) => g.provinceName == 'Battambang').totalElements, 4);
  });

  test('regions and provinces are favourites like the cards', () async {
    final adapter = FixtureAdapter();
    final api = AmsApi(ApiClient(adapter: adapter));
    await api.addFavorite(FavoriteType.region, 'r1');
    await api.removeFavorite(FavoriteType.province, 'p1');
    expect(adapter.requests[0].data, {'targetType': 'REGION', 'targetId': 'r1'});
    expect(adapter.requests[1].path, '/favorites/PROVINCE/p1');
    expect(FavoriteType.parse('PROVINCE').cardType, isNull);
    expect(FavoriteType.of(CardType.stay), FavoriteType.stay);
  });

  test('a profile save sends every field, so none is cleared by accident', () async {
    final adapter = FixtureAdapter();
    final api = AmsApi(ApiClient(adapter: adapter));
    await api.updateMe(fullName: 'Dara Chan', phone: null, avatarKey: 'avatar/x.jpg', homeProvinceId: 'p1');
    expect(adapter.requests.single.data, {
      'fullName': 'Dara Chan',
      'phone': null,
      'avatarKey': 'avatar/x.jpg',
      'homeProvinceId': 'p1',
    });
  });
}
