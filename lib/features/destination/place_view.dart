import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/geo.dart';
import '../../core/utils/opening_hours.dart';
import '../../data/models/models.dart';
import '../../state/collections_provider.dart';
import '../../widgets/app_image.dart';
import '../../widgets/common.dart';
import '../../widgets/destination_card.dart';
import '../../widgets/map_view.dart';
import 'reviews_section.dart';

/// Detail page for any place. Every category gets the same shape — photos,
/// title, rating, location, facilities, reviews, map, what is nearby and how
/// to get in touch — and the sections in between follow the category: house
/// rules and rooms for a stay, dishes for food, things to do for water, what
/// a tour includes for an experience.
class PlaceView extends StatelessWidget {
  const PlaceView({
    super.key,
    required this.destination,
    required this.region,
    required this.allDestinations,
    required this.interests,
  });

  final Destination destination;
  final Region region;

  /// Everything on the map — the nearest of these become the two card rows.
  final List<Destination> allDestinations;
  final List<Interest> interests;

  /// The interest a place belongs to, which decides its list headings and
  /// what counts as a similar place.
  Interest? get _interest => interests.where((i) => i.categories.contains(destination.category)).firstOrNull;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final d = destination;
    final (title, _) = bilingual(context, d.name, d.nameKh);
    final categories = _interest?.categories.toSet() ?? {d.category};

    final byDistance = allDestinations.where((o) => o.key != d.key).toList()
      ..sort((a, b) => distanceKm(d.lat, d.lng, a.lat, a.lng).compareTo(distanceKm(d.lat, d.lng, b.lat, b.lng)));
    // Nearby is what else is around; "you may like" stays in the same interest.
    final nearby = byDistance.where((o) => !categories.contains(o.category)).take(8).toList();
    String away(Destination o) => '${formatKm(distanceKm(d.lat, d.lng, o.lat, o.lng))} $distanceUnit ${s.kmAway}';
    // The chips under the map: what a stay offers, or what a place is known
    // for.
    final keywords = d.isStay && d.facilities.isNotEmpty
        ? d.facilities
        : (d.tags.isNotEmpty ? d.tags : d.facets.keys.toList());

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _Hero(destination: d),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
              child: _TitleBlock(destination: d, title: title, interest: _interest),
            ),
          ),
          SliverToBoxAdapter(child: _Description(destination: d)),
          SliverToBoxAdapter(
            child: _Card(
              title: s.howToGetThere,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${d.province}, Cambodia', style: AppText.sans(13.5, color: AppColors.sand500)),
                  const SizedBox(height: 12),
                  MapPreview(
                    height: 180,
                    expandLabel: s.seeOnFullMap,
                    onExpand: () => context.go(Routes.mapFocus(d.key)),
                    child: AppMap(
                      interactive: false,
                      fitToPins: false,
                      initialCenter: LatLng(d.lat, d.lng),
                      initialZoom: 12,
                      pins: [MapPin(id: d.key, point: LatLng(d.lat, d.lng), highlighted: true)],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (keywords.isNotEmpty) SliverToBoxAdapter(child: _Keywords(words: keywords)),
          SliverToBoxAdapter(child: ReviewsSection(destination: d)),
          if (nearby.isNotEmpty)
            SliverToBoxAdapter(
              child: _Card(
                title: s.recommendNearby,
                padded: false,
                child: SizedBox(
                  height: 196,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: nearby.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 12),
                    itemBuilder: (_, i) => _SimilarCard(destination: nearby[i], caption: away(nearby[i])),
                  ),
                ),
              ),
            ),
          SliverToBoxAdapter(child: SizedBox(height: 28 + MediaQuery.paddingOf(context).bottom)),
        ],
      ),
      bottomNavigationBar: _ActionBar(destination: d),
    );
  }
}

/// Swipeable photos with the back, save and share buttons over them, and a
/// counter in the corner.
class _Hero extends StatefulWidget {
  const _Hero({required this.destination});
  final Destination destination;

  @override
  State<_Hero> createState() => _HeroState();
}

class _HeroState extends State<_Hero> {
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
    final d = widget.destination;
    final photos = d.gallery;
    return SliverToBoxAdapter(
      child: SizedBox(
        height: 320,
        child: Stack(
          fit: StackFit.expand,
          children: [
            PageView.builder(
              controller: _controller,
              itemCount: photos.length,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (_, i) => AppImage(photos[i]),
            ),
            Positioned(
              top: MediaQuery.paddingOf(context).top + 8,
              left: 16,
              right: 16,
              child: Row(
                children: [
                  GlassIconButton(
                    icon: Icons.arrow_back_rounded,
                    tooltip: s.back,
                    onPressed: () => context.pop(),
                  ),
                  const Spacer(),
                  SaveButton(kind: SavedKind.destination, itemKey: d.key, size: 44),
                  const SizedBox(width: 8),
                  GlassIconButton(
                    icon: Icons.ios_share_rounded,
                    tooltip: s.share,
                    onPressed: () => SharePlus.instance.share(
                      ShareParams(
                        text:
                            '${d.name} — ${d.blurb}\nhttps://ams-travel.netlify.app/regions/${d.region}/${d.slug}',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (d.verified)
              Positioned(
                left: 16,
                bottom: 16,
                child: Pill.onImage(s.verified, icon: Icons.verified_rounded),
              ),
            if (photos.length > 1) ...[
              // Where you are in the photos, and how many there are.
              Positioned(
                left: 0,
                right: 0,
                bottom: 18,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < photos.length; i++)
                      Container(
                        width: i == _page ? 18 : 6,
                        height: 6,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: i == _page ? 1 : 0.5),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                  ],
                ),
              ),
              Positioned(
                right: 16,
                bottom: 14,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.photo_library_outlined, size: 14, color: Colors.white),
                      const SizedBox(width: 6),
                      Text(
                        '${s.gallery} ${photos.length}',
                        style: AppText.sans(12, weight: FontWeight.w600, color: Colors.white),
                      ),
                    ],
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

/// Name, what travellers make of it, where it is and what it is.
class _TitleBlock extends StatelessWidget {
  const _TitleBlock({required this.destination, required this.title, this.interest});
  final Destination destination;
  final String title;
  final Interest? interest;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final d = destination;
    final status = openStatus(d);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppText.display(24)),
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(Icons.verified_rounded, size: 15, color: Color(0xFF34D399)),
            const SizedBox(width: 5),
            Text(s.recommendByTraveler, style: AppText.sans(12.5, color: AppColors.sand600)),
            const Spacer(),
            if (d.rating != null) ...[
              const Icon(Icons.star_rounded, size: 17, color: AppColors.star),
              const SizedBox(width: 3),
              Text(
                d.rating!.toStringAsFixed(1),
                style: AppText.sans(13, weight: FontWeight.w700, color: AppColors.sand900),
              ),
              if (d.reviewCount != null)
                Text(
                  ' (${thousands(d.reviewCount!)} ${s.reviewsWord.toLowerCase()})',
                  style: AppText.sans(12.5, color: AppColors.sand500),
                ),
            ] else
              Text(s.noReviews, style: AppText.sans(12.5, color: AppColors.sand500)),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _Tag(label: d.province, icon: Icons.place_outlined),
            _Tag(label: d.category, icon: Icons.local_offer_outlined),
            if (interest != null && interest!.name != d.category)
              _Tag(label: interest!.name, icon: Icons.interests_outlined),
          ],
        ),
        if (status != OpenStatus.unknown) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: (status == OpenStatus.open ? AppColors.success : AppColors.sunset600)
                  .withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(
              status == OpenStatus.open ? s.openNow : s.closedNow,
              style: AppText.sans(
                12.5,
                weight: FontWeight.w600,
                color: status == OpenStatus.open ? AppColors.success : AppColors.sunset600,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// A violet outline chip under the title.
class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.icon});
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: AppColors.violet.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.violet),
          const SizedBox(width: 5),
          Text(label, style: AppText.sans(12.5, weight: FontWeight.w600, color: AppColors.violet)),
        ],
      ),
    );
  }
}

/// What this place is known for, in red outline chips.
class _Keywords extends StatelessWidget {
  const _Keywords({required this.words});
  final List<String> words;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Wrap(
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
              child: Text(w, style: AppText.sans(12.5, weight: FontWeight.w500, color: AppColors.sand800)),
            ),
        ],
      ),
    );
  }
}

/// Write a review or open the place on the map.
class _ActionBar extends StatelessWidget {
  const _ActionBar({required this.destination});
  final Destination destination;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final d = destination;
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 50),
                side: const BorderSide(color: AppColors.violet),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () => context.push(Routes.review(d.region, d.slug)),
              icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.violet),
              label: Text(
                s.writeReview,
                style: AppText.sans(14, weight: FontWeight.w700, color: AppColors.violet),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.violet,
                minimumSize: const Size(0, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () => context.go(Routes.mapFocus(d.key)),
              icon: const Icon(Icons.place_outlined, size: 18, color: Colors.white),
              label: Text(s.viewOnMap, style: AppText.sans(14, weight: FontWeight.w700, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Blurb and detail, folded to four lines until "Read more".
class _Description extends StatefulWidget {
  const _Description({required this.destination});
  final Destination destination;

  @override
  State<_Description> createState() => _DescriptionState();
}

class _DescriptionState extends State<_Description> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final d = widget.destination;
    final text = [d.blurb, ?d.detail].join('\n\n');
    return _Card(
      title: s.description,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            text,
            style: AppText.sans(14.5, color: AppColors.sand700, height: 1.6),
            maxLines: _expanded ? null : 4,
            overflow: _expanded ? TextOverflow.clip : TextOverflow.ellipsis,
          ),
          if (d.detail != null) ...[
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Text(
                _expanded ? s.showLess : s.readMore,
                style: AppText.sans(14, weight: FontWeight.w600, color: AppColors.brand600),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Small card in the "You may like" row.
class _SimilarCard extends StatelessWidget {
  const _SimilarCard({required this.destination, this.caption});
  final Destination destination;

  /// Small grey line under the name — how far away it is.
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final d = destination;
    return GestureDetector(
      onTap: () => context.push(Routes.destination(d.region, d.slug)),
      child: SizedBox(
        width: 150,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 120,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  AppImage(d.image, radius: BorderRadius.circular(16)),
                  Positioned(
                    top: 6,
                    left: 6,
                    child: SaveButton(kind: SavedKind.destination, itemKey: d.key, size: 30),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              bilingual(context, d.name, d.nameKh).$1,
              style: AppText.sans(13.5, weight: FontWeight.w700, color: AppColors.sand900),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (caption != null)
              Text(caption!, style: AppText.sans(12, color: AppColors.sand500), maxLines: 1),
          ],
        ),
      ),
    );
  }
}

/// White panel with a heading — every section on this page sits in one.
class _Card extends StatelessWidget {
  const _Card({required this.title, required this.child, this.padded = true});

  final String title;
  final Widget child;

  /// False lets the content run to the edges (the horizontal card row).
  final bool padded;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(padded ? 16 : 0, 16, padded ? 16 : 0, 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radius),
          border: Border.all(color: AppColors.sand200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: padded ? 0 : 16),
              child: Text(title, style: AppText.display(17)),
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}
