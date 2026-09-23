import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';

import '../core/network/routing_service.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';

export 'package:flutter_map/flutter_map.dart' show CameraFit, LatLngBounds, MapController;
export 'package:latlong2/latlong.dart' show LatLng;

const tileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

/// Geographic centre of Cambodia, used as the default camera.
const cambodiaCenter = LatLng(12.55, 104.95);

class MapPin {
  const MapPin({
    required this.id,
    required this.point,
    this.color = AppColors.brand600,
    this.icon,
    this.label,
    this.pillText,
    this.subtitle,
    this.alignment,
    this.highlighted = false,
    this.onTap,
  });

  final String id;
  final LatLng point;
  final Color color;

  /// Symbol inside the pin head — what kind of thing it marks.
  final IconData? icon;

  /// Short text inside the pin (step numbers on corridors and stories).
  final String? label;

  /// Draws the pin as a named pill instead of a dot — used for whole regions,
  /// provinces, interests and corridors.
  final String? pillText;

  /// Second line under the pill, for a place's name beneath its rating.
  final String? subtitle;

  /// Where a dot marker sits relative to its point (name pills place
  /// themselves; see [_LabelLayer]).
  final Alignment? alignment;

  /// Rough on-screen width of a name pill, so markers fit their label.
  static double pillWidth(String text) => (38 + text.length * 7.1).clamp(60, 200).toDouble();
  final bool highlighted;
  final VoidCallback? onTap;
}

/// flutter_map with the app's tile style, pins and optional route line.
///
/// Tiles: the public OpenStreetMap server — fine for development and testing.
/// OSM's usage policy does not allow heavy production traffic, so before
/// release switch [tileUrl] to a tile plan (MapTiler, Stadia, Mapbox, CARTO…)
/// with its API key.
class AppMap extends StatefulWidget {
  const AppMap({
    super.key,
    this.pins = const [],
    this.routes = const [],
    this.controller,
    this.interactive = true,
    this.fitToPins = true,
    this.initialCenter = cambodiaCenter,
    this.initialZoom = 6.4,
    this.onTapMap,
    this.onZoomChanged,
    this.fitPadding = const EdgeInsets.all(48),
    this.followRoads = true,
  });

  final List<MapPin> pins;
  final List<MapRoute> routes;
  final MapController? controller;
  final bool interactive;
  final bool fitToPins;
  final LatLng initialCenter;
  final double initialZoom;
  final VoidCallback? onTapMap;

  /// Reports the camera zoom, so callers can show more detail as you zoom in.
  final ValueChanged<double>? onZoomChanged;
  final EdgeInsets fitPadding;

  /// Bends route lines onto real roads (see [RoutingService]). Off for maps
  /// where the straight line is the point, like story hops.
  final bool followRoads;

  /// Widget tests have no cache-directory plugin; they turn tile caching off.
  @visibleForTesting
  static bool useTileCache = true;

  /// Widget tests have no network; they keep routes straight.
  @visibleForTesting
  static bool useRoadRouting = true;

  @override
  State<AppMap> createState() => _AppMapState();
}

class _AppMapState extends State<AppMap> {
  /// Straight lines to begin with, replaced by road geometry once it arrives.
  late List<MapRoute> _routes = widget.routes;

  @override
  void initState() {
    super.initState();
    _snapToRoads();
  }

  @override
  void didUpdateWidget(AppMap old) {
    super.didUpdateWidget(old);
    if (_routeKey(old.routes) != _routeKey(widget.routes)) {
      _routes = widget.routes;
      _snapToRoads();
    }
  }

  static String _routeKey(List<MapRoute> routes) =>
      routes.map((r) => r.points.map((p) => '${p.latitude},${p.longitude}').join(';')).join('|');

  Future<void> _snapToRoads() async {
    if (!widget.followRoads || !AppMap.useRoadRouting) return;
    final wanted = _routeKey(widget.routes);
    final snapped = [
      for (final r in widget.routes) MapRoute(await RoutingService.road(r.points), color: r.color),
    ];
    // The screen may have moved on while the routes were being fetched.
    if (mounted && _routeKey(widget.routes) == wanted) setState(() => _routes = snapped);
  }

  @override
  Widget build(BuildContext context) {
    final pins = widget.pins;
    final routes = _routes;
    final fitToPins = widget.fitToPins;
    final fitPadding = widget.fitPadding;
    final initialCenter = widget.initialCenter;
    final initialZoom = widget.initialZoom;
    final controller = widget.controller;
    final interactive = widget.interactive;
    final onTapMap = widget.onTapMap;
    final onZoomChanged = widget.onZoomChanged;
    final fit = fitToPins && pins.length > 1
        ? CameraFit.bounds(
            bounds: LatLngBounds.fromPoints(pins.map((p) => p.point).toList()),
            padding: fitPadding,
            maxZoom: 14,
          )
        : null;
    final center = pins.length == 1 ? pins.first.point : initialCenter;
    final zoom = pins.length == 1 ? 12.0 : initialZoom;

    final dots = pins.where((p) => p.pillText == null).toList();
    final labels = pins.where((p) => p.pillText != null).toList();

    // flutter_map still builds on package:flutter/material, so its attribution
    // widgets need the legacy Material theme/localizations provided here.
    // ignore: deprecated_member_use
    return MaterialUiCompatibilityBridge(
      child: FlutterMap(
        mapController: controller,
        options: MapOptions(
          initialCenter: center,
          initialZoom: zoom,
          initialCameraFit: fit,
          minZoom: 5,
          maxZoom: 18,
          backgroundColor: const Color(0xFFE9EEF0),
          interactionOptions: InteractionOptions(
            flags: interactive ? InteractiveFlag.all & ~InteractiveFlag.rotate : InteractiveFlag.none,
          ),
          onTap: onTapMap == null ? null : (_, _) => onTapMap(),
          onPositionChanged: onZoomChanged == null ? null : (camera, _) => onZoomChanged(camera.zoom),
        ),
        children: [
          TileLayer(
            urlTemplate: tileUrl,
            userAgentPackageName: 'com.amstravel.ams_travel',
            tileProvider: NetworkTileProvider(
              cachingProvider: AppMap.useTileCache ? null : const DisabledMapCachingProvider(),
            ),
          ),
          if (routes.any((r) => r.points.length > 1))
            PolylineLayer(
              polylines: [
                for (final r in routes)
                  if (r.points.length > 1)
                    Polyline(
                      points: r.points,
                      strokeWidth: 5,
                      color: r.color,
                      borderStrokeWidth: 3,
                      borderColor: Colors.white,
                      strokeCap: StrokeCap.round,
                      strokeJoin: StrokeJoin.round,
                    ),
              ],
            ),
          MarkerLayer(
            markers: [
              // Highlighted pin last so it draws on top.
              for (final p in [...dots.where((p) => !p.highlighted), ...dots.where((p) => p.highlighted)])
                Marker(
                  point: p.point,
                  width: p.highlighted ? 46 : 36,
                  height: p.highlighted ? 46 : 36,
                  // A teardrop points at its coordinate; a numbered stop sits
                  // right on it.
                  alignment: p.alignment ?? (p.label != null ? Alignment.center : Alignment.bottomCenter),
                  child: _PinDot(pin: p),
                ),
            ],
          ),
          if (labels.isNotEmpty) _LabelLayer(pins: labels),
          const RichAttributionWidget(
            showFlutterMapAttribution: false,
            attributions: [TextSourceAttribution('OpenStreetMap contributors')],
          ),
        ],
      ),
    );
  }
}

/// Map pin. A place is a filled teardrop with a white centre; a numbered stop
/// on a route is a round badge carrying its step number.
class _PinDot extends StatelessWidget {
  const _PinDot({required this.pin});
  final MapPin pin;

  @override
  Widget build(BuildContext context) {
    final color = pin.highlighted ? AppColors.sunset500 : pin.color;
    final size = pin.highlighted ? 46.0 : 36.0;
    const shadow = [BoxShadow(color: Color(0x4D000000), blurRadius: 5, offset: Offset(0, 2))];

    if (pin.label != null) {
      return GestureDetector(
        onTap: pin.onTap,
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: Container(
            width: size * 0.78,
            height: size * 0.78,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2.5),
              boxShadow: shadow,
            ),
            alignment: Alignment.center,
            child: Text(
              pin.label!,
              style: AppText.sans(size * 0.34, weight: FontWeight.w700, color: Colors.white),
            ),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: pin.onTap,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          // Sits behind the pin, showing through the hole in its head.
          Positioned(
            top: size * 0.2,
            child: Container(
              width: size * 0.34,
              height: size * 0.34,
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            ),
          ),
          Icon(
            Icons.location_on,
            size: size,
            color: color,
            shadows: const [Shadow(color: Color(0x4D000000), blurRadius: 4, offset: Offset(0, 2))],
          ),
          if (pin.icon != null)
            Positioned(
              top: size * 0.23,
              child: Icon(pin.icon, size: size * 0.29, color: color),
            ),
        ],
      ),
    );
  }
}

/// Name pills placed from the live camera, so neighbours don't cover each
/// other at any zoom. Each label tries its own point first, then steps above
/// and below (nudged sideways), staying inside the map; a moved label leaves a
/// small dot on the real spot.
class _LabelLayer extends StatelessWidget {
  const _LabelLayer({required this.pins});
  final List<MapPin> pins;

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.of(context);
    final area = (Offset.zero & camera.nonRotatedSize).deflate(4);
    final placed = <Rect>[];
    final children = <Widget>[];

    // Highlighted labels first so they keep their spot.
    final ordered = [...pins.where((p) => p.highlighted), ...pins.where((p) => !p.highlighted)];
    for (final pin in ordered) {
      final at = camera.latLngToScreenOffset(pin.point);
      if (!area.inflate(80).contains(at)) continue;
      // A label with a name under its pill needs the room for both lines.
      final h = pin.subtitle == null ? 28.0 : 48.0;
      final w = [MapPin.pillWidth(pin.pillText!), if (pin.subtitle != null) MapPin.pillWidth(pin.subtitle!)]
          .reduce((a, b) => a > b ? a : b);
      Rect? chosen;
      for (final dy in const [0.0, -1.0, 1.0, -2.0, 2.0, -3.0, 3.0, -4.0, 4.0]) {
        for (final dx in const [0.0, 0.5, -0.5, 1.0, -1.0]) {
          final rect = Rect.fromCenter(center: at.translate(dx * w, dy * (h + 3)), width: w, height: h);
          final inside = area.contains(rect.topLeft) && area.contains(rect.bottomRight);
          if (inside && !placed.any((r) => r.inflate(2).overlaps(rect))) {
            chosen = rect;
            break;
          }
        }
        if (chosen != null) break;
      }
      chosen ??= Rect.fromCenter(center: at, width: w, height: h);
      placed.add(chosen);

      if ((chosen.center - at).distance > 1) {
        children.add(
          Positioned(
            left: at.dx - 4,
            top: at.dy - 4,
            child: IgnorePointer(
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: pin.color,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
              ),
            ),
          ),
        );
      }
      children.add(
        Positioned.fromRect(
          rect: chosen,
          child: _PinPill(pin: pin),
        ),
      );
    }
    return Stack(children: children);
  }
}

/// A line drawn on the map (a corridor route, a story trail).
class MapRoute {
  const MapRoute(this.points, {this.color = AppColors.route});
  final List<LatLng> points;
  final Color color;
}

/// Named marker for a whole region / province / interest / corridor.
class _PinPill extends StatelessWidget {
  const _PinPill({required this.pin});
  final MapPin pin;

  @override
  Widget build(BuildContext context) {
    final pill = GestureDetector(
      onTap: pin.onTap,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: pin.highlighted ? pin.color : Colors.white,
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: pin.highlighted ? Colors.white : pin.color, width: 1.6),
            boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 6, offset: Offset(0, 2))],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(color: pin.highlighted ? Colors.white : pin.color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  pin.pillText!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.sans(
                    11.5,
                    weight: FontWeight.w700,
                    color: pin.highlighted ? Colors.white : AppColors.sand900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (pin.subtitle == null) return pill;
    return GestureDetector(
      onTap: pin.onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          pill,
          const SizedBox(height: 2),
          Text(
            pin.subtitle!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: AppText.sans(11, weight: FontWeight.w700, color: AppColors.sand900).copyWith(
              shadows: const [Shadow(color: Colors.white, blurRadius: 4)],
            ),
          ),
        ],
      ),
    );
  }
}

/// Rounded, fixed-height map preview used inside detail pages.
class MapPreview extends StatelessWidget {
  const MapPreview({super.key, required this.child, this.height = 240, this.onExpand, this.expandLabel});
  final Widget child;
  final double height;
  final VoidCallback? onExpand;
  final String? expandLabel;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTheme.radius),
      child: SizedBox(
        height: height,
        child: Stack(
          children: [
            Positioned.fill(child: child),
            if (onExpand != null)
              Positioned(
                right: 10,
                top: 10,
                child: Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(99),
                  elevation: 2,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(99),
                    onTap: onExpand,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.open_in_full_rounded, size: 15, color: AppColors.brand600),
                          if (expandLabel != null) ...[
                            const SizedBox(width: 6),
                            Text(
                              expandLabel!,
                              style: AppText.sans(12.5, weight: FontWeight.w600, color: AppColors.brand700),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
