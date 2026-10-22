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
import '../../core/utils/location.dart';
import '../../data/api/ams_api.dart';
import '../../state/collections_provider.dart';
import '../../widgets/app_image.dart';
import '../../widgets/common.dart';
import '../../widgets/overview_card.dart';
import '../../widgets/hero_app_bar.dart';
import '../../widgets/destination_card.dart';
import '../../widgets/filter_chips.dart' show categoryIcons;
import '../../widgets/map_view.dart';

/// The pieces every detail page is built from (attraction, stay, food):
/// the photos at the top, the white section cards, the quote, the
/// description, the map and the small cards of the nearby rows.

/// The cover first, then the gallery, without showing the cover twice.
List<String> galleryUrls(String coverUrl, List<MediaItem> media) {
  final urls = <String>[if (coverUrl.isNotEmpty) coverUrl];
  for (final m in media) {
    if (m.url.isNotEmpty && !urls.contains(m.url)) urls.add(m.url);
  }
  return urls;
}

/// Swipeable photos with a dot per photo and a Gallery button, under the
/// back, save and share buttons, which stay pinned at the top while the
/// page scrolls.
class PlaceHero extends StatefulWidget {
  const PlaceHero({super.key, required this.photos, required this.kind, required this.id, required this.shareText});

  final List<String> photos;
  final SavedKind kind;
  final String id;
  final String shareText;

  @override
  State<PlaceHero> createState() => _PlaceHeroState();
}

class _PlaceHeroState extends State<PlaceHero> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final photos = widget.photos;
    return HeroAppBar(
      height: 320,
      actions: [
        SaveButton(kind: widget.kind, itemKey: widget.id, size: 44),
        GlassIconButton(
          icon: Icons.ios_share_rounded,
          tooltip: s.share,
          onPressed: () => SharePlus.instance.share(ShareParams(text: widget.shareText)),
        ),
      ],
      background: ClipRRect(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (photos.isEmpty)
              const AppImage('')
            else
              PageView.builder(
                controller: _controller,
                itemCount: photos.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (_, i) => AppImage(photos[i]),
              ),
            if (photos.length > 1) ...[
              // One dot per photo; the one on show in violet.
              Positioned(
                left: 0,
                right: 0,
                bottom: 18,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < photos.length; i++)
                      Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.symmetric(horizontal: 3.5),
                        decoration: BoxDecoration(
                          color: i == _page ? AppColors.violet : Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
              ),
              Positioned(
                right: 16,
                bottom: 12,
                child: Glass(
                  circle: false,
                  child: InkWell(
                    onTap: () => showPhotoViewer(context, photos, initial: _page),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.photo_outlined, size: 18, color: Colors.white),
                          const SizedBox(width: 7),
                          Text(
                            s.gallery,
                            style: AppText.sans(13, weight: FontWeight.w500, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The photos full screen, swipeable and zoomable, from [initial].
void showPhotoViewer(BuildContext context, List<String> photos, {int initial = 0}) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (context) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white),
        body: PageView.builder(
          controller: PageController(initialPage: initial),
          itemCount: photos.length,
          itemBuilder: (_, i) => InteractiveViewer(
            child: Center(child: AppImage(photos[i], fit: BoxFit.contain)),
          ),
        ),
      ),
    ),
  );
}

/// What to share for a place: its name, its line and where it is on a map.
String shareTextFor(String name, {String? line, double? latitude, double? longitude}) => [
  name,
  if (line != null && line.isNotEmpty) line,
  if (latitude != null && longitude != null) 'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude',
].join('\n');

/// A section of a place's page: a heading and its content in a
/// [GradientCard], with the page's side margins.
class InfoCard extends StatelessWidget {
  const InfoCard({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      child: GradientCard(title: title, child: child),
    );
  }
}

/// A heading and its content straight on the page, with no panel around
/// them (a stay's facilities).
class PlainSection extends StatelessWidget {
  const PlainSection({super.key, required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 26, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppText.display(20)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

/// A violet outline chip under the title.
class OutlineTag extends StatelessWidget {
  const OutlineTag({super.key, required this.label, required this.icon, this.color = AppColors.violet});
  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              style: AppText.sans(12.5, weight: FontWeight.w600, color: color),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// A category of a place: a filled pill with the category's symbol. Every
/// category chip on a place's page looks like this.
class CategoryTag extends StatelessWidget {
  const CategoryTag({super.key, required this.label, this.icon, this.color = AppColors.violet});
  final String label;

  /// The category's own symbol when left out.
  final IconData? icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(99)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon ?? categoryIcons[label] ?? Icons.place_outlined, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: AppText.sans(13, weight: FontWeight.w500, color: Colors.white),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// The seal under a place's name: the travellers' if they gave it, else
/// AMS's. Nothing when the card has neither.
class SealLine extends StatelessWidget {
  const SealLine({super.key, required this.card});
  final PlaceCard? card;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final seal = s.seal(traveler: card?.travelerRecommended ?? false, verified: card?.verified ?? false);
    if (seal == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          const Icon(Icons.verified_rounded, size: 18, color: AppColors.seal),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              seal,
              style: AppText.sans(13, color: AppColors.sand700),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// The score line under a title: stars, the average and how many reviews,
/// or "No reviews yet".
class RatingLine extends StatelessWidget {
  const RatingLine({super.key, required this.average, required this.count});
  final double? average;
  final int count;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    if (average == null) return Text(s.noReviews, style: AppText.sans(13.5, color: AppColors.sand500));
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.star_rounded, size: 22, color: AppColors.star),
        const SizedBox(width: 6),
        Text(
          average!.toStringAsFixed(1),
          style: AppText.sans(15, weight: FontWeight.w700, color: AppColors.sand900),
        ),
        if (count > 0)
          Flexible(
            child: Text(
              '  ·  ${s.reviewCountText(count)}',
              style: AppText.sans(13.5, color: AppColors.sand600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
    );
  }
}

/// The place's own slogan, pulled out above the description, with who said
/// it. Nothing shows when the place has none.
class SloganQuote extends StatelessWidget {
  const SloganQuote({super.key, required this.slogan, this.by});
  final String? slogan;
  final String? by;

  @override
  Widget build(BuildContext context) {
    final words = slogan?.trim() ?? '';
    if (words.isEmpty) return const SizedBox.shrink();
    final style = AppText.sans(15.5, color: AppColors.violet, height: 1.5).copyWith(fontStyle: FontStyle.italic);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: GradientFrame(
        padding: const EdgeInsets.fromLTRB(12, 14, 16, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // An opening quote mark: the closing one turned over.
            Transform.rotate(
              angle: 3.14159,
              child: const Icon(Icons.format_quote_outlined, size: 34, color: Color(0xFFE85A6B)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('"$words"', style: style),
                  if (by != null && by!.trim().isNotEmpty)
                    Text('— ${by!.trim()}', style: style.copyWith(fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The description (it may be HTML) in an [OverviewCard].
class DescriptionCard extends StatefulWidget {
  const DescriptionCard({super.key, this.short, this.long});

  /// The short description, shown only when there is no full one (it is the
  /// card's line, and the CMS edits only the full one); either may hold HTML.
  final String? short;
  final String? long;

  @override
  State<DescriptionCard> createState() => _DescriptionCardState();
}

class _DescriptionCardState extends State<DescriptionCard> {
  // Converted once, not on every rebuild.
  late String _text;

  @override
  void initState() {
    super.initState();
    _convert();
  }

  @override
  void didUpdateWidget(DescriptionCard old) {
    super.didUpdateWidget(old);
    if (old.short != widget.short || old.long != widget.long) _convert();
  }

  void _convert() => _text = htmlToText(
    [widget.long, widget.short].whereType<String>().firstWhere((t) => t.trim().isNotEmpty, orElse: () => ''),
  );

  @override
  Widget build(BuildContext context) => _text.isEmpty
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
          child: OverviewCard(title: S.of(context).overview, text: _text),
        );
}

/// "How to get there": the address, the pin on a small map, the full map and
/// the device's directions.
class LocationCard extends StatelessWidget {
  const LocationCard({
    super.key,
    required this.id,
    this.address,
    required this.latitude,
    required this.longitude,
    this.onFullMap,
  });

  final String id;
  final String? address;
  final double latitude;
  final double longitude;

  /// The full map for this place, when the map can show it.
  final VoidCallback? onFullMap;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final point = LatLng(latitude, longitude);
    final where = address?.trim() ?? '';
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      child: GradientCard(
        title: s.howToGetThere,
        subtitle: where.isEmpty ? null : where,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MapPreview(
              height: 180,
              expandLabel: onFullMap == null ? null : s.seeOnFullMap,
              onExpand: onFullMap,
              child: AppMap(
                interactive: false,
                fitToPins: false,
                initialCenter: point,
                initialZoom: 12,
                pins: [MapPin(id: id, point: point, highlighted: true)],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 46),
                  side: BorderSide(color: AppColors.violet.withValues(alpha: 0.5)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () => openDirections(latitude, longitude),
                icon: const Icon(Icons.directions_rounded, size: 18, color: AppColors.violet),
                label: Text(
                  s.directions,
                  style: AppText.sans(14, weight: FontWeight.w700, color: AppColors.violet),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Words in red outline chips (a stay's amenities).
class KeywordChips extends StatelessWidget {
  const KeywordChips({super.key, required this.words});
  final List<String> words;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final w in words)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(99),
              border: Border.all(color: AppColors.sunset300),
            ),
            child: Text(
              w,
              style: AppText.sans(12.5, weight: FontWeight.w500, color: AppColors.sand800),
            ),
          ),
      ],
    );
  }
}

/// One line of a list such as the house rules.
class Bullet extends StatelessWidget {
  const Bullet({super.key, required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('•  ', style: AppText.sans(13.5, color: AppColors.sand600)),
          Expanded(
            child: Text(text, style: AppText.sans(13.5, color: AppColors.sand700, height: 1.45)),
          ),
        ],
      ),
    );
  }
}

/// The violet bar at the foot of a page.
class BottomActionBar extends StatelessWidget {
  const BottomActionBar({super.key, required this.label, required this.onPressed});
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + MediaQuery.paddingOf(context).bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.sand200)),
      ),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.violet,
            minimumSize: const Size(0, 52),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: onPressed,
          child: Text(
            label,
            style: AppText.sans(15.5, weight: FontWeight.w700, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

/// A heading and a horizontal row of small cards, straight on the page: no
/// panel around them, the row running to the screen's edge.
class CardRow extends StatelessWidget {
  const CardRow({super.key, required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(title, style: AppText.display(20)),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 196,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: children.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (_, i) => children[i],
            ),
          ),
        ],
      ),
    );
  }
}

/// A small card in a nearby row: photo, heart, name and one line under it.
class SmallPlaceCard extends StatelessWidget {
  const SmallPlaceCard({
    super.key,
    required this.image,
    required this.title,
    required this.route,
    required this.kind,
    required this.id,
    this.rating,
    this.line,
    this.distance,
  });

  /// A card from `GET /search/cards`.
  factory SmallPlaceCard.of(PlaceCard c, {required String route}) => SmallPlaceCard(
    image: c.coverUrl,
    title: c.name,
    route: route,
    kind: SavedKind.of(c.type),
    id: c.id,
    rating: c.averageRating,
    // The review count beside a rating; a food place without one shows
    // today's hours.
    line: c.averageRating != null && c.reviewCount > 0 ? '${c.reviewCount}' : c.todayHours,
    distance: c.distanceMeters == null ? null : '${formatKm(c.distanceMeters! / 1000)} $distanceUnit',
  );

  final String image;
  final String title;
  final String route;
  final SavedKind kind;
  final String id;
  final double? rating;

  /// Beside the rating, or on its own when there is no rating.
  final String? line;

  /// How far the place is from the page's place: "5.7 km".
  final String? distance;

  @override
  Widget build(BuildContext context) {
    final after = [if (line != null) rating != null ? '($line)' : line!, ?distance].join(' · ');
    return GestureDetector(
      onTap: () => context.push(route),
      child: SizedBox(
        width: 152,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 126,
              width: double.infinity,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    AppImage(image),
                    Positioned(
                      right: 6,
                      top: 6,
                      child: SaveButton(kind: kind, itemKey: id, size: 32),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: AppText.sans(13.5, weight: FontWeight.w700, color: AppColors.sand900),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (rating != null || after.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  if (rating != null) ...[
                    const Icon(Icons.star_rounded, size: 15, color: AppColors.star),
                    const SizedBox(width: 3),
                    Text(
                      rating!.toStringAsFixed(1),
                      style: AppText.sans(12.5, weight: FontWeight.w700, color: AppColors.sand900),
                    ),
                    const SizedBox(width: 6),
                  ],
                  if (after.isNotEmpty)
                    Expanded(
                      child: Text(
                        after,
                        style: AppText.sans(11.5, color: AppColors.sand500),
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
    );
  }
}

final _separators = RegExp('[-_]+');

/// A code or slug as words: "STREET_FOOD" or "street-food" → "Street food".
String labelOf(String code) {
  final words = code.replaceAll(_separators, ' ').trim().toLowerCase();
  if (words.isEmpty) return code;
  return words[0].toUpperCase() + words.substring(1);
}

/// An amount in the currency the API gave: "US$300", "KHR 120,000".
/// No conversion: riel prices are parked 2026-10-14 (R-006).
String money(double amount, String? currency) {
  final whole = amount == amount.roundToDouble();
  final number = whole
      ? thousands(amount.round())
      : '${thousands(amount.floor())}.${((amount - amount.floor()) * 100).round().toString().padLeft(2, '0')}';
  return switch (currency?.toUpperCase()) {
    null => number,
    'USD' => 'US\$$number',
    'KHR' => '$number ៛',
    final c => '$c $number',
  };
}

/// "US$300 total for 2 nights".
String totalForNights(S s, double total, String? currency, int nights) {
  final price = money(total, currency);
  return nights == 1
      ? s.fill(s.priceTotalOneNight, {'price': price})
      : s.fill(s.priceTotalNights, {'price': price, 'n': nights});
}

/// The page body under the hero: a little space at the foot.
Widget bottomGap(BuildContext context) => SizedBox(height: bottomInset(context));

/// A section that loads on its own and stays out of sight while it loads,
/// when it fails or when [builder] has nothing to show: the page never waits
/// for it.
class LazySection<T> extends StatefulWidget {
  const LazySection({super.key, required this.load, required this.builder});
  final Future<T> Function() load;
  final Widget Function(BuildContext context, T data) builder;

  @override
  State<LazySection<T>> createState() => _LazySectionState<T>();
}

class _LazySectionState<T> extends State<LazySection<T>> {
  late final Future<T> _future = widget.load();

  @override
  Widget build(BuildContext context) => FutureBuilder<T>(
    future: _future,
    builder: (context, snap) => snap.hasData ? widget.builder(context, snap.data as T) : const SizedBox.shrink(),
  );
}

/// A row of [type] cards near the place [near] (`GET /search?near=`),
/// leaving out [excludeId] (the page's own place). Nothing until it loads.
class NearbyRow extends StatelessWidget {
  const NearbyRow({
    super.key,
    required this.title,
    required this.type,
    required this.near,
    this.excludeId,
    this.radiusKm,
  });

  final String title;
  final CardType type;
  final String near;
  final String? excludeId;
  final double? radiusKm;

  @override
  Widget build(BuildContext context) {
    final api = context.read<AmsApi>();
    return LazySection<List<PlaceCard>>(
      load: () => api.search(type: type, near: near, radiusKm: radiusKm).then((page) => page.content),
      builder: (context, cards) => CardRow(
        title: title,
        children: [
          for (final c in cards)
            if (c.id != excludeId) SmallPlaceCard.of(c, route: Routes.card(c)),
        ],
      ),
    );
  }
}
