import '../../core/config/api_config.dart';
import '../../core/network/api_client.dart';
import '../models/models.dart';
import 'travel_repository.dart';

/// Real backend implementation. Enabled when `ApiConfig.useMockData` is false.
///
/// Every method maps to one route in [ApiEndpoints]. When the API docs
/// arrive, adjust the paths/query names here — screens stay untouched.
class ApiTravelRepository implements TravelRepository {
  ApiTravelRepository(this._api);

  final ApiClient _api;

  List<T> _list<T>(dynamic body, T Function(Json) fromJson) {
    final data = body is Map && body['items'] is List ? body['items'] : body;
    return (data as List).whereType<Map>().map((e) => fromJson(Json.from(e))).toList();
  }

  T _one<T>(dynamic body, T Function(Json) fromJson) => fromJson(Json.from(body as Map));


  @override
  Future<List<Region>> getRegions() async => _list(await _api.get(ApiEndpoints.regions), Region.fromJson);

  @override
  Future<Region> getRegion(String slug) async => _one(await _api.get(ApiEndpoints.region(slug)), Region.fromJson);

  @override
  Future<List<Destination>> getDestinations({
    String? region,
    String? province,
    List<String>? categories,
    String? query,
  }) async {
    final body = await _api.get(
      ApiEndpoints.destinations,
      query: {
        'region': ?region,
        'province': ?province,
        if (categories != null && categories.isNotEmpty) 'category': categories.join(','),
        if (query != null && query.isNotEmpty) 'q': query,
      },
    );
    return _list(body, Destination.fromJson);
  }

  @override
  Future<Destination> getDestination(String region, String slug) async =>
      _one(await _api.get(ApiEndpoints.destination(region, slug)), Destination.fromJson);

  @override
  Future<List<Destination>> getDestinationsByRefs(List<DestinationRef> refs) async {
    if (refs.isEmpty) return const [];
    // TODO(api): replace with a batch endpoint if the backend offers one.
    final results = await Future.wait(
      refs.map((r) async {
        try {
          return await getDestination(r.region, r.slug);
        } on ApiException {
          return null;
        }
      }),
    );
    return results.whereType<Destination>().toList();
  }

  @override
  Future<List<Province>> getProvinces() async => _list(await _api.get(ApiEndpoints.provinces), Province.fromJson);

  @override
  Future<Province> getProvince(String slug) async =>
      _one(await _api.get(ApiEndpoints.province(slug)), Province.fromJson);

  @override
  Future<List<Interest>> getInterests() async => _list(await _api.get(ApiEndpoints.interests), Interest.fromJson);


  @override
  Future<List<Corridor>> getCorridors() async => _list(await _api.get(ApiEndpoints.corridors), Corridor.fromJson);

  @override
  Future<Corridor> getCorridor(String slug) async =>
      _one(await _api.get(ApiEndpoints.corridor(slug)), Corridor.fromJson);

  @override
  Future<List<Story>> getStories(String region) async =>
      _list(await _api.get(ApiEndpoints.regionStories(region)), Story.fromJson);


  @override
  Future<List<Review>> getReviews(DestinationRef ref) async =>
      _list(await _api.get(ApiEndpoints.destinationReviews(ref.region, ref.slug)), Review.fromJson);

  @override
  Future<List<Review>> getRegionReviews(String region) async =>
      _list(await _api.get(ApiEndpoints.regionReviews(region)), Review.fromJson);

  @override
  Future<List<Review>> getMyReviews(String author) async =>
      _list(await _api.get(ApiEndpoints.myReviews), Review.fromJson);

  @override
  Future<List<Room>> getRooms(DestinationRef ref) async =>
      _list(await _api.get(ApiEndpoints.rooms(ref.region, ref.slug)), Room.fromJson);

  @override
  Future<Review> submitReview(
    DestinationRef ref, {
    required int rating,
    String? title,
    String? text,
    String? tripType,
    DateTime? visitedOn,
    required String author,
  }) async {
    final body = await _api.post(
      ApiEndpoints.destinationReviews(ref.region, ref.slug),
      body: {
        'rating': rating,
        'title': ?title,
        'text': ?text,
        'tripType': ?tripType,
        if (visitedOn != null) 'visitedOn': visitedOn.toIso8601String(),
      },
    );
    return _one(body, Review.fromJson);
  }


  @override
  Future<SearchResults> search(String query) async =>
      _one(await _api.get(ApiEndpoints.search, query: {'q': query}), SearchResults.fromJson);
}
