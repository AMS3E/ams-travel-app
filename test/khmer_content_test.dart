import 'package:ams_travel/core/network/api_client.dart';
import 'package:ams_travel/data/api/ams_api.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_api.dart';

const _cruise = '078303f6-baa1-4104-b549-927b6fd80716';

void main() {
  late FixtureAdapter adapter;
  late AmsApi api;

  setUp(() {
    adapter = FixtureAdapter();
    api = AmsApi(ApiClient(adapter: adapter));
  });

  Map<String, dynamic> lastQuery(String path) => adapter.requests.lastWhere((r) => r.path == path).queryParameters;

  test('in English, nothing asks for Khmer and the English is read', () async {
    final a = await api.activity(_cruise);
    expect(a.name, 'Kampi Dolphin Sunset Cruise');
    await api.search(type: CardType.activity);
    expect(lastQuery('/search').containsKey('lang'), isFalse);
  });

  test('in Khmer, the search calls ask lang=km', () async {
    api.khmer = true;
    await api.search(type: CardType.activity);
    await api.searchByProvince(type: CardType.activity);
    await api.cards([_cruise], type: CardType.activity);
    await api.suggest('kampi');
    for (final path in ['/search', '/search/by-province', '/search/cards', '/search/suggest']) {
      expect(lastQuery(path)['lang'], 'km', reason: path);
    }
  });

  test('in Khmer, a detail reads the Khmer twins', () async {
    api.khmer = true;
    final a = await api.activity(_cruise);
    expect(a.name, 'ជិះទូកមើលផ្សោតពេលថ្ងៃលិចនៅកំពី');
    expect(a.slogan, 'ម៉ាស៊ីនឈប់ ហើយអ្នកឮសំឡេងពួកវាដកដង្ហើម។');
    expect(a.address, startsWith('កំពង់ទូកកំពី'));
    expect(a.shortDescription, startsWith('A two-hour evening cruise'), reason: 'no Khmer twin: English stays');
  });

  test('in Khmer, a corridor reads its Khmer name and descriptions', () async {
    api.khmer = true;
    final c = (await api.itinerary('ef52e705-d9ef-4412-a9c4-b14a4b9bd11a')).corridor;
    expect(c.name, 'អារ្យធម៌ខ្មែរ');
    expect(c.shortDescription, startsWith('រាជធានីបុរាណ'));
    expect(c.description, startsWith('រាជធានីបុរាណ'));
    expect(c.expectations, ['Sunrise', 'Photography', 'Historic Site']);
  });

  test('in Khmer, reference lists read the Khmer, and keep the English where none is written', () async {
    api.khmer = true;
    final interests = await api.interests();
    expect(interests.firstWhere((i) => i.slug == 'beaches-islands').name, 'ឆ្នេរ និងកោះ');
    expect(interests.firstWhere((i) => i.slug == 'diving').name, 'Diving', reason: 'no nameKm in the answer');
    api.khmer = false;
    final english = await api.interests();
    expect(english.firstWhere((i) => i.slug == 'beaches-islands').name, 'Beaches & Island', reason: 'kept apart per language');
  });
}
