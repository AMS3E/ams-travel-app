import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/geo.dart';
import '../../core/utils/opening_hours.dart';
import '../../data/models/models.dart';
import '../../data/repositories/travel_repository.dart';
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
          SliverToBoxAdapter(child: _Quote(destination: d)),
          SliverToBoxAdapter(child: _Description(destination: d)),
          // Facilities, house rules and contact belong to a stay; an
          // attraction or a place to eat shows the design's sections only.
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
          // What a stay offers, between the map and what travellers say.
          if (d.isStay && d.facilities.isNotEmpty)
            SliverToBoxAdapter(child: _Keywords(words: d.facilities)),
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
                    itemBuilder: (_, i) => _SimilarCard(destination: nearby[i]),
                  ),
                ),
              ),
            ),
          if (d.isStay) SliverToBoxAdapter(child: _StayPolicies(destination: d)),
          if (d.isStay && (d.phone != null || d.website != null))
            SliverToBoxAdapter(child: _ContactPills(destination: d)),
          SliverToBoxAdapter(child: SizedBox(height: 28 + MediaQuery.paddingOf(context).bottom)),
        ],
      ),
      bottomNavigationBar: d.isStay ? _RoomsBar(destination: d) : null,
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppText.display(24)),
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(Icons.verified_rounded, size: 15, color: Color(0xFF34D399)),
            const SizedBox(width: 5),
            // The score and what the place is are never cut; the line on the
            // left gives way instead.
            Flexible(
              child: Text(
                s.recommendByTraveler,
                style: AppText.sans(12.5, color: AppColors.sand600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 10),
            if (d.rating != null) ...[
              const Icon(Icons.star_rounded, size: 17, color: AppColors.star),
              const SizedBox(width: 3),
              Text(
                d.rating!.toStringAsFixed(1),
                style: AppText.sans(13, weight: FontWeight.w700, color: AppColors.sand900),
              ),
              if (d.reviewCount != null)
                Text(
                  ' ${thousands(d.reviewCount!)} ${s.reviewsWord.toLowerCase()}'
                  '${d.stars == null ? '' : '  ·  ${d.stars}-star ${_stayNoun(d.category)}'}',
                  style: AppText.sans(11.5, color: AppColors.sand500),
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
            // A stay says when its reception is open; elsewhere the chips are
            // about what kind of place it is.
            if (d.isStay && openStatus(d) != OpenStatus.unknown)
              _Tag(
                label: d.open24h ? s.open24h : s.openNow,
                icon: Icons.schedule_rounded,
                color: AppColors.success,
              ),
            _Tag(label: d.category, icon: Icons.local_offer_outlined),
            if (interest != null && interest!.name != d.category)
              _Tag(label: interest!.name, icon: Icons.interests_outlined),
          ],
        ),
      ],
    );
  }
}

/// What a traveller said about the place, pulled out above the description.
/// Nothing is shown until someone has written something.
class _Quote extends StatelessWidget {
  const _Quote({required this.destination});
  final Destination destination;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Review>>(
      future: context.read<TravelRepository>().getReviews(destination.ref),
      builder: (context, snap) {
        final reviews = snap.data ?? const <Review>[];
        if (reviews.isEmpty) return const SizedBox.shrink();
        final best = reviews.reduce((a, b) => b.rating > a.rating ? b : a);
        final words = best.text ?? best.title;
        if (words == null || words.isEmpty) return const SizedBox.shrink();

        return Container(
          margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.violet.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.violet.withValues(alpha: 0.25)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.format_quote_rounded, size: 20, color: AppColors.violet.withValues(alpha: 0.6)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      words,
                      style: AppText.sans(
                        13.5,
                        color: AppColors.violet,
                        height: 1.5,
                      ).copyWith(fontStyle: FontStyle.italic),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '— ${best.author}',
                      style: AppText.sans(12, weight: FontWeight.w600, color: AppColors.violet),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// What a stay offers, in red outline chips.
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

/// What a stay is called once it has a star rating: "5-star hotel".
String _stayNoun(String category) => switch (category) {
  'Homestay' => 'homestay',
  'Eco Lodge' => 'lodge',
  'Private Island' => 'resort',
  _ => 'hotel',
};

/// A violet outline chip under the title.
class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.icon, this.color = AppColors.violet});
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
          Text(label, style: AppText.sans(12.5, weight: FontWeight.w600, color: color)),
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
            backgroundColor: AppColors.violet,
            minimumSize: const Size(0, 52),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: () => context.push(Routes.rooms(destination.region, destination.slug)),
          child: Text(s.viewRooms, style: AppText.sans(15.5, weight: FontWeight.w700, color: Colors.white)),
        ),
      ),
    );
  }
}

/// House rules, as the design lists them.
///
/// TODO(api): the times and the note are the same for every stay until the
/// backend sends each one's own.
class _StayPolicies extends StatelessWidget {
  const _StayPolicies({required this.destination});
  final Destination destination;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final d = destination;
    final checkIn = formatTime(d.openTime ?? '14:00');
    final checkOut = formatTime(d.closeTime ?? '12:00');

    return _Card(
      title: s.stayPolicies,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Bullet(text: '${s.checkIn}: ${s.fromTime} $checkIn'),
          _Bullet(text: '${s.checkOut}: ${s.beforeTime} $checkOut'),
          _Bullet(text: s.earlyCheckInNote),
        ],
      ),
    );
  }
}

/// One line of the house rules.
class _Bullet extends StatelessWidget {
  const _Bullet({required this.text});
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



/// How to reach the stay: a row per way, big enough to read and to tap.
class _ContactPills extends StatelessWidget {
  const _ContactPills({required this.destination});
  final Destination destination;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final d = destination;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.sand200),
      ),
      child: Column(
        children: [
          if (d.phone != null)
            _ContactRow(
              icon: Icons.call_rounded,
              label: s.callWord,
              value: d.phone!,
              onTap: () => launchUrl(Uri.parse('tel:${d.phone!.replaceAll(' ', '')}')),
            ),
          if (d.phone != null && d.website != null)
            const Divider(height: 1, color: AppColors.sand200),
          if (d.website != null)
            _ContactRow(
              icon: Icons.public_rounded,
              label: s.website,
              // Just the site's name; the whole link is what opens.
              value: d.website!.replaceFirst(RegExp('^https?://'), '').split('/').first,
              onTap: () => launchUrl(
                Uri.parse(d.website!.startsWith('http') ? d.website! : 'https://${d.website!}'),
                mode: LaunchMode.externalApplication,
              ),
            ),
        ],
      ),
    );
  }
}

/// One way of getting in touch.
class _ContactRow extends StatelessWidget {
  const _ContactRow({required this.icon, required this.label, required this.value, required this.onTap});
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.violet.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 20, color: AppColors.violet),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: AppText.sans(11.5, color: AppColors.sand500)),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: AppText.sans(15, weight: FontWeight.w700, color: AppColors.sand900),
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
    );
  }
}

/// Small card in the "You may like" row.
class _SimilarCard extends StatelessWidget {
  const _SimilarCard({required this.destination});
  final Destination destination;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final d = destination;
    return GestureDetector(
      onTap: () => context.push(Routes.destination(d.region, d.slug)),
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
                    AppImage(d.image),
                    Positioned(
                      right: 6,
                      top: 6,
                      child: SaveButton(kind: SavedKind.destination, itemKey: d.key, size: 32),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              bilingual(context, d.name, d.nameKh).$1,
              style: AppText.sans(13.5, weight: FontWeight.w700, color: AppColors.sand900),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (d.rating != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.star_rounded, size: 15, color: AppColors.star),
                  const SizedBox(width: 3),
                  Text(
                    d.rating!.toStringAsFixed(1),
                    style: AppText.sans(12.5, weight: FontWeight.w700, color: AppColors.sand900),
                  ),
                  if (d.reviewCount != null) ...[
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${thousands(d.reviewCount!)} ${s.reviewsWord.toLowerCase()}',
                        style: AppText.sans(11.5, color: AppColors.sand500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            ],
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

