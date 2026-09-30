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
import 'contact_card.dart';
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

  String _listTitle(S s) => switch (_interest?.slug) {
    'stays' => s.popularFacilities,
    'food' => s.dishesToTry,
    'water' => s.thingsToDo,
    'activities-experiences' => s.whatsIncluded,
    _ => s.highlightsTitle,
  };

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
    final similar = byDistance.where((o) => categories.contains(o.category)).take(6).toList();
    String away(Destination o) => '${formatKm(distanceKm(d.lat, d.lng, o.lat, o.lng))} $distanceUnit ${s.kmAway}';
    final keywords = d.tags.isNotEmpty ? d.tags : d.facets.keys.toList();

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
          if (keywords.isNotEmpty) SliverToBoxAdapter(child: _Keywords(words: keywords)),
          if (d.facilities.isNotEmpty)
            SliverToBoxAdapter(
              child: _Card(
                title: s.popularFacilities,
                child: Column(
                  children: [
                    for (final f in d.facilities)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 7),
                        child: Row(
                          children: [
                            Icon(_facilityIcon(f), size: 19, color: AppColors.sand600),
                            const SizedBox(width: 12),
                            Expanded(child: Text(f, style: AppText.sans(14.5, color: AppColors.sand800))),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          SliverToBoxAdapter(child: _GoodToKnow(destination: d)),
          if (d.highlights.isNotEmpty)
            SliverToBoxAdapter(
              child: _Card(
                title: _listTitle(s),
                child: Column(
                  children: [
                    for (final h in d.highlights)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_outline_rounded, size: 19, color: AppColors.success),
                            const SizedBox(width: 12),
                            Expanded(child: Text(h, style: AppText.sans(14.5, color: AppColors.sand800))),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          if (d.tips.isNotEmpty)
            SliverToBoxAdapter(
              child: _Card(
                title: s.tipsTitle,
                child: Column(
                  children: [
                    for (final t in d.tips)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.lightbulb_outline_rounded, size: 19, color: AppColors.star),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(t, style: AppText.sans(14.5, color: AppColors.sand800, height: 1.4)),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          SliverToBoxAdapter(child: ReviewsSection(destination: d)),
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
          if (d.isStay) SliverToBoxAdapter(child: _Policies(destination: d)),
          if (d.facets.isNotEmpty)
            SliverToBoxAdapter(
              child: _Card(
                title: s.atAGlance,
                child: Column(
                  children: [
                    for (final f in d.facets.entries)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 7),
                        child: Row(
                          children: [
                            Text(f.key, style: AppText.sans(14.5, color: AppColors.sand800)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                f.value,
                                textAlign: TextAlign.right,
                                style: AppText.sans(13.5, weight: FontWeight.w600, color: AppColors.sand700),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          if (similar.isNotEmpty)
            SliverToBoxAdapter(
              child: _Card(
                title: s.youMayLike,
                padded: false,
                child: SizedBox(
                  height: 196,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: similar.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 12),
                    itemBuilder: (_, i) => _SimilarCard(destination: similar[i], caption: away(similar[i])),
                  ),
                ),
              ),
            ),
          // Attraction sites are places you simply turn up at — there is no
          // one to call, so they skip the contact card.
          if (_interest?.slug != 'attraction-sites') SliverToBoxAdapter(child: ContactCard(destination: d)),
          SliverToBoxAdapter(child: SizedBox(height: 28 + MediaQuery.paddingOf(context).bottom)),
        ],
      ),
      bottomNavigationBar: d.isStay ? _RoomsBar(destination: d) : _ActionBar(destination: d),
    );
  }
}

/// Entry price, how long to allow, when to come — only the lines this
/// category uses.
class _GoodToKnow extends StatelessWidget {
  const _GoodToKnow({required this.destination});
  final Destination destination;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final d = destination;
    final hours = formatHours(d);
    final rows = <(IconData, String, String)>[
      if (d.entryFee != null) (Icons.confirmation_number_outlined, s.entryFee, d.entryFee!),
      if (d.priceRange != null) (Icons.payments_outlined, s.priceRangeLabel, d.priceRange!),
      if (d.visitDuration != null) (Icons.schedule_rounded, s.howLong, d.visitDuration!),
      if (d.open24h)
        (Icons.access_time_rounded, s.hoursLabel, s.open24h)
      else if (hours != null)
        (Icons.access_time_rounded, s.hoursLabel, hours),
      if (d.bestTime != null) (Icons.wb_sunny_outlined, s.bestTime, d.bestTime!),
      if (d.bestSeason != null) (Icons.calendar_month_rounded, s.bestSeason, d.bestSeason!),
      if (d.difficulty != null) (Icons.trending_up_rounded, s.difficulty, d.difficulty!),
      if (d.groupSize != null) (Icons.groups_outlined, s.groupSize, d.groupSize!),
    ];
    if (rows.isEmpty) return const SizedBox.shrink();

    return _Card(
      title: s.goodToKnow,
      child: Column(
        children: [
          for (final (icon, label, value) in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(
                children: [
                  Icon(icon, size: 19, color: AppColors.sand500),
                  const SizedBox(width: 12),
                  Text(label, style: AppText.sans(14.5, color: AppColors.sand800)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      value,
                      textAlign: TextAlign.right,
                      style: AppText.sans(13.5, weight: FontWeight.w600, color: AppColors.sand700),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
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
            if (photos.length > 1)
              Positioned(
                right: 16,
                bottom: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${_page + 1}/${photos.length}',
                    style: AppText.sans(12.5, weight: FontWeight.w600, color: Colors.white),
                  ),
                ),
              ),
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

/// House rules. Generic defaults until the API sends the real ones.
class _Policies extends StatelessWidget {
  const _Policies({required this.destination});
  final Destination destination;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final d = destination;
    // TODO(api): replace with the stay's own policies once the backend has them.
    final checkIn = d.openTime ?? '14:00';
    final checkOut = d.closeTime ?? '12:00';
    return _Card(
      title: s.policies,
      child: Column(
        children: [
          _PolicyRow(icon: Icons.login_rounded, label: s.checkIn, value: formatTime(checkIn)),
          _PolicyRow(icon: Icons.logout_rounded, label: s.checkOut, value: formatTime(checkOut)),
          _PolicyRow(icon: Icons.event_busy_outlined, label: s.cancellation, value: s.contactForPolicy),
          _PolicyRow(icon: Icons.pets_outlined, label: s.pets, value: s.contactForPolicy),
        ],
      ),
    );
  }
}

class _PolicyRow extends StatelessWidget {
  const _PolicyRow({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.sand500),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: AppText.sans(14.5, color: AppColors.sand800))),
          Text(value, style: AppText.sans(13.5, weight: FontWeight.w600, color: AppColors.sand600)),
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

/// Nightly price and the call to action. Hidden until the API prices the stay.
class _RoomsBar extends StatelessWidget {
  const _RoomsBar({required this.destination});
  final Destination destination;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
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
            backgroundColor: AppColors.sand900,
            minimumSize: const Size(0, 50),
          ),
          onPressed: () => context.push(Routes.rooms(destination.region, destination.slug)),
          child: Text(s.seeAllRooms),
        ),
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

/// Symbol for a facility line ("Free Wi-Fi", "Swimming pool"…).
IconData _facilityIcon(String facility) {
  final f = facility.toLowerCase();
  bool any(List<String> words) => words.any(f.contains);
  if (any(['wifi', 'wi-fi', 'internet'])) return Icons.wifi_rounded;
  if (any(['front desk', 'reception', '24'])) return Icons.room_service_outlined;
  if (any(['restaurant', 'meal', 'breakfast', 'food', 'dining'])) return Icons.restaurant_rounded;
  if (any(['pool', 'swim'])) return Icons.pool_rounded;
  if (any(['spa', 'massage'])) return Icons.spa_outlined;
  if (any(['bike', 'bicycle', 'cycling'])) return Icons.pedal_bike_rounded;
  if (any(['boat', 'ferry', 'kayak'])) return Icons.directions_boat_outlined;
  if (any(['guide', 'tour', 'trek'])) return Icons.tour_outlined;
  if (any(['air con', 'aircon', 'a/c', 'fan'])) return Icons.ac_unit_rounded;
  if (any(['parking', 'car'])) return Icons.local_parking_rounded;
  if (any(['mosquito', 'bed', 'room', 'net'])) return Icons.bed_outlined;
  if (any(['shower', 'bath', 'toilet'])) return Icons.shower_outlined;
  if (any(['power', 'electric', 'solar'])) return Icons.bolt_rounded;
  return Icons.check_circle_outline_rounded;
}
