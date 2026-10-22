import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../data/api/ams_api.dart';
import '../../state/collections_provider.dart';
import '../../widgets/async_view.dart';
import '../../widgets/interest_style.dart';
import 'browse_record.dart';
import 'contact_card.dart';
import 'place_view.dart';
import 'reviews_section.dart';

/// An activity (a dive trip, a kayak tour, a trek, a cruise):
/// `GET /activities/{id}` and its gallery, its card for the rating, review
/// count and seal, and its interests for the chips. Then the organiser's
/// contacts, slogan, description, map, check-in, reviews, and other
/// activities near the place it belongs to. No price, duration or hours yet.
class ActivityScreen extends StatelessWidget {
  const ActivityScreen({super.key, required this.id});
  final String id;

  Future<(ActivityDetail, List<MediaItem>, List<CatalogInterest>, PlaceCard?)> _load(AmsApi api) => (
    api.activity(id),
    api.media(CardType.activity, id).or(const []),
    api.interests().or(const []),
    api.card(id, type: CardType.activity).orNull,
  ).wait;

  @override
  Widget build(BuildContext context) {
    final api = context.read<AmsApi>();
    return BrowseRecorder(
      type: CardType.activity,
      id: id,
      child: AsyncView<(ActivityDetail, List<MediaItem>, List<CatalogInterest>, PlaceCard?)>(
        load: () => _load(api),
        loading: const Scaffold(body: LoadingView()),
        builder: (context, data, _) => Scaffold(
          body: _ActivityView(
            activity: data.$1,
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

class _ActivityView extends StatelessWidget {
  const _ActivityView({required this.activity, required this.media, required this.card, required this.interests});
  final ActivityDetail activity;
  final List<MediaItem> media;

  /// Rating, review count and seal; null when the card could not be read.
  final PlaceCard? card;

  /// Its interests ("Cruise", "Wildlife"), as the API orders them.
  final List<CatalogInterest> interests;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final a = activity;
    final (typeIcon, typeColour) = groupStyle(InterestGroup.activities);
    // The type says the same as an interest of the same name ("Cruise"):
    // shown only when no such interest is.
    final type = a.type;
    final showType = type != null && !interests.any((i) => i.slug.replaceAll('-', '_').toUpperCase() == type);

    return CustomScrollView(
      slivers: [
        PlaceHero(
          photos: galleryUrls(a.coverUrl, media),
          kind: SavedKind.activity,
          id: a.id,
          shareText: shareTextFor(a.name, line: a.shortDescription, latitude: a.latitude, longitude: a.longitude),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(a.name, style: AppText.display(24)),
                const SizedBox(height: 8),
                SealLine(card: card),
                RatingLine(average: card?.averageRating, count: card?.reviewCount ?? 0),
                const SizedBox(height: 14),
                // What kind of activity, then the interests it is listed under.
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (showType) CategoryTag(label: s.activityType(type), icon: typeIcon, color: typeColour),
                    for (final i in interests) CategoryTag(label: i.name, icon: interestIcon(i)),
                  ],
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: SloganQuote(slogan: a.slogan, by: a.sloganBy),
        ),
        // The organiser: the app takes no bookings, so this is the way to one.
        SliverToBoxAdapter(
          child: ContactButtons(
            phone: a.phone,
            website: a.website,
            email: a.contactEmail,
            telegram: a.telegram,
            whatsapp: a.whatsapp,
            facebookUrl: a.facebookUrl,
            column: false,
          ),
        ),
        SliverToBoxAdapter(
          child: DescriptionCard(short: a.shortDescription, long: a.description),
        ),
        if (a.hasPin)
          SliverToBoxAdapter(
            child: LocationCard(id: a.id, address: a.address, latitude: a.latitude!, longitude: a.longitude!),
          ),
        SliverToBoxAdapter(
          child: ReviewsSection(
            type: CardType.activity,
            id: a.id,
            average: card?.averageRating,
            count: card?.reviewCount,
          ),
        ),
        // Other activities around the place this one starts from.
        if (a.destinationId != null)
          SliverToBoxAdapter(
            child: NearbyRow(
              title: s.activitiesNearby,
              type: CardType.activity,
              near: a.destinationId!,
              excludeId: a.id,
            ),
          ),
        SliverToBoxAdapter(child: bottomGap(context)),
      ],
    );
  }
}
