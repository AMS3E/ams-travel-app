import '../models/models.dart';

/// Everything the UI needs from the content backend.
///
/// Screens only talk to this interface. Today it is backed by
/// [MockTravelRepository]; when the API is ready [ApiTravelRepository] takes
/// over (see `ApiConfig.useMockData`) and no screen code changes.
abstract class TravelRepository {
  Future<HomeContent> getHome();

  Future<List<Region>> getRegions();
  Future<Region> getRegion(String slug);

  /// All filters are optional and combined with AND.
  Future<List<Destination>> getDestinations({
    String? region,
    String? province,
    List<String>? categories,
    String? query,
  });
  Future<Destination> getDestination(String region, String slug);

  /// Resolves references (featured lists, saved items) in one call.
  Future<List<Destination>> getDestinationsByRefs(List<DestinationRef> refs);

  Future<List<Province>> getProvinces();
  Future<Province> getProvince(String slug);

  Future<List<Interest>> getInterests();
  Future<Interest> getInterest(String slug);

  Future<List<Corridor>> getCorridors();
  Future<Corridor> getCorridor(String slug);

  Future<List<Story>> getStories(String region);
  Future<Story> getStory(String region, String slug);

  Future<List<Review>> getReviews(DestinationRef ref);

  /// Reviews about a whole region, newest first.
  Future<List<Review>> getRegionReviews(String region);

  /// Reviews this traveller has written, newest first.
  Future<List<Review>> getMyReviews(String author);

  /// Bookable rooms in a stay. Empty for places you cannot sleep in.
  Future<List<Room>> getRooms(DestinationRef ref);
  Future<Review> submitReview(
    DestinationRef ref, {
    required int rating,
    String? title,
    String? text,
    String? tripType,
    DateTime? visitedOn,
    required String author,
  });

  Future<void> submitPlanRequest({required String email, required String destination});

  Future<SearchResults> search(String query);
}

class SearchResults {
  const SearchResults({
    this.regions = const [],
    this.provinces = const [],
    this.interests = const [],
    this.corridors = const [],
  });

  final List<Region> regions;
  final List<Province> provinces;
  final List<Interest> interests;
  final List<Corridor> corridors;

  bool get isEmpty => regions.isEmpty && provinces.isEmpty && interests.isEmpty && corridors.isEmpty;

  factory SearchResults.fromJson(Json j) => SearchResults(
    regions: objList(j, 'regions', Region.fromJson),
    provinces: objList(j, 'provinces', Province.fromJson),
    interests: objList(j, 'interests', Interest.fromJson),
    corridors: objList(j, 'corridors', Corridor.fromJson),
  );
}

class NotFoundException implements Exception {
  NotFoundException(this.what);
  final String what;
  @override
  String toString() => '$what not found';
}
