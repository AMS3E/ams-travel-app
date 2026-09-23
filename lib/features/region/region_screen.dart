import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/models.dart';
import '../../data/repositories/travel_repository.dart';
import '../../state/collections_provider.dart';
import '../../widgets/app_image.dart';
import '../../widgets/async_view.dart';
import '../../widgets/common.dart';
import '../../widgets/destination_card.dart';
import '../../widgets/map_view.dart';

const regionViolet = Color(0xFF5B2EE5);
const tagRed = Color(0xFFE23E57);

class RegionScreen extends StatelessWidget {
  const RegionScreen({super.key, required this.slug});
  final String slug;

  @override
  Widget build(BuildContext context) {
    final repo = context.read<TravelRepository>();
    return AsyncView<(Region, List<Destination>, List<Story>, List<Review>)>(
      load: () => (
        repo.getRegion(slug),
        repo.getDestinations(region: slug),
        repo.getStories(slug),
        repo.getRegionReviews(slug),
      ).wait,
      loading: const Scaffold(body: LoadingView()),
      builder: (context, data, _) => _RegionView(region: data.$1, places: data.$2, stories: data.$3, reviews: data.$4),
    );
  }
}

class _RegionView extends StatelessWidget {
  const _RegionView({required this.region, required this.places, required this.stories, required this.reviews});
  final Region region;
  final List<Destination> places;
  final List<Story> stories;
  final List<Review> reviews;

  /// Opens a sheet listing [list] under [title].
  void _showPlaces(BuildContext context, String title, List<Destination> list) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        builder: (context, scroll) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: AppText.sans(19, weight: FontWeight.w800, color: AppColors.sand900),
                    ),
                  ),
                  Text(
                    '${list.length}',
                    style: AppText.sans(14, weight: FontWeight.w700, color: regionViolet),
                  ),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: ListView.builder(
                controller: scroll,
                itemCount: list.length,
                itemBuilder: (_, i) => PlaceRow(destination: list[i]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final (title, _) = bilingual(context, region.name, region.nameKh);
    final rated = places.where((d) => d.rating != null).toList();
    final rating = rated.isEmpty ? null : rated.map((d) => d.rating!).reduce((a, b) => a + b) / rated.length;
    final categories = places.map((d) => d.category).toSet().toList()..sort();
    final tags = <String>{for (final d in places) ...d.facets.keys}.toList()..sort();
    final liked = (places.toList()..sort((a, b) => (b.rating ?? 0).compareTo(a.rating ?? 0))).take(10).toList();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: ListView(
          padding: EdgeInsets.only(bottom: 32 + MediaQuery.paddingOf(context).bottom),
          children: [
            _Hero(region: region),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppText.sans(24, weight: FontWeight.w800, color: AppColors.sand900, height: 1.2),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.verified_rounded, size: 16, color: Color(0xFF22C55E)),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(s.recommendByTraveler, style: AppText.sans(13, color: AppColors.sand600)),
                      ),
                      if (rating != null) ...[
                        Stars(rating.round(), size: 15),
                        const SizedBox(width: 5),
                        Text(
                          rating.toStringAsFixed(1),
                          style: AppText.sans(13.5, weight: FontWeight.w700, color: AppColors.sand900),
                        ),
                        Text(
                          ' (${places.length} ${s.places.toLowerCase()})',
                          style: AppText.sans(13, color: AppColors.sand500),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final c in categories)
                        RegionChip(
                          label: c,
                          color: regionViolet,
                          filled: true,
                          onTap: () => _showPlaces(context, c, places.where((d) => d.category == c).toList()),
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _Overview(text: region.coreIdentity),
                  const SizedBox(height: 18),
                  _MapCard(region: region, places: places, stories: stories),
                ],
              ),
            ),

            RegionSectionHeader(title: s.whatTravelersSay),
            ReviewsCarousel(reviews: reviews),

            // Ancient capitals (stories) or the region's own highlight list.
            if (region.highlights.isNotEmpty) ...[
              RegionSectionHeader(title: stories.isNotEmpty ? s.exploreByCapitals : region.highlightTitle),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    if (stories.isNotEmpty)
                      for (final st in stories) _StoryRow(story: st)
                    else
                      for (final h in region.highlights) _HighlightRow(highlight: h),
                  ],
                ),
              ),
            ],

            RegionSectionHeader(title: s.youMayLike, onMore: () => _showPlaces(context, title, places)),
            SizedBox(
              height: 152,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: liked.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (_, i) => LikeCard(destination: liked[i]),
              ),
            ),

            if (tags.isNotEmpty) ...[
              RegionSectionHeader(title: s.relatedTags),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final t in tags)
                      RegionChip(
                        label: t,
                        color: tagRed,
                        filled: true,
                        onTap: () => _showPlaces(context, t, places.where((d) => d.facets.containsKey(t)).toList()),
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

/// Photo with back, save and share over it.
class _Hero extends StatelessWidget {
  const _Hero({required this.region});
  final Region region;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    Widget glass(Widget child) => ClipRRect(
      borderRadius: BorderRadius.circular(99),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(color: Colors.white.withValues(alpha: 0.28), child: child),
      ),
    );

    return SizedBox(
      height: 300,
      child: Stack(
        fit: StackFit.expand,
        children: [
          AppImage(region.image),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0, 0.3],
                colors: [Color(0x66000000), Color(0x00000000)],
              ),
            ),
          ),
          Positioned(
            left: 14,
            top: top + 8,
            child: glass(
              IconButton(
                onPressed: () => context.canPop() ? context.pop() : context.go(Routes.home),
                icon: const Icon(Icons.chevron_left_rounded, color: Colors.white, size: 26),
              ),
            ),
          ),
          Positioned(
            right: 14,
            top: top + 8,
            child: glass(
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _SaveIcon(slug: region.slug),
                  IconButton(
                    onPressed: () => SharePlus.instance.share(
                      ShareParams(
                        text:
                            '${region.name} — ${region.tagline}\nhttps://ams-travel.netlify.app/regions/${region.slug}',
                      ),
                    ),
                    icon: const Icon(Icons.ios_share_rounded, color: Colors.white, size: 21),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SaveIcon extends StatelessWidget {
  const _SaveIcon({required this.slug});
  final String slug;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final saved = context.select<SavedProvider, bool>((p) => p.isSaved(SavedKind.region, slug));
    return IconButton(
      tooltip: s.save,
      onPressed: () => context.read<SavedProvider>().toggle(SavedKind.region, slug),
      icon: Icon(
        saved ? Icons.favorite_rounded : Icons.favorite_border_rounded,
        color: saved ? AppColors.sunset400 : Colors.white,
        size: 22,
      ),
    );
  }
}

class RegionChip extends StatelessWidget {
  const RegionChip({super.key, required this.label, required this.color, required this.onTap, this.filled = false});
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: filled ? color : Colors.white,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: color),
        ),
        child: Text(
          label,
          style: AppText.sans(12.5, weight: FontWeight.w600, color: filled ? Colors.white : color),
        ),
      ),
    );
  }
}

/// Card with a soft violet-to-peach outline, used for Overview and the map.
class OutlinedCard extends StatelessWidget {
  const OutlinedCard({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.sand200),
      ),
      child: child,
    );
  }
}

class _Overview extends StatefulWidget {
  const _Overview({required this.text});
  final String text;

  @override
  State<_Overview> createState() => _OverviewState();
}

class _OverviewState extends State<_Overview> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return OutlinedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.overview,
            style: AppText.sans(17, weight: FontWeight.w800, color: AppColors.sand900),
          ),
          const SizedBox(height: 8),
          Text(
            widget.text,
            style: AppText.sans(14, color: AppColors.sand600, height: 1.5),
            maxLines: _open ? null : 4,
            overflow: _open ? null : TextOverflow.ellipsis,
          ),
          GestureDetector(
            onTap: () => setState(() => _open = !_open),
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                _open ? s.readLess : s.readMore,
                style: AppText.sans(13.5, weight: FontWeight.w700, color: regionViolet),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Stories on the map when the region has them (Ancient Capitals), otherwise
/// its best places.
class _MapCard extends StatelessWidget {
  const _MapCard({required this.region, required this.places, required this.stories});
  final Region region;
  final List<Destination> places;
  final List<Story> stories;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final historical = stories.isNotEmpty;
    // (point, name, open, colour) for every labelled spot on the map.
    final spots = historical
        ? [
            for (final st in stories)
              (LatLng(st.lat, st.lng), st.name, () => context.push(Routes.story(st.region, st.slug)), regionViolet),
          ]
        : [
            for (final d in (places.toList()..sort((a, b) => (b.rating ?? 0).compareTo(a.rating ?? 0))).take(8))
              (
                LatLng(d.lat, d.lng),
                d.name,
                () => context.push(Routes.destination(d.region, d.slug)),
                AppColors.forRegion(d.region),
              ),
          ];

    return OutlinedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            historical ? s.historicalMap : s.regionMap,
            style: AppText.sans(17, weight: FontWeight.w800, color: AppColors.sand900),
          ),
          const SizedBox(height: 2),
          Text(
            historical ? s.historicalMapSubtitle : s.regionMapSubtitle,
            style: AppText.sans(13, color: AppColors.sand500),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              height: 280,
              child: AppMap(
                fitPadding: const EdgeInsets.all(56),
                pins: [
                  for (var i = 0; i < spots.length; i++)
                    MapPin(
                      id: '${spots[i].$2}-$i',
                      point: spots[i].$1,
                      color: spots[i].$4,
                      pillText: spots[i].$2,
                      onTap: spots[i].$3,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

const _dateMonths = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

String _monthYear(DateTime d) => '${_dateMonths[d.month - 1]} ${d.year}';

/// "What Travelers Say": a sideways row of review cards and a button that
/// opens every review.
class ReviewsCarousel extends StatelessWidget {
  const ReviewsCarousel({super.key, required this.reviews});
  final List<Review> reviews;

  void _openAll(BuildContext context) {
    final s = S.read(context);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        builder: (context, scroll) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      s.whatTravelersSay,
                      style: AppText.sans(19, weight: FontWeight.w800, color: AppColors.sand900),
                    ),
                  ),
                  Text(
                    '${reviews.length}',
                    style: AppText.sans(14, weight: FontWeight.w700, color: regionViolet),
                  ),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: ListView.separated(
                controller: scroll,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                itemCount: reviews.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (_, i) => ReviewCard(review: reviews[i], expanded: true),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    if (reviews.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: OutlinedCard(
          child: Row(
            children: [
              const Icon(Icons.rate_review_outlined, color: regionViolet),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.noReviews,
                      style: AppText.sans(15, weight: FontWeight.w700, color: AppColors.sand900),
                    ),
                    Text(s.beFirst, style: AppText.sans(13, color: AppColors.sand500)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        SizedBox(
          height: 196,
          child: LayoutBuilder(
            // A lone review fills the row; several peek so the row reads as swipeable.
            builder: (context, box) => ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: reviews.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (_, i) => SizedBox(
                width: reviews.length == 1 ? box.maxWidth - 32 : box.maxWidth * 0.78,
                child: ReviewCard(review: reviews[i], onMore: () => _openAll(context)),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GestureDetector(
            onTap: () => _openAll(context),
            child: Container(
              padding: const EdgeInsets.all(1.4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: AppColors.sand200),
                color: Colors.white,
              ),
              child: Container(
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(99)),
                child: Text(
                  '${s.showAllReviews} ${reviews.length} ${reviews.length == 1 ? s.reviewWord : s.reviewsWord}',
                  style: AppText.sans(15, weight: FontWeight.w700, color: AppColors.sand900),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class ReviewCard extends StatelessWidget {
  const ReviewCard({super.key, required this.review, this.onMore, this.expanded = false});
  final Review review;
  final VoidCallback? onMore;

  /// Full text, for the all-reviews sheet.
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final r = review;
    final initials = r.author.split(' ').where((p) => p.isNotEmpty).take(2).map((p) => p[0]).join().toUpperCase();
    final text = r.text ?? '';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.sand200),
      ),
      child: Builder(
        builder: (context) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: expanded ? MainAxisSize.min : MainAxisSize.max,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 23,
                  backgroundColor: AppColors.brand50,
                  child: Text(
                    initials,
                    style: AppText.sans(15, weight: FontWeight.w700, color: regionViolet),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r.author,
                        style: AppText.sans(16, weight: FontWeight.w700, color: AppColors.sand900),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          for (var i = 1; i <= 5; i++)
                            Icon(
                              Icons.star_rounded,
                              size: 16,
                              color: i <= r.rating ? AppColors.star : AppColors.sand200,
                            ),
                          Text('  ·  ', style: AppText.sans(12, color: AppColors.sand400)),
                          Flexible(
                            child: Text(
                              _monthYear(r.createdAt),
                              style: AppText.sans(13, color: AppColors.sand500),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (expanded)
              Text(text, style: AppText.sans(14, color: AppColors.sand600, height: 1.5))
            else ...[
              Text(
                text,
                style: AppText.sans(14, color: AppColors.sand600, height: 1.5),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const Spacer(),
              if (onMore != null)
                GestureDetector(
                  onTap: onMore,
                  child: Text(
                    s.showMore,
                    style: AppText.sans(14, weight: FontWeight.w600, color: regionViolet),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class RegionSectionHeader extends StatelessWidget {
  const RegionSectionHeader({super.key, required this.title, this.onMore});
  final String title;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: AppText.sans(18, weight: FontWeight.w800, color: AppColors.sand900),
            ),
          ),
          if (onMore != null)
            Material(
              color: AppColors.brand50,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onMore,
                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child: Icon(Icons.arrow_forward_rounded, color: regionViolet, size: 18),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Row with a photo, used for the ancient capitals.
class _StoryRow extends StatelessWidget {
  const _StoryRow({required this.story});
  final Story story;

  @override
  Widget build(BuildContext context) {
    final st = story;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: () => context.push(Routes.story(st.region, st.slug)),
        child: OutlinedCard(
          child: Row(
            children: [
              if (st.photos.isNotEmpty)
                AppImage(st.photos.first, width: 64, height: 64, radius: BorderRadius.circular(12)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      st.knownAs != null && st.knownAs != st.name ? '${st.name} ${st.knownAs}' : st.name,
                      style: AppText.sans(15, weight: FontWeight.w700, color: AppColors.sand900),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      st.summary,
                      style: AppText.sans(12.5, color: AppColors.sand500, height: 1.35),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Row for regions without story pages (Peoples of the Northeast, The Water Year…).
class _HighlightRow extends StatelessWidget {
  const _HighlightRow({required this.highlight});
  final RegionHighlight highlight;

  @override
  Widget build(BuildContext context) {
    final h = highlight;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: OutlinedCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: AppColors.brand50, borderRadius: BorderRadius.circular(12)),
              alignment: Alignment.center,
              child: Text(
                '${h.index}',
                style: AppText.sans(16, weight: FontWeight.w800, color: regionViolet),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    h.title,
                    style: AppText.sans(15, weight: FontWeight.w700, color: AppColors.sand900),
                  ),
                  if (h.label != null || h.meta != null)
                    Text(
                      [h.label, h.meta].whereType<String>().join('  ·  '),
                      style: AppText.sans(12, weight: FontWeight.w600, color: AppColors.sunset600),
                    ),
                  const SizedBox(height: 3),
                  Text(h.description, style: AppText.sans(12.5, color: AppColors.sand500, height: 1.35)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LikeCard extends StatelessWidget {
  const LikeCard({super.key, required this.destination});
  final Destination destination;

  @override
  Widget build(BuildContext context) {
    final d = destination;
    final (title, _) = bilingual(context, d.name, d.nameKh);
    return GestureDetector(
      onTap: () => context.push(Routes.destination(d.region, d.slug)),
      child: SizedBox(
        width: 140,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 100,
              width: double.infinity,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    AppImage(d.image),
                    Positioned(
                      right: 4,
                      top: 4,
                      child: SaveButton(kind: SavedKind.destination, itemKey: d.key, dark: true, size: 30),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: AppText.sans(13, weight: FontWeight.w700, color: AppColors.sand900),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(d.province, style: AppText.sans(11.5, color: AppColors.sand500), maxLines: 1),
          ],
        ),
      ),
    );
  }
}
