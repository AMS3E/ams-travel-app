import 'dart:async';

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_theme.dart';
import '../../data/api/ams_api.dart';
import '../../state/collections_provider.dart';
import '../../widgets/async_view.dart';
import 'browse_record.dart';
import 'place_view.dart';
import 'reviews_section.dart';

/// Everything the top of an attraction page needs, read in one go.
class _PlaceData {
  const _PlaceData({required this.place, this.card, this.media = const [], this.categories = const []});

  final PlaceDetail place;

  /// Rating, review count and seal.
  final PlaceCard? card;
  final List<MediaItem> media;

  /// Category names, in the place's order.
  final List<String> categories;
}

/// An attraction: `GET /destinations/{id}`, its gallery, its card for the
/// rating and seal, the categories by name, then a check-in, the reviews,
/// and what is nearby (places, stays, food, activities), each loading on its
/// own.
class DestinationScreen extends StatelessWidget {
  const DestinationScreen({super.key, required this.id});
  final String id;

  Future<_PlaceData> _load(AmsApi api) async {
    final (place, card, media, categories) = await (
      api.destination(id),
      api.card(id, type: CardType.destination).orNull,
      api.media(CardType.destination, id).or(const []),
      api.categories().or(const []),
    ).wait;
    final byId = {for (final c in categories) c.id: c.name};
    return _PlaceData(
      place: place,
      card: card,
      media: media,
      categories: [for (final id in place.categoryIds) ?byId[id]],
    );
  }

  @override
  Widget build(BuildContext context) {
    final api = context.read<AmsApi>();
    return BrowseRecorder(
      type: CardType.destination,
      id: id,
      child: AsyncView<_PlaceData>(
        load: () => _load(api),
        loading: const Scaffold(body: LoadingView()),
        builder: (context, data, _) => Scaffold(body: _AttractionView(data: data)),
      ),
    );
  }
}

class _AttractionView extends StatelessWidget {
  const _AttractionView({required this.data});
  final _PlaceData data;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final p = data.place;
    final card = data.card;

    return CustomScrollView(
      slivers: [
        PlaceHero(
          photos: galleryUrls(p.coverUrl, data.media),
          kind: SavedKind.destination,
          id: p.id,
          shareText: shareTextFor(p.name, line: p.shortDescription, latitude: p.latitude, longitude: p.longitude),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.name, style: AppText.display(24)),
                const SizedBox(height: 8),
                // The seal, then the score under it.
                SealLine(card: card),
                RatingLine(average: card?.averageRating, count: card?.reviewCount ?? 0),
                if (data.categories.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Wrap(spacing: 8, runSpacing: 8, children: [for (final c in data.categories) CategoryTag(label: c)]),
                ],
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: SloganQuote(slogan: p.slogan, by: p.sloganBy),
        ),
        // The Highlights / About sheet of the design is this same text.
        SliverToBoxAdapter(
          child: DescriptionCard(short: p.shortDescription, long: p.description),
        ),
        if (p.hasPin)
          SliverToBoxAdapter(
            child: LocationCard(
              id: p.id,
              address: p.address,
              latitude: p.latitude!,
              longitude: p.longitude!,
              onFullMap: () => context.go(Routes.mapFocus(p.id)),
            ),
          ),
        SliverToBoxAdapter(
          child: ReviewsSection(
            type: CardType.destination,
            id: p.id,
            average: card?.averageRating,
            count: card?.reviewCount,
          ),
        ),
        // Other attractions within 5 km, nearest first, each with its
        // distance from this one.
        SliverToBoxAdapter(
          child: NearbyRow(title: s.recommendNearby, type: CardType.destination, near: p.id, radiusKm: 5),
        ),
        SliverToBoxAdapter(
          child: NearbyRow(title: s.staysNearby, type: CardType.stay, near: p.id),
        ),
        SliverToBoxAdapter(
          child: NearbyRow(title: s.foodNearby, type: CardType.food, near: p.id),
        ),
        SliverToBoxAdapter(
          child: NearbyRow(title: s.activitiesNearby, type: CardType.activity, near: p.id),
        ),
        SliverToBoxAdapter(child: bottomGap(context)),
      ],
    );
  }
}
