import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/opening_hours.dart';
import '../../data/api/ams_api.dart';
import '../../state/collections_provider.dart';
import '../../widgets/async_view.dart';
import '../../widgets/interest_style.dart';
import 'contact_card.dart';
import 'place_view.dart';
import 'browse_record.dart';
import 'reviews_section.dart';

/// A food place: `GET /foods/{id}` and its gallery. Price range, the hours
/// with open or closed now (Cambodia time), cuisines and meals, contacts,
/// slogan, description, map, reviews, and other food near the place it
/// belongs to. The menu is out of scope.
class FoodScreen extends StatelessWidget {
  const FoodScreen({super.key, required this.id});
  final String id;

  /// The place, its gallery, the interests for its Food labels
  /// ("Restaurants", "Traditional Food"; its `categoryIds` are shared with
  /// attractions, "Fishing", so they are not shown) and its card, for the
  /// seal: `verified` is on the card, not on `GET /foods/{id}`.
  Future<(FoodDetail, List<MediaItem>, List<CatalogInterest>, PlaceCard?)> _load(AmsApi api) => (
    api.food(id),
    api.media(CardType.food, id).or(const []),
    api.interests().or(const []),
    api.card(id, type: CardType.food).orNull,
  ).wait;

  @override
  Widget build(BuildContext context) {
    final api = context.read<AmsApi>();
    return BrowseRecorder(
      type: CardType.food,
      id: id,
      child: AsyncView<(FoodDetail, List<MediaItem>, List<CatalogInterest>, PlaceCard?)>(
        load: () => _load(api),
        loading: const Scaffold(body: LoadingView()),
        builder: (context, data, _) => Scaffold(
          body: _FoodView(
            food: data.$1,
            media: data.$2,
            card: data.$4,
            interests: [
              for (final i in data.$3)
                if (data.$1.interestIds.contains(i.id)) i,
            ],
          ),
        ),
      ),
    );
  }
}

class _FoodView extends StatelessWidget {
  const _FoodView({required this.food, required this.media, required this.card, required this.interests});
  final FoodDetail food;
  final List<MediaItem> media;

  /// For the seal; null when the card could not be read.
  final PlaceCard? card;

  /// Its Food interests, as the API orders them.
  final List<CatalogInterest> interests;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final f = food;

    return CustomScrollView(
      slivers: [
        PlaceHero(
          photos: galleryUrls(f.coverUrl, media),
          kind: SavedKind.food,
          id: f.id,
          shareText: shareTextFor(f.name, line: f.shortDescription, latitude: f.latitude, longitude: f.longitude),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(f.name, style: AppText.display(24)),
                const SizedBox(height: 8),
                // The seal, then the score under it, as on an attraction.
                SealLine(card: card),
                RatingLine(average: f.averageRating, count: f.reviewCount),
                _PriceLine(food: f),
                // What kind of food place it is, under the stars.
                if (interests.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [for (final i in interests) CategoryTag(label: i.name, icon: interestIcon(i))],
                  ),
                ],
                if (f.openNow != null) ...[
                  const SizedBox(height: 12),
                  _OpenLine(openNow: f.openNow!, todayHours: f.todayHours),
                ],
              ],
            ),
          ),
        ),
        if (f.cuisines.isNotEmpty || f.mealsServed.isNotEmpty)
          SliverToBoxAdapter(
            child: InfoCard(
              title: s.aboutPlace,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (f.cuisines.isNotEmpty)
                    _AboutRow(
                      icon: Icons.restaurant_rounded,
                      label: s.cuisines,
                      value: f.cuisines.map(labelOf).join(', '),
                    ),
                  if (f.cuisines.isNotEmpty && f.mealsServed.isNotEmpty) const SizedBox(height: 12),
                  if (f.mealsServed.isNotEmpty)
                    _AboutRow(
                      icon: Icons.schedule_rounded,
                      label: s.serving,
                      value: f.mealsServed.map(labelOf).join('   '),
                    ),
                ],
              ),
            ),
          ),
        SliverToBoxAdapter(
          child: SloganQuote(slogan: f.slogan, by: f.sloganBy),
        ),
        SliverToBoxAdapter(
          child: ContactButtons(phone: f.phone, website: f.website, column: false),
        ),
        SliverToBoxAdapter(
          child: DescriptionCard(short: f.shortDescription, long: f.description),
        ),
        if (f.openingHours.isNotEmpty) SliverToBoxAdapter(child: _HoursCard(hours: f.openingHours)),
        if (f.hasPin)
          SliverToBoxAdapter(
            child: LocationCard(id: f.id, address: f.address, latitude: f.latitude!, longitude: f.longitude!),
          ),
        SliverToBoxAdapter(
          child: ReviewsSection(type: CardType.food, id: f.id, average: f.averageRating, count: f.reviewCount),
        ),
        // Other food near the place this one belongs to.
        if (f.destinationId != null)
          SliverToBoxAdapter(
            child: NearbyRow(title: s.foodNearby, type: CardType.food, near: f.destinationId!, excludeId: f.id),
          ),
        SliverToBoxAdapter(child: bottomGap(context)),
      ],
    );
  }
}

/// How dear the place is: its "$" to "$$$$" tier with a money symbol.
/// Nothing when the place gives none.
class _PriceLine extends StatelessWidget {
  const _PriceLine({required this.food});
  final FoodDetail food;

  @override
  Widget build(BuildContext context) {
    final tier = food.priceRange?.trim() ?? '';
    if (tier.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          const Icon(Icons.payments_outlined, size: 20, color: AppColors.violet),
          const SizedBox(width: 8),
          Text(
            tier,
            style: AppText.sans(14, weight: FontWeight.w700, color: AppColors.violet),
          ),
        ],
      ),
    );
  }
}

/// Whether the kitchen is open now, and today's hours: both from the server
/// (`openNow`, `todayHours`), worked out in Cambodia time.
class _OpenLine extends StatelessWidget {
  const _OpenLine({required this.openNow, this.todayHours});
  final bool openNow;

  /// "07:00-22:00" or "closed".
  final String? todayHours;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final today = formatHoursLine(todayHours);
    return Row(
      children: [
        OutlineTag(
          label: openNow ? s.openNowPill : s.closeNow,
          icon: Icons.schedule_rounded,
          color: openNow ? AppColors.success : AppColors.sunset600,
        ),
        if (todayHours != null) ...[
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              today == null ? s.closedToday : s.fill(s.todayHours, {'hours': today}),
              style: AppText.sans(13.5, color: AppColors.sand600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ],
    );
  }
}

/// The week's hours, Monday first, today in bold; a shut day says Closed.
class _HoursCard extends StatelessWidget {
  const _HoursCard({required this.hours});
  final Map<String, String> hours;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final names = [s.dayMonday, s.dayTuesday, s.dayWednesday, s.dayThursday, s.dayFriday, s.daySaturday, s.daySunday];
    final today = cambodiaWeekday();

    return InfoCard(
      title: s.openingHours,
      child: Column(
        children: [
          for (var d = 1; d <= 7; d++)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 110,
                    child: Text(
                      names[d - 1],
                      style: AppText.sans(
                        13.5,
                        weight: d == today ? FontWeight.w700 : FontWeight.w400,
                        color: AppColors.sand700,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      dayHoursText(hours, d) ?? s.closedNow,
                      style: AppText.sans(
                        13.5,
                        weight: d == today ? FontWeight.w700 : FontWeight.w500,
                        color: AppColors.sand900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// One line of the About card: what it is, and what it says.
class _AboutRow extends StatelessWidget {
  const _AboutRow({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 17, color: AppColors.sand700),
        const SizedBox(width: 10),
        SizedBox(
          width: 74,
          child: Text(label, style: AppText.sans(13, color: AppColors.sand500)),
        ),
        Expanded(
          child: Text(
            value,
            style: AppText.sans(13.5, weight: FontWeight.w600, color: AppColors.sand900),
          ),
        ),
      ],
    );
  }
}
