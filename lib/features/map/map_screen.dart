import 'dart:async';

import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/location.dart';
import '../../core/utils/polyline.dart';
import '../../data/api/ams_api.dart';
import '../../features/auth/sign_in.dart';
import '../../state/collections_provider.dart';
import '../../widgets/app_image.dart';
import '../../widgets/async_view.dart';
import '../../widgets/destination_card.dart';
import '../../widgets/interest_filter.dart';
import '../../widgets/interest_style.dart';
import '../../widgets/map_view.dart';
import '../destination/reviews_section.dart' show writeReviewFor;

/// The small reference lists behind the map's chips.
class _MapLists {
  const _MapLists({required this.regions, required this.provinces, required this.groups, required this.corridors});

  final List<CatalogRegion> regions;
  final List<CatalogProvince> provinces;
  final List<InterestGroup> groups;
  final List<PlaceCard> corridors;
}

/// The full map. Pins come from the server only: the places around the
/// traveller (`GET /destinations/nearby` → `GET /search/cards`), a chip's
/// places (`GET /search?regionId= | provinceId= | interestIds=&type=&size=100`), a
/// search (`GET /search?q=`), the saved places, or a corridor's itinerary
/// (`GET /corridors/{id}/itinerary`, its road line and stops).
class MapScreen extends StatelessWidget {
  const MapScreen({super.key, this.focusId, this.corridorId});

  /// Destination to select on open, from `?place=` ([Routes.mapFocus]).
  final String? focusId;

  /// Corridor to open on, from `?corridor=` ([Routes.mapCorridor]).
  final String? corridorId;

  /// Goes up each time the Map tab is tapped, so the map can go back to the
  /// traveller's position. The tab keeps its state, so a tap alone would not
  /// rebuild it.
  static final tabTaps = ValueNotifier<int>(0);

  static Future<_MapLists> _load(AmsApi api) async {
    final (regions, provinces, groups, corridors) = await (
      api.tourismRegions(),
      api.provinces(),
      api.interestGroups(),
      api.search(type: CardType.corridor, size: 100),
    ).wait;
    return _MapLists(regions: regions, provinces: provinces, groups: groups, corridors: corridors.content);
  }

  @override
  Widget build(BuildContext context) {
    final api = context.read<AmsApi>();
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        body: AsyncView<_MapLists>(
          load: () => _load(api),
          builder: (context, lists, _) => _FullMap(lists: lists, focusId: focusId, corridorId: corridorId),
        ),
      ),
    );
  }
}

/// Where the pins come from: around the traveller, or one of the four chips.
enum _Layer { nearby, regions, provinces, interests, corridors }

class _FullMap extends StatefulWidget {
  const _FullMap({required this.lists, this.focusId, this.corridorId});

  final _MapLists lists;
  final String? focusId;
  final String? corridorId;

  @override
  State<_FullMap> createState() => _FullMapState();
}

class _FullMapState extends State<_FullMap> {
  final _controller = MapController();
  final _searchField = TextEditingController();
  Timer? _debounce;

  late _Layer _layer = widget.corridorId != null ? _Layer.corridors : _Layer.nearby;

  /// The region or province picked in the chip row.
  String? _pick;
  late String? _corridorId = widget.corridorId;
  int _groupIndex = 0;
  Set<String> _picked = {};
  String _query = '';
  bool _savedOnly = false;

  /// Opened from a place page: the map shows that one place until the
  /// traveller searches, switches chip or asks for what is near.
  late String? _focusId = widget.focusId;

  List<PlaceCard> _cards = const [];
  CorridorItinerary? _itinerary;
  PlaceCard? _selected;
  DeviceLocation? _location;
  LatLng? _me;

  /// Live updates of the traveller's position, started after the first fix.
  /// Paused while another tab is showing.
  StreamSubscription<DeviceLocation>? _watch;
  bool _loading = false;
  Object? _error;

  /// Answers to an older request are dropped.
  int _request = 0;

  double _zoom = 6.4;

  /// Place names and their ratings only fit once you are well zoomed in.
  static const _placeLabelZoom = 10.5;
  bool get _showPlaceLabels => _zoom >= _placeLabelZoom;

  void _onZoomChanged(double zoom) {
    final was = _showPlaceLabels;
    _zoom = zoom;
    if (was != _showPlaceLabels) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    MapScreen.tabTaps.addListener(_onTabTap);
    WidgetsBinding.instance.addPostFrameCallback((_) => _reload());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The shell turns tickers off for the tabs it hides.
    final visible = TickerMode.valuesOf(context).enabled;
    if (visible && (_watch?.isPaused ?? false)) _watch!.resume();
    if (!visible && _watch != null && !_watch!.isPaused) _watch!.pause();
  }

  /// Follows the phone as it moves: the "me" pin goes with it.
  void _followMe() {
    _watch ??= watchLocation().listen((location) {
      if (!mounted || !location.ok) return;
      setState(() => _me = LatLng(location.latitude!, location.longitude!));
    }, onError: (_) {});
  }

  /// The Map tab was tapped: around the traveller, the position is read again
  /// and the camera goes back to it. A chip, search or opened place is kept.
  void _onTabTap() {
    if (!mounted || !_isAroundMe) return;
    _reload();
  }

  bool get _isAroundMe => _layer == _Layer.nearby && _focusId == null && !_savedOnly && _query.isEmpty;

  @override
  void didUpdateWidget(_FullMap old) {
    super.didUpdateWidget(old);
    if (widget.focusId != null && widget.focusId != old.focusId) {
      _clearFilters();
      _focusId = widget.focusId;
      _reload();
    } else if (widget.corridorId != null && widget.corridorId != old.corridorId) {
      _clearFilters();
      _layer = _Layer.corridors;
      _corridorId = widget.corridorId;
      _reload();
    }
  }

  @override
  void dispose() {
    MapScreen.tabTaps.removeListener(_onTabTap);
    _watch?.cancel();
    _debounce?.cancel();
    _searchField.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _clearFilters() {
    _layer = _Layer.nearby;
    _pick = null;
    _corridorId = null;
    _picked = {};
    _savedOnly = false;
    _focusId = null;
    _selected = null;
    _itinerary = null;
    _query = '';
    _searchField.clear();
  }

  /// The filters of the open chip, as `GET /search` parameters. Null when the
  /// chip has nothing picked yet. An interest group of stays, food places or
  /// activities asks for that kind: without a type the server answers
  /// attractions only.
  ({String? regionId, String? provinceId, List<String> interestIds, CardType? type})? get _filters => switch (_layer) {
    _Layer.regions when _pick != null => (regionId: _pick, provinceId: null, interestIds: const <String>[], type: null),
    _Layer.provinces when _pick != null => (
      regionId: null,
      provinceId: _pick,
      interestIds: const <String>[],
      type: null,
    ),
    _Layer.interests => (
      regionId: null,
      provinceId: null,
      interestIds: InterestFilter.idsFor(widget.lists.groups, _groupIndex, _picked),
      type: widget.lists.groups.elementAtOrNull(_groupIndex)?.cardType,
    ),
    _ => null,
  };

  Future<void> _reload() async {
    final ticket = ++_request;
    final api = context.read<AmsApi>();
    final saved = context.read<SavedProvider>();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      var cards = <PlaceCard>[];
      CorridorItinerary? itinerary;
      PlaceCard? selected;
      LatLng? me;
      final filters = _filters;

      if (_focusId != null) {
        final card = await api.card(_focusId!);
        if (card != null) cards = [card];
        selected = card;
      } else if (_savedOnly) {
        // Saved places with a pin: attractions, stays, food places and
        // activities.
        final found = await [
          for (final kind in const [SavedKind.destination, SavedKind.stay, SavedKind.food, SavedKind.activity])
            api.cards(saved.idsOf(kind), type: kind.type.cardType),
        ].wait;
        cards = [for (final list in found) ...list];
      } else if (_query.isNotEmpty || filters != null) {
        final page = await api.search(
          q: _query.isEmpty ? null : _query,
          regionId: filters?.regionId,
          provinceId: filters?.provinceId,
          interestIds: filters?.interestIds ?? const [],
          type: filters?.type,
          size: 100,
        );
        cards = page.content;
      } else if (_layer == _Layer.corridors) {
        if (_corridorId != null) itinerary = await api.itinerary(_corridorId!);
      } else if (_layer == _Layer.nearby) {
        // Jump to the last known position straight away; a fresh fix can take
        // several seconds.
        final fresh = currentLocation();
        final last = await lastKnownLocation();
        if (!mounted || ticket != _request) return;
        if (last != null) {
          setState(() => _me = LatLng(last.latitude!, last.longitude!));
          _centerOnMe();
        }
        final location = await fresh;
        if (!mounted || ticket != _request) return;
        setState(() => _location = location);
        if (location.ok) {
          me = LatLng(location.latitude!, location.longitude!);
          _followMe();
          cards = await api.nearbyCards(
            latitude: location.latitude!,
            longitude: location.longitude!,
            radiusKm: 50,
            limit: 100,
          );
        }
      }
      if (!mounted || ticket != _request) return;
      setState(() {
        _cards = [
          for (final c in cards)
            if (c.hasPin) c,
        ];
        _itinerary = itinerary;
        _selected = selected;
        if (me != null) _me = me;
        _loading = false;
      });
      _frame();
    } catch (e) {
      if (!mounted || ticket != _request) return;
      setState(() {
        _loading = false;
        _error = e;
      });
    }
  }

  /// The corridor's road line: the whole route, or its legs joined. Decoded
  /// once per itinerary, not on every build.
  List<LatLng> get _route {
    final it = _itinerary;
    if (it == null) return const [];
    if (!identical(it, _routeOf)) {
      _routeOf = it;
      final whole = decodePolyline(it.encodedPolyline);
      _routePoints = whole.length > 1 ? whole : [for (final stop in it.stops) ...decodePolyline(stop.routePolyline)];
    }
    return _routePoints;
  }

  CorridorItinerary? _routeOf;
  List<LatLng> _routePoints = const [];

  /// Every corridor card's line, decoded once per list.
  List<List<LatLng>> get _corridorLines {
    final corridors = widget.lists.corridors;
    if (!identical(corridors, _linesOf)) {
      _linesOf = corridors;
      _lines = [for (final c in corridors) decodePolyline(c.encodedPolyline)];
    }
    return _lines;
  }

  List<PlaceCard>? _linesOf;
  List<List<LatLng>> _lines = const [];

  /// Colours for the corridor lines drawn together.
  static const _lineColors = [
    AppColors.route,
    AppColors.violet,
    AppColors.sunset500,
    Color(0xFF0987A0),
    Color(0xFF2F855A),
  ];

  /// Every corridor's line at once, from the cards' `encodedPolyline`, while
  /// the Corridors chip is open and none is picked.
  List<MapRoute> get _allLines {
    if (_layer != _Layer.corridors || _corridorId != null || _query.isNotEmpty) return const [];
    final lines = _corridorLines;
    return [
      for (var i = 0; i < lines.length; i++)
        if (lines[i].length > 1) MapRoute(lines[i], color: _lineColors[i % _lineColors.length]),
    ];
  }

  /// A marker per region or province, at its centre, while their chip is
  /// open and none is picked. Tapping one picks it.
  List<MapPin> get _areaPins {
    if (_pick != null || _query.isNotEmpty) return const [];
    final lists = widget.lists;
    return switch (_layer) {
      _Layer.regions => [
        for (final r in lists.regions)
          if (r.hasPin)
            MapPin(
              id: 'region-${r.id}',
              point: LatLng(r.latitude!, r.longitude!),
              color: AppColors.violet,
              pillText: r.name,
              onTap: () => _pickChip(r.id),
            ),
      ],
      _Layer.provinces => [
        for (final p in lists.provinces)
          if (p.hasPin)
            MapPin(
              id: 'province-${p.id}',
              point: LatLng(p.latitude!, p.longitude!),
              color: AppColors.violet,
              pillText: p.name,
              subtitle: S.read(context).placeCountText(p.placeCount),
              onTap: () => _pickChip(p.id),
            ),
      ],
      _ => const [],
    };
  }

  List<ItineraryStop> get _stops => [
    for (final stop in _itinerary?.stops ?? const <ItineraryStop>[])
      if (stop.place.latitude != null && stop.place.longitude != null) stop,
  ];

  /// Zoom for the traveller's own position: a few streets around them.
  static const _meZoom = 14.0;

  /// Moves the camera, unless the map has not laid out yet.
  void _camera(void Function(MapController c) move) {
    try {
      move(_controller);
    } catch (_) {}
  }

  void _centerOnMe() {
    if (_me == null) return;
    _camera((c) => c.move(_me!, _meZoom));
  }

  /// Frames what was just loaded, clear of the chips above and the card below.
  /// Around the traveller, the camera centres on them; the nearby pins are a
  /// zoom-out away.
  void _frame() {
    if (_me != null && _isAroundMe) return _centerOnMe();
    final points = <LatLng>[
      for (final c in _cards) LatLng(c.latitude!, c.longitude!),
      ..._route,
      for (final line in _allLines) ...line.points,
      for (final pin in _areaPins) pin.point,
      for (final s in _stops) LatLng(s.place.latitude!, s.place.longitude!),
    ];
    _camera((c) {
      if (points.length > 1) {
        c.fitCamera(
          CameraFit.bounds(
            bounds: LatLngBounds.fromPoints(points),
            padding: const EdgeInsets.fromLTRB(44, 200, 44, 240),
            maxZoom: 14,
          ),
        );
      } else if (points.length == 1) {
        c.move(points.first, 12);
      }
    });
  }

  void _resetView() {
    setState(() => _selected = null);
    _camera((c) => c.move(cambodiaCenter, 6.4));
  }

  /// Steps the camera in or out — pinching works too, but a button is easier
  /// one-handed (and on the simulator).
  void _zoomBy(double delta) {
    _camera((c) => c.move(c.camera.center, (c.camera.zoom + delta).clamp(5.0, 18.0)));
  }

  /// Back to the places around the traveller, asking for location if needed.
  void _nearMe() {
    setState(_clearFilters);
    _reload();
  }

  void _showLayer(_Layer layer) {
    setState(() {
      final next = _layer == layer ? _Layer.nearby : layer;
      _clearFilters();
      _layer = next;
    });
    _reload();
  }

  void _pickChip(String id) {
    setState(() {
      _focusId = null;
      _selected = null;
      if (_layer == _Layer.corridors) {
        _corridorId = _corridorId == id ? null : id;
        if (_corridorId == null) _itinerary = null;
      } else {
        _pick = _pick == id ? null : id;
      }
    });
    _reload();
  }

  void _onSearch(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      final q = text.trim();
      if (q == _query) return;
      setState(() {
        _query = q;
        _focusId = null;
        _savedOnly = false;
        _selected = null;
      });
      _reload();
    });
  }

  void _toggleSaved() {
    whenSignedIn(context, S.read(context).logInToSeeSaved, () {
      setState(() {
        final on = !_savedOnly;
        _clearFilters();
        _savedOnly = on;
      });
      _reload();
    });
  }

  /// A stop on the corridor line: its card, for the info sheet.
  Future<void> _openStop(ItineraryStop stop) async {
    final card = await context.read<AmsApi>().card(stop.place.id, type: CardType.destination).orNull;
    if (mounted && card != null) setState(() => _selected = card);
  }

  Future<void> _allowLocation() async {
    final problem = _location?.problem;
    if (problem.needsSettings) {
      await openLocationSettings(problem);
    } else {
      await _reload();
    }
  }

  static (IconData?, Color) _kindStyle(CardType type) => switch (type) {
    CardType.stay => groupStyle(InterestGroup.stays),
    CardType.food => groupStyle(InterestGroup.food),
    CardType.activity => groupStyle(InterestGroup.activities),
    _ => (null, AppColors.brand600),
  };

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final lists = widget.lists;
    final itinerary = _itinerary;
    final corridorCard = itinerary == null
        ? null
        : lists.corridors.where((c) => c.id == itinerary.corridor.id).firstOrNull;
    final stops = _stops;
    final showMe = _me != null && _isAroundMe;
    final pinCount = _cards.length + stops.length;

    // The one card at the bottom, if any.
    Widget? bottom;
    if (_selected != null) {
      bottom = _SelectedCard(card: _selected!, onClose: () => setState(() => _selected = null));
    } else if (itinerary != null) {
      bottom = _CorridorCard(
        itinerary: itinerary,
        card: corridorCard,
        onClose: () => setState(() {
          _corridorId = null;
          _itinerary = null;
        }),
      );
    } else if (_error != null && !_loading) {
      bottom = _Notice(icon: Icons.cloud_off_rounded, text: s.somethingWentWrong, action: s.retry, onAction: _reload);
    } else if (_loading) {
      bottom = null;
    } else if (_isAroundMe && _location != null && !_location!.ok) {
      bottom = _Notice(
        icon: Icons.location_off_rounded,
        text: s.mapLocationOff,
        action: s.allowLocationAccess,
        onAction: _allowLocation,
      );
    } else if (_layer == _Layer.corridors && _corridorId == null && _query.isEmpty) {
      bottom = _Notice(icon: Icons.route_rounded, text: s.mapPickCorridor);
    } else if (_savedOnly && _cards.isEmpty) {
      bottom = _Notice(icon: Icons.favorite_border_rounded, text: s.emptySaved);
    } else if ((_query.isNotEmpty || _filters != null) && _cards.isEmpty) {
      bottom = _Notice(icon: Icons.search_off_rounded, text: s.noResults);
    }

    final route = _route;
    final legend = switch (_layer) {
      _Layer.regions => [for (final r in lists.regions) (r.id, r.name)],
      _Layer.provinces => [for (final p in lists.provinces) (p.id, '${p.name} · ${p.placeCount}')],
      _Layer.corridors => [for (final c in lists.corridors) (c.id, c.name)],
      _ => const <(String, String)>[],
    };
    final legendPick = _layer == _Layer.corridors ? _corridorId : _pick;

    return Stack(
      children: [
        Positioned.fill(
          child: AppMap(
            controller: _controller,
            fitToPins: false,
            onZoomChanged: _onZoomChanged,
            onTapMap: () => setState(() => _selected = null),
            routes: [if (route.length > 1) MapRoute(route), ..._allLines],
            pins: [
              ..._areaPins,
              if (showMe) MapPin(id: 'me', point: _me!, color: AppColors.route, icon: Icons.person_rounded),
              for (final c in _cards)
                () {
                  final (icon, color) = _kindStyle(c.type);
                  final labelled = _showPlaceLabels && c.averageRating != null;
                  return MapPin(
                    id: c.id,
                    point: LatLng(c.latitude!, c.longitude!),
                    color: color,
                    icon: icon,
                    // Zoomed in, a place shows its score and name instead of a
                    // bare pin.
                    pillText: labelled ? '★ ${c.averageRating!.toStringAsFixed(1)}' : null,
                    subtitle: labelled ? c.name : null,
                    highlighted: c.id == _selected?.id,
                    onTap: () => setState(() => _selected = c),
                  );
                }(),
              for (var i = 0; i < stops.length; i++)
                MapPin(
                  id: 'stop-${stops[i].sequence}',
                  point: LatLng(stops[i].place.latitude!, stops[i].place.longitude!),
                  label: '${i + 1}',
                  color: AppColors.route,
                  highlighted: stops[i].place.id == _selected?.id,
                  onTap: () => _openStop(stops[i]),
                ),
            ],
          ),
        ),

        // Search, saved toggle and the chips
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
                            controller: _searchField,
                            onChanged: _onSearch,
                            textInputAction: TextInputAction.search,
                            decoration: InputDecoration(
                              hintText: s.searchMap,
                              prefixIcon: const Icon(Icons.search_rounded, color: AppColors.violet),
                              suffixIcon: Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: Center(
                                  widthFactor: 1,
                                  child: _loading
                                      ? const SizedBox.square(
                                          dimension: 16,
                                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.brand600),
                                        )
                                      : Text(
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
                      Material(
                        color: _savedOnly ? AppColors.sunset500 : Colors.white,
                        elevation: 3,
                        shadowColor: const Color(0x331C1935),
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: _toggleSaved,
                          child: Tooltip(
                            message: s.savedTitle,
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
                      for (final (layer, label) in [
                        (_Layer.regions, s.tabRegions),
                        (_Layer.provinces, s.tabProvinces),
                        (_Layer.interests, s.tabInterests),
                        (_Layer.corridors, s.tabCorridors),
                      ])
                        _MapChip(label: label, selected: _layer == layer, onTap: () => _showLayer(layer)),
                    ],
                  ),
                ),
                if (_layer == _Layer.interests)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: InterestFilter(
                      groups: lists.groups,
                      index: _groupIndex,
                      showAll: false,
                      onIndex: (i) {
                        setState(() {
                          _groupIndex = i ?? 0;
                          _picked = {};
                          _selected = null;
                        });
                        _reload();
                      },
                      picked: _picked,
                      onPicked: (id) {
                        setState(() {
                          _picked = {..._picked};
                          if (!_picked.remove(id)) _picked.add(id);
                          _selected = null;
                        });
                        _reload();
                      },
                    ),
                  )
                else if (legend.isNotEmpty)
                  SizedBox(
                    height: 42,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                      children: [
                        for (final (id, name) in legend)
                          _LegendChip(
                            name: name,
                            color: _layer == _Layer.corridors ? AppColors.route : AppColors.brand600,
                            selected: id == legendPick,
                            onTap: () => _pickChip(id),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),

        Positioned(
          right: 16,
          bottom: (bottom == null ? 16 : 176) + MediaQuery.paddingOf(context).bottom,
          child: Column(
            children: [
              _MapButton(icon: Icons.add_rounded, tooltip: s.zoomIn, onTap: () => _zoomBy(1)),
              const SizedBox(height: 8),
              _MapButton(icon: Icons.remove_rounded, tooltip: s.zoomOut, onTap: () => _zoomBy(-1)),
              const SizedBox(height: 8),
              _MapButton(icon: Icons.my_location_rounded, tooltip: s.nearMe, onTap: _nearMe),
              const SizedBox(height: 8),
              _MapButton(icon: Icons.center_focus_strong_rounded, tooltip: s.resetView, onTap: _resetView),
            ],
          ),
        ),

        if (bottom != null)
          Positioned(left: 16, right: 16, bottom: 16 + MediaQuery.paddingOf(context).bottom, child: bottom),
      ],
    );
  }
}

/// Round white control on top of the map (zoom in, zoom out, near me, recentre).
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

/// One region, province or corridor in the chip row under the layer chips.
class _LegendChip extends StatelessWidget {
  const _LegendChip({required this.name, required this.color, required this.selected, required this.onTap});

  final String name;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: selected ? color : Colors.white,
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
                  decoration: BoxDecoration(color: selected ? Colors.white : color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 170),
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.sans(
                      12,
                      weight: FontWeight.w600,
                      color: selected ? Colors.white : AppColors.sand800,
                    ),
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

/// Chip that switches the map to one of the four lists.
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

/// A one-line message at the bottom of the map, with an optional button.
class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.text, this.action, this.onAction});

  final IconData icon;
  final String text;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 8,
      shadowColor: const Color(0x401C1935),
      borderRadius: BorderRadius.circular(AppTheme.radius),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
        child: Row(
          children: [
            Icon(icon, color: AppColors.brand600),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(text, style: AppText.sans(13.5, color: AppColors.sand800, height: 1.35)),
                  if (action != null)
                    TextButton(
                      style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 36)),
                      onPressed: onAction,
                      child: Text(action!),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The picked corridor: cover, name, days and stops, into its page.
class _CorridorCard extends StatelessWidget {
  const _CorridorCard({required this.itinerary, required this.card, required this.onClose});

  final CorridorItinerary itinerary;
  final PlaceCard? card;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final c = itinerary.corridor;
    final days = c.durationDays ?? card?.durationDays;
    final stops = c.stopCount ?? itinerary.stops.length;
    final cover = c.coverUrl.isNotEmpty ? c.coverUrl : (card?.coverUrl ?? '');
    return Material(
      color: Colors.white,
      elevation: 8,
      shadowColor: const Color(0x401C1935),
      borderRadius: BorderRadius.circular(AppTheme.radius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(Routes.corridor(c.id)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              AppImage(cover, width: 76, height: 76, radius: BorderRadius.circular(12)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      c.name,
                      style: AppText.sans(16.5, weight: FontWeight.w700, color: AppColors.sand900),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [if (days != null) s.daysCount(days), '$stops ${s.stops.toLowerCase()}'].join('  ·  '),
                      style: AppText.sans(13, weight: FontWeight.w600, color: AppColors.route),
                    ),
                    if ((c.shortDescription ?? '').isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        c.shortDescription!,
                        style: AppText.sans(13, color: AppColors.sand500, height: 1.35),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(onPressed: onClose, icon: const Icon(Icons.close_rounded, size: 20)),
            ],
          ),
        ),
      ),
    );
  }
}

/// The tapped pin: cover, name, rating or category, province, into its page.
class _SelectedCard extends StatelessWidget {
  const _SelectedCard({required this.card, required this.onClose});
  final PlaceCard card;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final d = card;

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
            onTap: () => context.push(Routes.card(d)),
            child: SizedBox(
              height: 104,
              child: Row(
                children: [
                  AppImage(d.coverUrl, width: 104, height: 104),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(d.name, style: AppText.display(17), maxLines: 1, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              if (d.averageRating != null) ...[
                                const Icon(Icons.star_rounded, size: 16, color: AppColors.star),
                                const SizedBox(width: 3),
                                Text(
                                  d.averageRating!.toStringAsFixed(1),
                                  style: AppText.sans(13, weight: FontWeight.w700, color: AppColors.sand900),
                                ),
                                if (d.reviewCount > 0)
                                  Text(
                                    ' (${s.reviewCountText(d.reviewCount)})',
                                    style: AppText.sans(12.5, color: AppColors.sand500),
                                  ),
                              ] else if (d.categoryNames.isNotEmpty)
                                Expanded(
                                  child: Text(
                                    d.categoryNames.join(' · '),
                                    style: AppText.sans(12.5, color: AppColors.sand500),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                          ),
                          if ((d.provinceName ?? '').isNotEmpty) ...[
                            const SizedBox(height: 5),
                            Row(
                              children: [
                                const Icon(Icons.place_outlined, size: 14, color: AppColors.brand600),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    d.provinceName!,
                                    style: AppText.sans(12.5, color: AppColors.sand600),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  Column(
                    children: [
                      IconButton(onPressed: onClose, icon: const Icon(Icons.close_rounded, size: 20)),
                      SaveButton(kind: SavedKind.of(d.type), itemKey: d.id, onImage: false),
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
                onPressed: () => writeReviewFor(context, d.type, d.id),
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
                // The route itself is the device's maps app, from where the
                // traveller is to the pin.
                onPressed: d.latitude == null || d.longitude == null
                    ? null
                    : () => openDirections(d.latitude!, d.longitude!),
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
