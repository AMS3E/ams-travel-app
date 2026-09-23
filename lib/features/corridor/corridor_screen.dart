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
import '../../widgets/detail_scaffold.dart';
import '../../widgets/map_view.dart';

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

  /// The place picked out of the day-by-day plan, pinned on the map. The day
  /// is part of it because the same place can appear on more than one day.
  Destination? _focus;
  int? _focusDay;

  Corridor get corridor => widget.corridor;
  List<Destination> get all => widget.all;

  /// Moves the map to a place from the plan and marks it, on that day only.
  void _focusOn(int day, Destination d) {
    setState(() {
      _focus = d;
      _focusDay = day;
    });
    try {
      _map.move(LatLng(d.lat, d.lng), 12);
    } catch (_) {}
  }

  /// Up to three places within 35 km of a stop, nearest first.
  List<(Destination, double)> _near(CorridorStop stop) {
    final list = [
      for (final d in all)
        if (distanceKm(stop.lat, stop.lng, d.lat, d.lng) <= 35) (d, distanceKm(stop.lat, stop.lng, d.lat, d.lng)),
    ]..sort((a, b) => a.$2.compareTo(b.$2));
    final seen = <String>{};
    return list.where((e) => seen.add(e.$1.name)).take(3).toList();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final c = corridor;
    final points = [for (final st in c.stops) LatLng(st.lat, st.lng)];

    return DetailScaffold(
      title: c.name,
      image: c.image,
      expandedHeight: 380,
      actions: [
        SaveButton(kind: SavedKind.corridor, itemKey: c.slug, size: 44),
        GlassIconButton(
          icon: Icons.ios_share_rounded,
          tooltip: s.share,
          onPressed: () => SharePlus.instance.share(
            ShareParams(text: '${c.name} (${c.duration}): ${c.stops.map((e) => e.name).join(' → ')}'),
          ),
        ),
      ],
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Pill.onImage(c.duration, icon: Icons.schedule_rounded),
          const SizedBox(height: 12),
          Text(c.name, style: AppText.display(32, color: Colors.white)),
          const SizedBox(height: 8),
          Text(c.description, style: AppText.sans(14.5, color: Colors.white.withValues(alpha: 0.85), height: 1.45)),
          const SizedBox(height: 12),
          Text(
            '${c.stops.length} ${s.stops.toLowerCase()}',
            style: AppText.sans(13, weight: FontWeight.w600, color: AppColors.sunset200),
          ),
        ],
      ),
      slivers: [
        SliverToBoxAdapter(
          child: DetailSection(
            title: s.theRoute,
            child: MapPreview(
              height: 300,
              child: AppMap(
                controller: _map,
                routes: [if (c.sequential) MapRoute(points)],
                fitPadding: const EdgeInsets.all(40),
                pins: [
                  for (var i = 0; i < c.stops.length; i++)
                    MapPin(id: c.stops[i].name, point: points[i], label: '${i + 1}', color: AppColors.route),
                  if (_focus != null)
                    MapPin(
                      id: _focus!.key,
                      point: LatLng(_focus!.lat, _focus!.lng),
                      highlighted: true,
                      onTap: () => context.push(Routes.destination(_focus!.region, _focus!.slug)),
                    ),
                ],
              ),
            ),
          ),
        ),
        if (c.itinerary.isNotEmpty)
          SliverToBoxAdapter(
            child: DetailSection(
              title: s.dayByDay,
              subtitle: '${c.days ?? c.itinerary.length} ${s.daysWord}',
              child: Column(
                children: [
                  for (var i = 0; i < c.itinerary.length; i++)
                    _DayRow(
                      day: c.itinerary[i],
                      isLast: i == c.itinerary.length - 1,
                      places: [
                        for (final key in c.itinerary[i].places)
                          ...all.where((d) => d.key == key),
                      ],
                      focused: _focusDay == c.itinerary[i].day ? _focus : null,
                      onPlace: (d) => _focusOn(c.itinerary[i].day, d),
                    ),
                ],
              ),
            ),
          ),
        SliverToBoxAdapter(
          child: DetailSection(
            title: s.stops,
            child: Column(
              children: [
                for (var i = 0; i < c.stops.length; i++)
                  _StopRow(
                    index: i + 1,
                    stop: c.stops[i],
                    isLast: i == c.stops.length - 1,
                    sequential: c.sequential,
                    near: _near(c.stops[i]),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// One day of the plan: the number, where it runs from and to, and what it
/// covers — joined by a line down the left.
class _DayRow extends StatelessWidget {
  const _DayRow({
    required this.day,
    required this.isLast,
    required this.places,
    required this.onPlace,
    this.focused,
  });

  final CorridorDay day;
  final bool isLast;

  /// The places this day takes in; tapping one moves the map above.
  final List<Destination> places;
  final ValueChanged<Destination> onPlace;
  final Destination? focused;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: const BoxDecoration(color: AppColors.brand600, shape: BoxShape.circle),
                child: Text(
                  '${day.day}',
                  style: AppText.sans(14, weight: FontWeight.w700, color: Colors.white),
                ),
              ),
              if (!isLast) Expanded(child: Container(width: 2, color: AppColors.sand200)),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${s.dayWord} ${day.day}',
                    style: AppText.sans(12, weight: FontWeight.w600, color: AppColors.sand500),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          day.from,
                          style: AppText.sans(15.5, weight: FontWeight.w700, color: AppColors.sand900),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6),
                        child: Icon(Icons.arrow_forward_rounded, size: 15, color: AppColors.sand400),
                      ),
                      Flexible(
                        child: Text(
                          day.to,
                          style: AppText.sans(15.5, weight: FontWeight.w700, color: AppColors.sand900),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    day.summary,
                    style: AppText.sans(14, color: AppColors.sand600, height: 1.45),
                  ),
                  if (places.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final p in places)
                          GestureDetector(
                            onTap: () => onPlace(p),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: focused?.key == p.key ? AppColors.brand600 : Colors.white,
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: focused?.key == p.key ? AppColors.brand600 : AppColors.sand200,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.place_outlined,
                                    size: 14,
                                    color: focused?.key == p.key ? Colors.white : AppColors.sand500,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    p.name,
                                    style: AppText.sans(
                                      12.5,
                                      weight: FontWeight.w600,
                                      color: focused?.key == p.key ? Colors.white : AppColors.sand800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StopRow extends StatelessWidget {
  const _StopRow({
    required this.index,
    required this.stop,
    required this.isLast,
    required this.sequential,
    required this.near,
  });

  final int index;
  final CorridorStop stop;
  final bool isLast;
  final bool sequential;
  final List<(Destination, double)> near;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final (name, sub) = bilingual(context, stop.name, stop.nameKh);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 36,
            child: Column(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: index == 1 ? AppColors.sunset500 : AppColors.brand600,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$index',
                    style: AppText.sans(14, weight: FontWeight.w700, color: Colors.white),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: sequential ? AppColors.brand200 : AppColors.sand200,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 26),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text(name, style: AppText.display(20)),
                  if (sub != null) KhmerText(sub, size: 13),
                  if (near.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(s.nearThisStop.toUpperCase(), style: AppText.eyebrow(color: AppColors.sand500)),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 132,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: near.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 10),
                        itemBuilder: (_, i) => _MiniPlace(destination: near[i].$1, km: near[i].$2),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniPlace extends StatelessWidget {
  const _MiniPlace({required this.destination, required this.km});
  final Destination destination;
  final double km;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final (name, _) = bilingual(context, destination.name, destination.nameKh);
    return GestureDetector(
      onTap: () => context.push(Routes.destination(destination.region, destination.slug)),
      child: SizedBox(
        width: 150,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppImage(destination.image, width: 150, height: 86, radius: BorderRadius.circular(14)),
            const SizedBox(height: 6),
            Text(
              name,
              style: AppText.sans(13, weight: FontWeight.w600, color: AppColors.sand900),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text('${formatKm(km)} $distanceUnit ${s.kmAway}', style: AppText.sans(11.5, color: AppColors.sand500)),
          ],
        ),
      ),
    );
  }
}
