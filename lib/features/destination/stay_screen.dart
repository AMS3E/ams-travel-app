import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/html_text.dart';
import '../../core/utils/opening_hours.dart';
import '../../data/api/ams_api.dart';
import '../../state/collections_provider.dart';
import '../../widgets/async_view.dart';
import 'booking.dart';
import 'contact_card.dart';
import 'place_view.dart';
import 'browse_record.dart';
import 'reviews_section.dart';

/// Amenity slugs as labels, in the given order; a slug `GET /amenities` does
/// not know is shown as words.
List<String> _amenityNames(List<String> slugs, Map<String, Amenity> bySlug) => [
  for (final slug in slugs) bySlug[slug]?.name ?? labelOf(slug),
];

class _StayData {
  const _StayData({required this.stay, this.card, this.media = const [], this.amenities = const {}, this.rating});

  final StayDetail stay;

  /// For the seal.
  final PlaceCard? card;
  final List<MediaItem> media;
  final Map<String, Amenity> amenities;
  final RatingSummary? rating;
}

/// A stay: `GET /stays/{id}`, its gallery, its amenities by name, its rating
/// summary and reviews, and the dates-and-guests picker that asks the quote
/// for one total. Nothing is booked: the stay's own phone and website are
/// the way to a booking.
class StayScreen extends StatelessWidget {
  const StayScreen({super.key, required this.id});
  final String id;

  Future<_StayData> _load(AmsApi api) async {
    final (stay, card, media, amenities, rating) = await (
      api.stay(id),
      api.card(id, type: CardType.stay).orNull,
      api.media(CardType.stay, id).or(const []),
      api.amenities().or(const []),
      api.ratingSummary(CardType.stay, id).orNull,
    ).wait;
    return _StayData(stay: stay, card: card, media: media, amenities: amenitiesBySlug(amenities), rating: rating);
  }

  @override
  Widget build(BuildContext context) {
    final api = context.read<AmsApi>();
    final s = S.of(context);
    return BrowseRecorder(
      type: CardType.stay,
      id: id,
      child: AsyncView<_StayData>(
        load: () => _load(api),
        loading: const Scaffold(body: LoadingView()),
        builder: (context, data, _) => Scaffold(
          body: _StayView(data: data),
          bottomNavigationBar: BottomActionBar(label: s.viewRooms, onPressed: () => context.push(Routes.stayRooms(id))),
        ),
      ),
    );
  }
}

class _StayView extends StatelessWidget {
  const _StayView({required this.data});
  final _StayData data;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final st = data.stay;
    final rating = data.rating;
    final average = rating?.shownAverage;
    final amenities = _amenityNames(st.amenities, data.amenities);

    return CustomScrollView(
      slivers: [
        PlaceHero(
          photos: galleryUrls(st.coverUrl, data.media),
          kind: SavedKind.stay,
          id: st.id,
          shareText: shareTextFor(st.name, line: st.shortDescription, latitude: st.latitude, longitude: st.longitude),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(st.name, style: AppText.display(24)),
                const SizedBox(height: 8),
                // The seal, then the score under it, as on an attraction.
                SealLine(card: data.card),
                RatingLine(average: average, count: rating?.count ?? 0),
                // "Open 24h" in the design is filler: a stay has check-in
                // hours, shown under Stay Policies.
                // The hotel's class in yellow, then its kind under it.
                if (st.starRating != null && st.starRating! > 0) ...[
                  const SizedBox(height: 12),
                  CategoryTag(
                    label: s.hotelStarsText(st.starRating!.round()),
                    icon: Icons.star_rounded,
                    color: AppColors.star,
                  ),
                ],
                if (st.type != null) ...[
                  const SizedBox(height: 10),
                  CategoryTag(label: labelOf(st.type!), icon: Icons.hotel_rounded),
                ],
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(child: BookingPanel(stayId: st.id)),
        SliverToBoxAdapter(
          child: SloganQuote(slogan: st.slogan, by: st.sloganBy),
        ),
        SliverToBoxAdapter(
          child: DescriptionCard(short: st.shortDescription, long: st.description),
        ),
        if (st.hasPin)
          SliverToBoxAdapter(
            child: LocationCard(id: st.id, address: st.address, latitude: st.latitude!, longitude: st.longitude!),
          ),
        if (amenities.isNotEmpty)
          SliverToBoxAdapter(
            child: PlainSection(
              title: s.facilities,
              child: KeywordChips(words: amenities),
            ),
          ),
        SliverToBoxAdapter(
          child: ReviewsSection(type: CardType.stay, id: st.id, average: average, count: rating?.count),
        ),
        SliverToBoxAdapter(child: StayPolicies(stay: st)),
        SliverToBoxAdapter(
          child: ContactButtons(phone: st.phone, website: st.website),
        ),
        SliverToBoxAdapter(child: bottomGap(context)),
      ],
    );
  }
}

/// Check-in and check-out hours and the stay's policies box, as the stay
/// wrote them. Hidden when the stay gave none.
class StayPolicies extends StatelessWidget {
  const StayPolicies({super.key, required this.stay});
  final StayDetail stay;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final st = stay;
    String? span(String? from, String? until) {
      final parts = [
        if (from != null && from.isNotEmpty) '${s.fromTime} ${formatTime(from)}',
        if (until != null && until.isNotEmpty) '${s.untilTime.toLowerCase()} ${formatTime(until)}',
      ];
      return parts.isEmpty ? null : parts.join(' ');
    }

    final checkIn = span(st.checkInFrom, st.checkInUntil);
    final checkOut = (st.checkOutFrom == null || st.checkOutFrom!.isEmpty) && st.checkOutUntil != null
        ? '${s.beforeTime} ${formatTime(st.checkOutUntil!)}'
        : span(st.checkOutFrom, st.checkOutUntil);
    final policies = htmlToLines(st.policies);
    if (checkIn == null && checkOut == null && policies.isEmpty) return const SizedBox.shrink();

    return InfoCard(
      title: s.stayPolicies,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (checkIn != null) Bullet(text: '${s.checkIn}: $checkIn'),
          if (checkOut != null) Bullet(text: '${s.checkOut}: $checkOut'),
          for (final p in policies) Bullet(text: p),
        ],
      ),
    );
  }
}

/// The amenities of a stay or room under their groups, groups and items in
/// the order `GET /amenities` gives them.
class AmenityGroups extends StatelessWidget {
  const AmenityGroups({super.key, required this.slugs, required this.bySlug});
  final List<String> slugs;
  final Map<String, Amenity> bySlug;

  @override
  Widget build(BuildContext context) {
    final known = [for (final slug in slugs) ?bySlug[slug]]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final groups = <String, List<String>>{};
    for (final a in known) {
      groups.putIfAbsent(a.groupName, () => []).add(a.name);
    }
    final other = [
      for (final slug in slugs)
        if (!bySlug.containsKey(slug)) labelOf(slug),
    ];
    if (other.isNotEmpty) groups.putIfAbsent('', () => []).addAll(other);
    final rank = _groupRank(bySlug);
    final names = groups.keys.toList()
      ..sort((a, b) => (a.isEmpty ? 999 : rank[a]!).compareTo(b.isEmpty ? 999 : rank[b]!));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final g in names) ...[
          if (g.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Row(
                children: [
                  Icon(amenityGroupIcon(g), size: 18, color: AppColors.violet),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      g,
                      style: AppText.sans(15.5, weight: FontWeight.w700, color: AppColors.violet),
                    ),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(groups[g]!.join('  ·  '), style: AppText.sans(12.5, color: AppColors.sand600, height: 1.6)),
          ),
        ],
      ],
    );
  }
}

/// The groups [slugs] fall in ("Bathroom", "Comfort"…), in the order
/// `GET /amenities` lists them; slugs it does not know are left out.
List<String> amenityGroupsOf(List<String> slugs, Map<String, Amenity> bySlug) {
  final rank = _groupRank(bySlug);
  final groups = {
    for (final slug in slugs)
      if (bySlug[slug]?.groupName case final g? when g.isNotEmpty) g,
  }.toList();
  return groups..sort((a, b) => rank[a]!.compareTo(rank[b]!));
}

/// `GET /amenities` keyed by slug.
Map<String, Amenity> amenitiesBySlug(List<Amenity> amenities) => {for (final a in amenities) a.slug: a};

/// Each group's place in the order `GET /amenities` first names it.
Map<String, int> _groupRank(Map<String, Amenity> bySlug) {
  final rank = <String, int>{};
  for (final a in bySlug.values) {
    rank.putIfAbsent(a.groupName, () => rank.length);
  }
  return rank;
}

/// A symbol for each amenity group the API has.
IconData amenityGroupIcon(String group) => switch (group) {
  'Accessibility' => Icons.accessible_rounded,
  'Bathroom' => Icons.bathtub_rounded,
  'Comfort' => Icons.weekend_rounded,
  'Family & pets' => Icons.child_friendly_rounded,
  'Food & drink' => Icons.local_cafe_rounded,
  'Internet' => Icons.wifi_rounded,
  'Parking & transport' => Icons.local_parking_rounded,
  'Safety & access' => Icons.verified_user_rounded,
  'Services' => Icons.room_service_rounded,
  'Space & outdoors' => Icons.park_rounded,
  'Tech & work' => Icons.tv_rounded,
  'Wellbeing' => Icons.spa_rounded,
  _ => Icons.check_circle_outline_rounded,
};
