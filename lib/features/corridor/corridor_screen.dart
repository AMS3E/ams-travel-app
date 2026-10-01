import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/geo.dart';
import '../../data/models/models.dart';
import '../../data/repositories/travel_repository.dart';
import '../../state/collections_provider.dart';
import '../../widgets/app_image.dart';
import '../../widgets/async_view.dart';
import '../../widgets/common.dart';
import '../../widgets/destination_card.dart';
import '../../widgets/map_view.dart';

/// The sights a stop is known for, so the route overview shows a temple
/// rather than the coffee shop that happens to sit next to it.
const _sightCategories = {
  'Temples',
  'Ancient Cities',
  'Ancient Roads',
  'Archaeological Sites',
  'Museums',
  'Sacred Mountain',
  'Mountain',
  'National Park',
  'Waterfall',
  'Viewpoint',
  'Cave',
  'Bridges',
  'Village',
};

/// Stay categories, for the "Where to Stay" row.
const _stayCategories = {'Homestay', 'Eco Lodge', 'Luxury Hotel', 'Private Island'};

/// What a traveller may want along the way, and the categories that answer it.
/// TODO(api): fuel, groceries and pharmacies need a places-of-interest feed.
const _experiences = <String, Set<String>>{
  'Restaurants': {'Traditional Food', 'Fine Dining', 'Seafood', 'Michelin'},
  'Hotels': _stayCategories,
  'Street food': {'Street Food', 'Night Market'},
  'Coffee': {'Coffee'},
  'Markets': {'Night Market', 'Shopping'},
  'Hospitals': {'Hospitals'},
};

class CorridorScreen extends StatelessWidget {
  const CorridorScreen({super.key, required this.slug});
  final String slug;

  @override
  Widget build(BuildContext context) {
    final repo = context.read<TravelRepository>();
    return AsyncView<(Corridor, List<Destination>)>(
      load: () => (repo.getCorridor(slug), repo.getDestinations()).wait,
      loading: const Scaffold(body: LoadingView()),
      builder: (context, data, _) => _CorridorView(corridor: data.$1, all: data.$2),
    );
  }
}

class _CorridorView extends StatefulWidget {
  const _CorridorView({required this.corridor, required this.all});
  final Corridor corridor;
  final List<Destination> all;

  @override
  State<_CorridorView> createState() => _CorridorViewState();
}

class _CorridorViewState extends State<_CorridorView> {
  final _map = MapController();
  final _photos = PageController();
  int _photo = 0;

  Corridor get corridor => widget.corridor;
  List<Destination> get all => widget.all;

  /// Places within 35 km of any stop, nearest to the route first.
  late final List<Destination> _along = () {
    final list = <(Destination, double)>[];
    for (final d in all) {
      var best = double.infinity;
      for (final st in corridor.stops) {
        final km = distanceKm(st.lat, st.lng, d.lat, d.lng);
        if (km < best) best = km;
      }
      if (best <= 35) list.add((d, best));
    }
    list.sort((a, b) => a.$2.compareTo(b.$2));
    return [for (final (d, _) in list) d];
  }();

  /// The corridor's own photo, then the places it passes.
  List<String> get _gallery => <String>{
    corridor.image,
    for (final d in _along.where((d) => d.featured)) d.image,
    for (final d in _along) d.image,
  }.take(6).toList();

  /// A corridor has no score of its own, so it carries the places along it.
  /// TODO(api): send a rating and review count per corridor.
  (double?, int) get _score {
    final rated = _along.where((d) => d.rating != null).toList();
    if (rated.isEmpty) return (null, 0);
    final sum = rated.map((d) => d.rating!).reduce((a, b) => a + b);
    final reviews = _along.fold(0, (n, d) => n + (d.reviewCount ?? 0));
    return (sum / rated.length, reviews);
  }

  /// The place that stands for a stop in the route overview: one that carries
  /// its name if there is one, else the nearest sight, else the nearest place.
  Destination? _faceOf(CorridorStop stop) {
    final name = stop.name.toLowerCase();
    Destination? best;
    var bestScore = -1e9;
    for (final d in all) {
      final km = distanceKm(stop.lat, stop.lng, d.lat, d.lng);
      if (km > 45) continue;
      var score = -km;
      if (d.name.toLowerCase().contains(name) || name.contains(d.name.toLowerCase())) score += 500;
      if (_sightCategories.contains(d.category)) score += 200;
      if (d.featured) score += 50;
      if (score > bestScore) {
        bestScore = score;
        best = d;
      }
    }
    return best;
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final c = corridor;
    final points = [for (final st in c.stops) LatLng(st.lat, st.lng)];
    final (rating, reviews) = _score;
    final stays = _along.where((d) => _stayCategories.contains(d.category)).take(6).toList();
    final categories = _along.map((d) => d.category).toSet();
    final experiences = [
      for (final e in _experiences.entries)
        if (e.value.any(categories.contains)) e.key,
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      body: ListView(
        padding: EdgeInsets.only(bottom: 28 + MediaQuery.paddingOf(context).bottom),
        children: [
          // Photos, with the corridor's own first.
          SizedBox(
            height: 300,
            child: Stack(
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
                    child: PageView(
                      controller: _photos,
                      onPageChanged: (i) => setState(() => _photo = i),
                      children: [for (final url in _gallery) AppImage(url)],
                    ),
                  ),
                ),
                Positioned(
                  left: 10,
                  right: 10,
                  top: MediaQuery.paddingOf(context).top + 4,
                  child: Row(
                    children: [
                      GlassIconButton(
                        icon: Icons.chevron_left_rounded,
                        tooltip: s.back,
                        onPressed: () => context.pop(),
                      ),
                      const Spacer(),
                      SaveButton(kind: SavedKind.corridor, itemKey: c.slug, dark: true, size: 40),
                      const SizedBox(width: 8),
                      GlassIconButton(
                        icon: Icons.ios_share_rounded,
                        tooltip: s.share,
                        onPressed: () => SharePlus.instance.share(
                          ShareParams(
                            text: '${c.name} (${c.duration}): ${c.stops.map((e) => e.name).join(' → ')}',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 18,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < _gallery.length; i++)
                        Container(
                          width: i == _photo ? 18 : 6,
                          height: 6,
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: i == _photo ? 1 : 0.5),
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                    ],
                  ),
                ),
                Positioned(
                  right: 14,
                  bottom: 14,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.photo_library_outlined, size: 14, color: Colors.white),
                        const SizedBox(width: 6),
                        Text(
                          '${s.gallery} ${_gallery.length}',
                          style: AppText.sans(12, weight: FontWeight.w600, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(c.name, style: AppText.display(26)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.verified_rounded, size: 15, color: Color(0xFF34D399)),
                    const SizedBox(width: 5),
                    Text(s.recommendByTraveler, style: AppText.sans(12.5, color: AppColors.sand600)),
                    if (rating != null) ...[
                      const SizedBox(width: 12),
                      const Icon(Icons.star_rounded, size: 16, color: AppColors.star),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          '${rating.toStringAsFixed(1)} (${thousands(reviews)} ${s.reviewsWord.toLowerCase()})',
                          style: AppText.sans(12.5, color: AppColors.sand600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 14),

                // Every stop, as a chip.
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final st in c.stops)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(color: AppColors.violet.withValues(alpha: 0.45)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.place_outlined, size: 14, color: AppColors.violet),
                            const SizedBox(width: 5),
                            Text(
                              st.name,
                              style: AppText.sans(12.5, weight: FontWeight.w600, color: AppColors.violet),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 22),
                Text(s.routeOverview, style: AppText.sans(17, weight: FontWeight.w700, color: AppColors.sand900)),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // The stops in order: a photo each, numbered along a line.
          SizedBox(
            height: 112,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              itemCount: c.stops.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) => _StopStep(
                index: i + 1,
                stop: c.stops[i],
                face: _faceOf(c.stops[i]),
                isLast: i == c.stops.length - 1,
              ),
            ),
          ),
          const SizedBox(height: 18),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.violet,
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () => context.go(Routes.mapCorridor(c.slug)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(s.startThisTrip, style: AppText.sans(15.5, weight: FontWeight.w700, color: Colors.white)),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward_rounded, size: 18, color: Colors.white),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),

          // The route on a map, stops named.
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 18),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.sand200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.corridorsMap, style: AppText.sans(16, weight: FontWeight.w700, color: AppColors.sand900)),
                const SizedBox(height: 3),
                Text(
                  '${s.exploreThrough} ${c.name}',
                  style: AppText.sans(12.5, color: AppColors.sand500),
                ),
                const SizedBox(height: 12),
                MapPreview(
                  height: 300,
                  child: AppMap(
                    controller: _map,
                    routes: [if (c.sequential) MapRoute(points)],
                    fitPadding: const EdgeInsets.all(40),
                    pins: [
                      for (var i = 0; i < c.stops.length; i++)
                        MapPin(
                          id: c.stops[i].name,
                          point: points[i],
                          pillText: c.stops[i].name,
                          color: AppColors.violet,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          if (stays.isNotEmpty) ...[
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      s.whereToStay,
                      style: AppText.sans(17, weight: FontWeight.w700, color: AppColors.sand900),
                    ),
                  ),
                  Material(
                    color: AppColors.violet,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => context.push('${Routes.search}?q=${Uri.encodeQueryComponent(c.stops.first.name)}'),
                      child: const Padding(
                        padding: EdgeInsets.all(5),
                        child: Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 178,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                itemCount: stays.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (_, i) => _StayCard(destination: stays[i]),
              ),
            ),
          ],

          if (experiences.isNotEmpty) ...[
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.exploreExperiences,
                    style: AppText.sans(17, weight: FontWeight.w700, color: AppColors.sand900),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final label in experiences)
                        InkWell(
                          borderRadius: BorderRadius.circular(99),
                          onTap: () => context.push(
                            '${Routes.search}?q=${Uri.encodeQueryComponent(_experiences[label]!.first)}',
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(99),
                              border: Border.all(color: AppColors.sunset300),
                            ),
                            child: Text(
                              label,
                              style: AppText.sans(13, weight: FontWeight.w500, color: AppColors.sand800),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// One stop in the route overview: its photo, its number, and the line on to
/// the next one.
class _StopStep extends StatelessWidget {
  const _StopStep({required this.index, required this.stop, required this.face, required this.isLast});
  final int index;
  final CorridorStop stop;
  final Destination? face;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 66,
      child: Column(
        children: [
          SizedBox(
            width: 66,
            height: 66,
            child: face == null
                ? const SizedBox()
                : AppImage(face!.image, radius: BorderRadius.circular(12)),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: Container(height: 2, color: index == 1 ? Colors.transparent : AppColors.violet)),
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: const BoxDecoration(color: AppColors.violet, shape: BoxShape.circle),
                child: Text('$index', style: AppText.sans(11, weight: FontWeight.w700, color: Colors.white)),
              ),
              Expanded(child: Container(height: 2, color: isLast ? Colors.transparent : AppColors.violet)),
            ],
          ),
        ],
      ),
    );
  }
}

/// A place to sleep along the way.
class _StayCard extends StatelessWidget {
  const _StayCard({required this.destination});
  final Destination destination;

  @override
  Widget build(BuildContext context) {
    final d = destination;
    final (title, _) = bilingual(context, d.name, d.nameKh);
    return GestureDetector(
      onTap: () => context.push(Routes.destination(d.region, d.slug)),
      child: SizedBox(
        width: 146,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 112,
              width: double.infinity,
              child: AppImage(d.image, radius: BorderRadius.circular(14)),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: AppText.sans(13, weight: FontWeight.w700, color: AppColors.sand900),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                if (d.rating != null) ...[
                  Text(
                    d.rating!.toStringAsFixed(1),
                    style: AppText.sans(12, weight: FontWeight.w700, color: AppColors.sand900),
                  ),
                  const SizedBox(width: 4),
                  Stars(d.rating!.round(), size: 10),
                  const SizedBox(width: 6),
                ],
                Flexible(
                  child: Text(
                    d.category,
                    style: AppText.sans(11.5, color: AppColors.sand500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
