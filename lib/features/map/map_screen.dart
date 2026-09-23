import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

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
import '../../widgets/destination_card.dart';
import '../../widgets/interest_card.dart';
import '../../widgets/map_view.dart';

class MapScreen extends StatelessWidget {
  const MapScreen({super.key, this.focusKey, this.corridorSlug});

  /// Destination key (`region/slug`) to select on open, from `?place=`.
  final String? focusKey;

  /// Corridor to open on, from `?corridor=` — the map starts on that route.
  final String? corridorSlug;

  @override
  Widget build(BuildContext context) {
    final repo = context.read<TravelRepository>();
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        body: AsyncView<(List<Destination>, List<Province>, List<Interest>, List<Corridor>)>(
          load: () => (
            repo.getDestinations(),
            repo.getProvinces(),
            repo.getInterests(),
            repo.getCorridors(),
          ).wait,
          builder: (context, data, _) => _FullMap(
            destinations: data.$1,
            provinces: data.$2,
            interests: data.$3,
            corridors: data.$4,
            focusKey: focusKey,
            corridorSlug: corridorSlug,
          ),
        ),
      ),
    );
  }
}

/// What the map draws: every place, or one marker per region / province /
/// interest, or the corridor routes.
enum _Layer { places, provinces, interests, corridors }

/// A named marker standing for a whole region, province, interest or corridor.
class _Group {
  const _Group({
    required this.slug,
    required this.name,
    required this.subtitle,
    required this.image,
    required this.count,
    required this.point,
    required this.color,
    required this.route,
    required this.onOpen,
  });

  final String slug;
  final String name;

  /// One line under the name — the region tagline, province headline, etc.
  final String subtitle;
  final String image;
  final int count;
  final LatLng point;
  final Color color;

  /// Stops of a corridor, empty for the other layers.
  final List<LatLng> route;
  final String onOpen;

  _Group at(LatLng moved) => _Group(
    slug: slug,
    name: name,
    subtitle: subtitle,
    image: image,
    count: count,
    point: moved,
    color: color,
    route: route,
    onOpen: onOpen,
  );
}

class _FullMap extends StatefulWidget {
  const _FullMap({
    required this.destinations,
    required this.provinces,
    required this.interests,
    required this.corridors,
    this.focusKey,
    this.corridorSlug,
  });

  final List<Destination> destinations;
  final List<Province> provinces;
  final List<Interest> interests;
  final List<Corridor> corridors;
  final String? focusKey;
  final String? corridorSlug;

  @override
  State<_FullMap> createState() => _FullMapState();
}

class _FullMapState extends State<_FullMap> {
  final _controller = MapController();
  late _Layer _layer = widget.corridorSlug == null ? _Layer.places : _Layer.corridors;
  bool _savedOnly = false;
  String _query = '';
  late String? _selected = widget.focusKey;

  /// Opened from a place page: the map shows that one place until the
  /// traveller searches, switches layer, recentres or taps the map.
  late bool _onlyFocused = widget.focusKey != null;
  late String? _selectedGroup = widget.corridorSlug;
  double _zoom = 6.4;

  /// Below this zoom the group markers are counted dots; above it they show
  /// their names, which are too wide to fit side by side when zoomed out.
  static const _labelZoom = 8.5;

  bool get _showNames => _zoom >= _labelZoom;

  /// What the markers of the open layer stand for.
  IconData get _layerIcon => switch (_layer) {
    _Layer.provinces => Icons.location_city_rounded,
    _Layer.interests => Icons.interests_rounded,
    _Layer.corridors => Icons.route_rounded,
    _Layer.places => Icons.place_rounded,
  };

  /// Place names and their ratings only fit once you are well zoomed in.
  static const _placeLabelZoom = 10.5;
  bool get _showPlaceLabels => _zoom >= _placeLabelZoom;

  void _onZoomChanged(double zoom) {
    final wasNames = _showNames;
    final wasPlaces = _showPlaceLabels;
    _zoom = zoom;
    if (wasNames != _showNames || wasPlaces != _showPlaceLabels) setState(() {});
  }

  /// Nudges markers that would sit on top of each other onto a coarse grid, so
  /// every region or province stays readable at country zoom.
  List<_Group> _spread(List<_Group> groups) {
    const stepLat = 0.42;
    const stepLng = 0.52;
    final taken = <(int, int)>{};
    return [
      for (final g in groups)
        () {
          var row = (g.point.latitude / stepLat).round();
          var col = (g.point.longitude / stepLng).round();
          // Walk outwards in a square spiral until a free cell turns up.
          for (var ring = 0; ring < 8 && taken.contains((row, col)); ring++) {
            for (var dRow = -ring; dRow <= ring; dRow++) {
              for (var dCol = -ring; dCol <= ring; dCol++) {
                final cell = (
                  (g.point.latitude / stepLat).round() + dRow,
                  (g.point.longitude / stepLng).round() + dCol,
                );
                if (!taken.contains(cell)) {
                  row = cell.$1;
                  col = cell.$2;
                  break;
                }
              }
              if (!taken.contains((row, col))) break;
            }
          }
          taken.add((row, col));
          return g.at(LatLng(row * stepLat, col * stepLng));
        }(),
    ];
  }

  Destination? get _selectedDestination => widget.destinations.where((d) => d.key == _selected).firstOrNull;

  @override
  void didUpdateWidget(_FullMap old) {
    super.didUpdateWidget(old);
    if (widget.focusKey != null && widget.focusKey != old.focusKey) {
      setState(() {
        _selected = widget.focusKey;
        _layer = _Layer.places;
        _savedOnly = false;
        _onlyFocused = true;
      });
      final d = _selectedDestination;
      if (d != null) _moveTo(d);
    }
  }

  void _moveTo(Destination d, {double zoom = 12}) {
    try {
      _controller.move(LatLng(d.lat, d.lng), zoom);
    } catch (_) {
      // The map hasn't laid out yet; its initial camera already targets `d`.
    }
  }

  void _resetView() {
    setState(() {
      _selected = null;
      _selectedGroup = null;
      _onlyFocused = false;
    });
    try {
      _controller.move(cambodiaCenter, 6.4);
    } catch (_) {}
  }

  /// Steps the camera in or out — pinching works too, but a button is easier
  /// one-handed (and on the simulator).
  void _zoomBy(double delta) {
    try {
      final camera = _controller.camera;
      _controller.move(camera.center, (camera.zoom + delta).clamp(5.0, 18.0));
    } catch (_) {}
  }

  /// Centres the map on one marker and shows its card.
  void _focusGroup(_Group g) {
    setState(() => _selectedGroup = g.slug);
    try {
      if (g.route.length > 1) {
        // Frame the whole route, clear of the chips above and the card below.
        _controller.fitCamera(
          CameraFit.bounds(
            bounds: LatLngBounds.fromPoints(g.route),
            padding: const EdgeInsets.fromLTRB(44, 190, 44, 230),
            maxZoom: 12,
          ),
        );
      } else {
        _controller.move(g.point, 9);
      }
    } catch (_) {}
  }

  void _showLayer(_Layer layer) {
    setState(() {
      _onlyFocused = false;
      // Tapping the active chip goes back to showing every place.
      _layer = _layer == layer ? _Layer.places : layer;
      _selected = null;
      _selectedGroup = null;
      if (_layer != _Layer.places) _savedOnly = false;
    });
    try {
      _controller.move(cambodiaCenter, 6.4);
    } catch (_) {}
  }

  /// Middle of a set of places, used to position a group marker.
  LatLng _centre(Iterable<Destination> places, {LatLng? fallback}) {
    if (places.isEmpty) return fallback ?? cambodiaCenter;
    final lat = places.map((d) => d.lat).reduce((a, b) => a + b) / places.length;
    final lng = places.map((d) => d.lng).reduce((a, b) => a + b) / places.length;
    return LatLng(lat, lng);
  }

  List<_Group> get _groups {
    switch (_layer) {
      case _Layer.places:
        return const [];
      case _Layer.provinces:
        return [
          for (final p in widget.provinces)
            () {
              final places = widget.destinations.where((d) => slugify(d.province) == p.slug);
              return _Group(
                slug: p.slug,
                name: bilingual(context, p.name, p.nameKh).$1,
                subtitle: p.tagline,
                image: p.image,
                count: places.length,
                point: _centre(places, fallback: LatLng(p.lat, p.lng)),
                color: AppColors.brand600,
                route: const [],
                onOpen: Routes.province(p.slug),
              );
            }(),
        ];
      case _Layer.interests:
        return [
          for (final i in widget.interests)
            () {
              final places = widget.destinations.where((d) => i.categories.contains(d.category));
              final (_, color) = interestStyle(i);
              return _Group(
                slug: i.slug,
                name: bilingual(context, i.name, i.nameKh).$1,
                subtitle: i.description,
                image: i.image,
                count: i.isCorridors ? widget.corridors.length : places.length,
                point: _centre(places),
                color: color,
                route: const [],
                onOpen: Routes.interest(i.slug),
              );
            }(),
        ];
      case _Layer.corridors:
        return [
          for (var i = 0; i < widget.corridors.length; i++)
            () {
              final c = widget.corridors[i];
              final points = [for (final st in c.stops) LatLng(st.lat, st.lng)];
              return _Group(
                slug: c.slug,
                name: c.name,
                subtitle: '${c.duration}  ·  ${c.description}',
                image: c.image,
                count: c.stops.length,
                point: points.isEmpty ? cambodiaCenter : points[points.length ~/ 2],
                color: _corridorColors[i % _corridorColors.length],
                route: c.sequential ? points : const [],
                onOpen: Routes.corridor(c.slug),
              );
            }(),
        ];
    }
  }

  static const _corridorColors = [
    AppColors.brand600,
    Color(0xFF0987A0),
    Color(0xFFC05621),
    Color(0xFF2F855A),
    AppColors.plum600,
  ];

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final saved = context.watch<SavedProvider>();
    final savedKeys = saved.keysOf(SavedKind.destination).toSet();
    final q = _query.toLowerCase();

    // Searching always looks through the places, whichever layer is on.
    final searching = q.isNotEmpty;
    // Choosing an interest or a province swaps its single marker for the
    // places it covers.
    final openInterest = _layer == _Layer.interests && _selectedGroup != null
        ? widget.interests.where((i) => i.slug == _selectedGroup).firstOrNull
        : null;
    final interestCategories = openInterest?.categories.toSet();
    final openProvince = _layer == _Layer.provinces ? _selectedGroup : null;
    final opened = openInterest != null || openProvince != null;
    final showPlaces = _layer == _Layer.places || searching || opened;

    final visible = widget.destinations.where((d) {
      if (_onlyFocused) return d.key == widget.focusKey;
      if (interestCategories != null && !interestCategories.contains(d.category)) return false;
      if (openProvince != null && slugify(d.province) != openProvince) return false;
      if (_savedOnly && !savedKeys.contains(d.key)) return false;
      if (searching &&
          !(d.name.toLowerCase().contains(q) ||
              d.province.toLowerCase().contains(q) ||
              d.category.toLowerCase().contains(q) ||
              (d.nameKh?.contains(q) ?? false))) {
        return false;
      }
      return true;
    }).toList();

    final allGroups = (showPlaces && !opened) ? const <_Group>[] : (_showNames ? _groups : _spread(_groups));
    final selectedGroup = allGroups.where((g) => g.slug == _selectedGroup).firstOrNull;
    // Picking one corridor shows that route by itself; the chips below still
    // list them all, so another one is a tap away.
    final groups = switch (_layer) {
      _Layer.corridors when selectedGroup != null => [selectedGroup],
      // The interest's or province's own marker steps aside for its places.
      _Layer.interests when openInterest != null => const <_Group>[],
      _Layer.provinces when openProvince != null => const <_Group>[],
      _ => allGroups,
    };
    final selected = _selectedDestination;
    final focus = widget.focusKey == null
        ? null
        : widget.destinations.where((d) => d.key == widget.focusKey).firstOrNull;
    final pinCount = showPlaces ? visible.length : groups.length;

    return Stack(
      children: [
        Positioned.fill(
          child: AppMap(
            controller: _controller,
            fitToPins: false,
            initialCenter: focus != null ? LatLng(focus.lat, focus.lng) : cambodiaCenter,
            initialZoom: focus != null ? 12 : 6.4,
            onZoomChanged: _onZoomChanged,
            onTapMap: () => setState(() {
              _selected = null;
              _selectedGroup = null;
              _onlyFocused = false;
            }),
            routes: [for (final g in groups) MapRoute(g.route, color: g.color)],
            pins: [
              if (showPlaces)
                for (final d in visible)
                  MapPin(
                    id: d.key,
                    point: LatLng(d.lat, d.lng),
                    color: AppColors.forRegion(d.region),
                    // Zoomed in, a place shows its score and name instead of a
                    // bare pin.
                    pillText: _showPlaceLabels && d.rating != null ? '★ ${d.rating!.toStringAsFixed(1)}' : null,
                    subtitle: _showPlaceLabels && d.rating != null ? bilingual(context, d.name, d.nameKh).$1 : null,
                    highlighted: d.key == _selected,
                    onTap: () => setState(() => _selected = d.key),
                  )
              else ...[
                // Stops along each corridor, drawn under the name pills.
                for (final g in groups)
                  for (var i = 0; i < g.route.length; i++)
                    MapPin(
                      id: '${g.slug}-stop-$i',
                      point: g.route[i],
                      label: '${i + 1}',
                      color: g.color,
                      onTap: () => setState(() => _selectedGroup = g.slug),
                    ),
                for (final g in groups)
                  MapPin(
                    id: g.slug,
                    point: g.point,
                    color: g.color,
                    // Zoomed out the pins say what they are; the name pill
                    // carries the count once there is room for it.
                    icon: _showNames ? null : _layerIcon,
                    pillText: _showNames ? '${g.name}  ·  ${g.count}' : null,
                    highlighted: g.slug == _selectedGroup,
                    onTap: () => setState(() => _selectedGroup = g.slug),
                  ),
              ],
            ],
          ),
        ),

        // Search + layer chips
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Material(
                          elevation: 3,
                          shadowColor: const Color(0x331C1935),
                          borderRadius: BorderRadius.circular(16),
                          child: TextField(
                            onChanged: (v) => setState(() {
                              _query = v.trim();
                              if (_query.isNotEmpty) _onlyFocused = false;
                            }),
                            decoration: InputDecoration(
                              hintText: s.searchMap,
                              prefixIcon: const Icon(Icons.search_rounded),
                              suffixIcon: Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: Center(
                                  widthFactor: 1,
                                  child: Text(
                                    '$pinCount',
                                    style: AppText.sans(13, weight: FontWeight.w700, color: AppColors.brand600),
                                  ),
                                ),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Saved-only toggle; showing saved places means the places layer.
                      Material(
                        color: _savedOnly ? AppColors.sunset500 : Colors.white,
                        elevation: 3,
                        shadowColor: const Color(0x331C1935),
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => setState(() {
                            _savedOnly = !_savedOnly;
                            if (_savedOnly) _layer = _Layer.places;
                          }),
                          child: SizedBox(
                            width: 54,
                            height: 54,
                            child: Icon(
                              _savedOnly ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                              color: _savedOnly ? Colors.white : AppColors.sand600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 52,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
                    children: [
                      _MapChip(
                        label: s.tabProvinces,
                        selected: _layer == _Layer.provinces,
                        onTap: () => _showLayer(_Layer.provinces),
                      ),
                      _MapChip(
                        label: s.tabInterests,
                        selected: _layer == _Layer.interests,
                        onTap: () => _showLayer(_Layer.interests),
                      ),
                      _MapChip(
                        label: s.tabCorridors,
                        selected: _layer == _Layer.corridors,
                        onTap: () => _showLayer(_Layer.corridors),
                      ),
                    ],
                  ),
                ),
                if (allGroups.isNotEmpty)
                  SizedBox(
                    height: 42,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                      children: [
                        for (final g in allGroups)
                          _LegendChip(group: g, selected: g.slug == _selectedGroup, onTap: () => _focusGroup(g)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),

        Positioned(
          right: 16,
          bottom: (selected == null && selectedGroup == null ? 16 : 176) + MediaQuery.paddingOf(context).bottom,
          child: Column(
            children: [
              _MapButton(icon: Icons.add_rounded, tooltip: s.zoomIn, onTap: () => _zoomBy(1)),
              const SizedBox(height: 8),
              _MapButton(icon: Icons.remove_rounded, tooltip: s.zoomOut, onTap: () => _zoomBy(-1)),
              const SizedBox(height: 8),
              _MapButton(icon: Icons.center_focus_strong_rounded, tooltip: s.resetView, onTap: _resetView),
            ],
          ),
        ),

        if (selected != null)
          Positioned(
            left: 16,
            right: 16,
            bottom: 16 + MediaQuery.paddingOf(context).bottom,
            child: _SelectedCard(destination: selected, onClose: () => setState(() => _selected = null)),
          )
        else if (selectedGroup != null)
          Positioned(
            left: 16,
            right: 16,
            bottom: 16 + MediaQuery.paddingOf(context).bottom,
            child: _GroupCard(group: selectedGroup, unit: _layer == _Layer.corridors ? s.stops : s.places),
          ),
      ],
    );
  }
}

/// Round white control on top of the map (zoom in, zoom out, recentre).
class _MapButton extends StatelessWidget {
  const _MapButton({required this.icon, required this.tooltip, required this.onTap});

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 3,
      shadowColor: const Color(0x331C1935),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Tooltip(
          message: tooltip,
          child: SizedBox.square(dimension: 42, child: Icon(icon, size: 22, color: AppColors.brand700)),
        ),
      ),
    );
  }
}

/// Small legend entry naming one marker on the map.
class _LegendChip extends StatelessWidget {
  const _LegendChip({required this.group, required this.selected, required this.onTap});

  final _Group group;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: selected ? group.color : Colors.white,
        elevation: 2,
        shadowColor: const Color(0x331C1935),
        borderRadius: BorderRadius.circular(99),
        child: InkWell(
          borderRadius: BorderRadius.circular(99),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(color: selected ? Colors.white : group.color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 170),
                  child: Text(
                    group.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.sans(
                      12,
                      weight: FontWeight.w600,
                      color: selected ? Colors.white : AppColors.sand800,
                    ),
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  '${group.count}',
                  style: AppText.sans(
                    12,
                    weight: FontWeight.w700,
                    color: selected ? Colors.white70 : AppColors.sand400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Chip that switches the map between places and one of the four lists.
class _MapChip extends StatelessWidget {
  const _MapChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: selected ? AppColors.brand600 : Colors.white,
        elevation: 2,
        shadowColor: const Color(0x331C1935),
        borderRadius: BorderRadius.circular(99),
        child: InkWell(
          borderRadius: BorderRadius.circular(99),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: AppText.sans(
                    12.5,
                    weight: FontWeight.w600,
                    color: selected ? Colors.white : AppColors.sand800,
                  ),
                ),
                if (selected) ...[
                  const SizedBox(width: 5),
                  const Icon(Icons.close_rounded, size: 14, color: Colors.white),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Row card for the tapped region / province / interest / corridor: photo,
/// name, how many places it holds, and a chevron into its page.
class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.group, required this.unit});

  final _Group group;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 8,
      shadowColor: const Color(0x401C1935),
      borderRadius: BorderRadius.circular(AppTheme.radius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(group.onOpen),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              AppImage(group.image, width: 76, height: 76, radius: BorderRadius.circular(12)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      group.name,
                      style: AppText.sans(16.5, weight: FontWeight.w700, color: AppColors.sand900),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(color: group.color, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${group.count} ${unit.toLowerCase()}',
                          style: AppText.sans(13, weight: FontWeight.w600, color: group.color),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      group.subtitle,
                      style: AppText.sans(13, color: AppColors.sand500, height: 1.35),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.sand400),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectedCard extends StatelessWidget {
  const _SelectedCard({required this.destination, required this.onClose});
  final Destination destination;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final d = destination;
    final (title, _) = bilingual(context, d.name, d.nameKh);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: Colors.white,
          elevation: 8,
          shadowColor: const Color(0x401C1935),
          borderRadius: BorderRadius.circular(AppTheme.radius),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => context.push(Routes.destination(d.region, d.slug)),
            child: SizedBox(
              height: 104,
              child: Row(
                children: [
                  AppImage(d.image, width: 104, height: 104),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(title, style: AppText.display(17), maxLines: 1, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              if (d.rating != null) ...[
                                const Icon(Icons.star_rounded, size: 16, color: AppColors.star),
                                const SizedBox(width: 3),
                                Text(
                                  d.rating!.toStringAsFixed(1),
                                  style: AppText.sans(13, weight: FontWeight.w700, color: AppColors.sand900),
                                ),
                                if (d.reviewCount != null)
                                  Text(
                                    ' (${thousands(d.reviewCount!)} ${s.reviewsWord})',
                                    style: AppText.sans(12.5, color: AppColors.sand500),
                                  ),
                              ] else
                                Text(d.category, style: AppText.sans(12.5, color: AppColors.sand500)),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Row(
                            children: [
                              const Icon(Icons.place_outlined, size: 14, color: AppColors.brand600),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  d.province,
                                  style: AppText.sans(12.5, color: AppColors.sand600),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  Column(
                    children: [
                      IconButton(onPressed: onClose, icon: const Icon(Icons.close_rounded, size: 20)),
                      SaveButton(kind: SavedKind.destination, itemKey: d.key, onImage: false),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.sand900,
                  minimumSize: const Size(0, 46),
                  elevation: 6,
                  shadowColor: const Color(0x331C1935),
                ),
                onPressed: () => context.push(Routes.review(d.region, d.slug)),
                icon: const Icon(Icons.rate_review_outlined, size: 18),
                label: FittedBox(child: Text(s.writeReview)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.brand600,
                  minimumSize: const Size(0, 46),
                  elevation: 6,
                  shadowColor: const Color(0x331C1935),
                ),
                // Hands the walk or drive over to the maps app.
                onPressed: () => launchUrl(
                  Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${d.lat},${d.lng}'),
                  mode: LaunchMode.externalApplication,
                ),
                icon: const Icon(Icons.navigation_rounded, size: 18),
                label: FittedBox(child: Text(s.showRoute)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
