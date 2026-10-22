import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/geo.dart';
import '../../core/utils/html_text.dart';
import '../../core/utils/polyline.dart';
import '../../data/api/ams_api.dart';
import '../../state/collections_provider.dart';
import '../../widgets/app_image.dart';
import '../../widgets/async_view.dart';
import '../../widgets/common.dart';
import '../../widgets/overview_card.dart';
import '../../widgets/destination_card.dart';
import '../../widgets/hero_app_bar.dart';
import '../../widgets/map_view.dart';
import '../destination/place_view.dart' show galleryUrls;
import '../destination/browse_record.dart';
import '../destination/reviews_section.dart';

/// What the corridor page reads: the itinerary (which carries the corridor
/// itself), its card for the rating, and the gallery. The reviews section loads its own.
class _CorridorData {
  const _CorridorData({
    required this.itinerary,
    required this.card,
    required this.photos,
    required this.about,
    required this.route,
  });

  final CorridorItinerary itinerary;
  final PlaceCard? card;

  /// The cover, then the gallery (`GET /media?ownerType=CORRIDOR`).
  final List<String> photos;

  /// The description as plain text, and the route decoded: worked out once,
  /// not on every build.
  final String about;
  final List<LatLng> route;
}

class CorridorScreen extends StatelessWidget {
  const CorridorScreen({super.key, required this.id});
  final String id;

  Future<_CorridorData> _load(AmsApi api) async {
    final (itinerary, card, media) = await (
      api.itinerary(id),
      api.card(id, type: CardType.corridor),
      // A gallery that fails to load leaves the cover alone.
      api.media(CardType.corridor, id).or(const []),
    ).wait;
    return _CorridorData(
      itinerary: itinerary,
      card: card,
      photos: galleryUrls(itinerary.corridor.coverUrl, media),
      about: htmlToText(itinerary.corridor.description ?? itinerary.corridor.shortDescription),
      route: decodePolyline(itinerary.encodedPolyline),
    );
  }

  @override
  Widget build(BuildContext context) {
    final api = context.read<AmsApi>();
    return BrowseRecorder(
      type: CardType.corridor,
      id: id,
      child: AsyncView<_CorridorData>(
        load: () => _load(api),
        loading: const Scaffold(body: LoadingView()),
        builder: (context, data, _) => _CorridorView(id: id, data: data),
      ),
    );
  }
}

class _CorridorView extends StatelessWidget {
  const _CorridorView({required this.id, required this.data});
  final String id;
  final _CorridorData data;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final c = data.itinerary.corridor;
    final stops = data.itinerary.stops;
    final rating = data.card?.averageRating;
    final reviewCount = data.card?.reviewCount ?? 0;
    final about = data.about;
    final route = data.route;
    final pinned = [
      for (final st in stops)
        if (st.place.latitude != null && st.place.longitude != null) st,
    ];
    final facts = [
      if (c.durationDays != null) (Icons.calendar_month_rounded, s.daysCount(c.durationDays!)),
      if (stops.isNotEmpty || c.stopCount != null)
        (Icons.location_on_rounded, s.fill(s.stopsCount, {'n': c.stopCount ?? stops.length})),
      if (c.totalDistanceKm != null) (Icons.route_rounded, '${formatKm(c.totalDistanceKm!)} $distanceUnit'),
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          HeroAppBar(
            height: 300,
            actions: [
              SaveButton(kind: SavedKind.corridor, itemKey: id, size: 44),
              GlassIconButton(
                icon: Icons.ios_share_rounded,
                tooltip: s.share,
                onPressed: () => SharePlus.instance.share(
                  ShareParams(
                    text: stops.isEmpty
                        ? c.name
                        : '${c.name}: ${stops.map((e) => e.title ?? e.place.name).join(' → ')}',
                  ),
                ),
              ),
            ],
            background: ClipRRect(
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
              child: _Gallery(photos: data.photos),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.only(bottom: bottomInset(context)),
            sliver: SliverList.list(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.name, style: AppText.display(26)),
                      // The Traveler seal belongs to destinations: none here.
                      if (rating != null) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.star_rounded, size: 16, color: AppColors.star),
                            const SizedBox(width: 3),
                            Flexible(
                              child: Text(
                                '${rating.toStringAsFixed(1)} (${s.reviewCountText(reviewCount)})',
                                style: AppText.sans(12.5, color: AppColors.sand600),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (facts.isNotEmpty) ...[const SizedBox(height: 14), _Facts(facts: facts)],
                      const SizedBox(height: 18),

                      if (c.expectations.isNotEmpty) ...[
                        Text(s.whatYouExpect, style: AppText.display(20)),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [for (final e in c.expectations) _ExpectChip(label: e)],
                        ),
                        const SizedBox(height: 18),
                      ],

                      if (about.isNotEmpty) ...[
                        OverviewCard(title: s.aboutThisCorridor, text: about),
                        const SizedBox(height: 22),
                      ],
                      if (stops.isNotEmpty) Text(s.routeOverview, style: AppText.display(20)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // The stops in one panel, their photos joined by the route line.
                if (stops.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: GradientFrame(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          for (var i = 0; i < stops.length; i++) _StopCard(stop: stops[i], last: i == stops.length - 1),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 18),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Material(
                    color: AppColors.violet,
                    shape: const StadiumBorder(),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => context.go(Routes.mapCorridor(id)),
                      child: SizedBox(
                        height: 52,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              s.startThisTrip,
                              style: AppText.sans(15.5, weight: FontWeight.w600, color: Colors.white),
                            ),
                            const SizedBox(width: 10),
                            const Icon(Icons.arrow_forward_rounded, size: 20, color: Colors.white),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 22),

                // The route as the server drew it, and the stops on it.
                if (pinned.isNotEmpty || route.isNotEmpty)
                  _MapPanel(
                    title: s.corridorsMap,
                    subtitle: '${s.exploreThrough} ${c.name}',
                    child: MapPreview(
                      height: 300,
                      child: AppMap(
                        // The server's own route, already on the roads.
                        routes: [if (route.length > 1) MapRoute(route)],
                        fitPadding: const EdgeInsets.all(40),
                        pins: [
                          for (final st in pinned)
                            MapPin(
                              id: '${st.sequence}-${st.place.id}',
                              point: LatLng(st.place.latitude!, st.place.longitude!),
                              pillText: st.title ?? st.place.name,
                              color: AppColors.violet,
                              onTap: () => context.push(Routes.place(st.place.id)),
                            ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 18),

                // The same reviews section as every other place's page.
                ReviewsSection(type: CardType.corridor, id: id, average: rating, count: data.card?.reviewCount),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The trip at a glance: days, stops and distance side by side in one
/// slim card, each with its symbol in a small violet circle beside it.
class _Facts extends StatelessWidget {
  const _Facts({required this.facts});
  final List<(IconData, String)> facts;

  @override
  Widget build(BuildContext context) {
    return GradientFrame(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      child: IntrinsicHeight(
        child: Row(
          children: [
            for (final (i, (icon, label)) in facts.indexed) ...[
              if (i > 0) VerticalDivider(width: 1, thickness: 1, color: AppColors.violet.withValues(alpha: 0.15)),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(color: AppColors.violet.withValues(alpha: 0.1), shape: BoxShape.circle),
                      child: Icon(icon, size: 14, color: AppColors.violet),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.sans(13, weight: FontWeight.w600, color: AppColors.sand900),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// One thing the corridor promises, in a red outlined pill.
class _ExpectChip extends StatelessWidget {
  const _ExpectChip({required this.label});
  final String label;

  static const _red = Color(0xFFE5254B);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: _red, width: 1.2),
      ),
      child: Text(label, style: AppText.sans(13, weight: FontWeight.w500, color: _red)),
    );
  }
}

/// One stop in the route overview: the place's photo on the route line,
/// then its name, where it is, and what is there, in a card of its own.
class _StopCard extends StatelessWidget {
  const _StopCard({required this.stop, required this.last});

  final ItineraryStop stop;

  /// The last stop has no line running down to a next one.
  final bool last;

  static const _photo = 76.0;

  @override
  Widget build(BuildContext context) {
    final place = stop.place;
    final title = stop.title ?? place.name;
    // The stop's own words when the itinerary has them, else the place's.
    final description = htmlToText(stop.description ?? place.shortDescription);
    final arrival = stop.arrivalTime;
    final subtitle = [
      if (place.name != title) place.name,
      ?place.provinceName,
      if (arrival != null && arrival.length >= 5) arrival.substring(0, 5),
    ].join(' · ');

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: _photo,
            child: Column(
              children: [
                // The place's photo in a violet frame, with a pin on it.
                Container(
                  width: _photo,
                  height: _photo,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.violet, width: 2),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      AppImage(place.coverUrl, radius: BorderRadius.circular(14)),
                      Positioned(
                        right: 4,
                        top: 4,
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.92),
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: const Icon(Icons.location_on_rounded, size: 15, color: AppColors.violet),
                        ),
                      ),
                    ],
                  ),
                ),
                // The route on to the next stop.
                if (!last) Expanded(child: Container(width: 2, color: AppColors.violet)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: last ? 0 : 12),
              child: GradientFrame(
                padding: EdgeInsets.zero,
                radius: 16,
                color: const Color(0xFFEFEFF1),
                child: InkWell(
                  borderRadius: BorderRadius.circular(15),
                  onTap: () => context.push(Routes.place(place.id)),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: AppText.sans(15.5, weight: FontWeight.w600, color: AppColors.sand900),
                        ),
                        if (subtitle.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: AppText.sans(11.5, weight: FontWeight.w600, color: AppColors.sand500),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        if (description.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            description,
                            style: AppText.sans(12, color: AppColors.sand500, height: 1.45),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The corridor's map in a [GradientCard], with the page's side margins.
class _MapPanel extends StatelessWidget {
  const _MapPanel({required this.title, required this.subtitle, required this.child});
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 18),
    child: GradientCard(title: title, subtitle: subtitle, child: child),
  );
}

/// The cover and the gallery, swiped sideways, with "2 / 5" in the corner.
class _Gallery extends StatefulWidget {
  const _Gallery({required this.photos});
  final List<String> photos;

  @override
  State<_Gallery> createState() => _GalleryState();
}

class _GalleryState extends State<_Gallery> {
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final photos = widget.photos.isEmpty ? const [''] : widget.photos;
    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          itemCount: photos.length,
          onPageChanged: (i) => setState(() => _page = i),
          itemBuilder: (_, i) => AppImage(photos[i]),
        ),
        if (photos.length > 1)
          Positioned(
            right: 14,
            bottom: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(
                '${_page + 1} / ${photos.length}',
                style: AppText.sans(12, weight: FontWeight.w600, color: Colors.white),
              ),
            ),
          ),
      ],
    );
  }
}
