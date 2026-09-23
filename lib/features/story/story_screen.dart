import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/models.dart';
import '../../data/repositories/travel_repository.dart';
import '../../widgets/app_image.dart';
import '../../widgets/async_view.dart';
import '../../widgets/common.dart';
import '../../widgets/map_view.dart';
import '../region/region_screen.dart';

/// One step of a region's historical line (Ishanapura → Chaktomuk), laid out
/// like the region page: hero, chips, the story itself, a historical map,
/// traveller reviews, what is nearby and the tags that tie it together.
class StoryScreen extends StatelessWidget {
  const StoryScreen({super.key, required this.region, required this.slug});
  final String region;
  final String slug;

  @override
  Widget build(BuildContext context) {
    final repo = context.read<TravelRepository>();
    return AsyncView<(List<Story>, Region, List<Destination>, List<Review>)>(
      key: ValueKey('$region/$slug'),
      load: () => (
        repo.getStories(region),
        repo.getRegion(region),
        repo.getDestinations(region: region),
        repo.getRegionReviews(region),
      ).wait,
      loading: const Scaffold(body: LoadingView()),
      builder: (context, data, _) {
        final stories = data.$1;
        final story = stories.firstWhere((s) => s.slug == slug, orElse: () => stories.first);
        return _StoryView(
          story: story,
          all: stories,
          region: data.$2,
          places: data.$3,
          reviews: data.$4,
        );
      },
    );
  }
}

class _StoryView extends StatelessWidget {
  const _StoryView({
    required this.story,
    required this.all,
    required this.region,
    required this.places,
    required this.reviews,
  });

  final Story story;
  final List<Story> all;
  final Region region;
  final List<Destination> places;
  final List<Review> reviews;

  /// The places this step points at, or the closest ones when it names none.
  List<Destination> get _nearby {
    final keys = story.relatedDestinations.map((r) => r.key).toSet();
    final related = places.where((d) => keys.contains(d.key)).toList();
    if (related.length >= 3) return related;
    final rest = places.where((d) => !keys.contains(d.key)).toList()
      ..sort(
        (a, b) => _distance(a).compareTo(_distance(b)),
      );
    return [...related, ...rest].take(8).toList();
  }

  double _distance(Destination d) {
    final dx = d.lat - story.lat;
    final dy = d.lng - story.lng;
    return dx * dx + dy * dy;
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final st = story;
    final nearby = _nearby;
    // Stories carry no score of their own, so the stars average the places
    // this step covers. TODO(api): send a rating per story if you have one.
    final rated = nearby.where((d) => d.rating != null).toList();
    final rating = rated.isEmpty ? null : rated.map((d) => d.rating!).reduce((a, b) => a + b) / rated.length;
    // The facets the related places carry become this step's tags.
    final tags = <String>{for (final d in nearby.take(6)) ...d.facets.keys}.take(8).toList();

    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          _Hero(story: st, region: region),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(st.name, style: AppText.display(24)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.verified_rounded, size: 17, color: AppColors.success),
                    const SizedBox(width: 6),
                    Text(s.recommendByTraveler, style: AppText.sans(13.5, color: AppColors.sand600)),
                    const Spacer(),
                    if (rating != null) ...[
                      Stars(rating.round(), size: 15),
                      const SizedBox(width: 5),
                      Text(
                        rating.toStringAsFixed(1),
                        style: AppText.sans(13.5, weight: FontWeight.w700, color: AppColors.sand900),
                      ),
                    ] else
                      Text(
                        '${s.step} ${st.step} ${s.ofWord} ${all.length}',
                        style: AppText.sans(13, weight: FontWeight.w600, color: regionViolet),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    RegionChip(label: st.when, color: regionViolet, onTap: () {}),
                    RegionChip(label: st.period, color: regionViolet, onTap: () {}),
                    if (st.knownAs != null) RegionChip(label: st.knownAs!, color: regionViolet, onTap: () {}),
                    RegionChip(
                      label: region.name,
                      color: regionViolet,
                      onTap: () => context.push(Routes.region(region.slug)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
            child: OutlinedCard(child: _Story(story: st)),
          ),
          RegionSectionHeader(title: s.historicalMap),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: OutlinedCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(st.location, style: AppText.sans(13.5, color: AppColors.sand500)),
                  const SizedBox(height: 12),
                  MapPreview(
                    height: 260,
                    child: AppMap(
                      interactive: false,
                      fitToPins: false,
                      initialCenter: LatLng(st.lat, st.lng),
                      initialZoom: 11,
                      // This step only — the other capitals have their own pages.
                      pins: [MapPin(id: st.slug, point: LatLng(st.lat, st.lng), highlighted: true)],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (reviews.isNotEmpty) ...[
            RegionSectionHeader(title: s.whatTravelersSay),
            ReviewsCarousel(reviews: reviews),
          ],
          if (nearby.isNotEmpty) ...[
            RegionSectionHeader(title: s.recommendNearby),
            SizedBox(
              height: 152,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: nearby.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (_, n) => LikeCard(destination: nearby[n]),
              ),
            ),
          ],
          if (tags.isNotEmpty) ...[
            RegionSectionHeader(title: s.relatedTags),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final t in tags) RegionChip(label: t, color: tagRed, filled: true, onTap: () {}),
                ],
              ),
            ),
          ],
          SizedBox(height: 24 + MediaQuery.paddingOf(context).bottom),
        ],
      ),
      bottomNavigationBar: _ActionBar(story: st, nearby: nearby),
    );
  }

}

/// Swipeable photos with back and share over them, and a counter in the
/// corner — the gallery lives at the top rather than in a strip below.
class _Hero extends StatefulWidget {
  const _Hero({required this.story, required this.region});
  final Story story;
  final Region region;

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

  void _openPhoto(String url) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => GestureDetector(
        onTap: () => Navigator.pop(context),
        child: InteractiveViewer(
          child: Center(child: AppImage(url.replaceAll('w=1000', 'w=1600'), fit: BoxFit.contain)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final story = widget.story;
    final photos = story.photos.isNotEmpty ? story.photos : [widget.region.image];

    return SizedBox(
      height: 320,
      child: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: photos.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (_, i) => GestureDetector(
              onTap: () => _openPhoto(photos[i]),
              child: AppImage(photos[i]),
            ),
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
                GlassIconButton(
                  icon: Icons.ios_share_rounded,
                  tooltip: s.share,
                  onPressed: () => SharePlus.instance.share(
                    ShareParams(
                      text:
                          '${story.name} — ${story.summary}\nhttps://ams-travel.netlify.app/regions/${story.region}/stories/${story.slug}',
                    ),
                  ),
                ),
              ],
            ),
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
    );
  }
}

/// The quote, the summary and the body, folded until "Read more".
class _Story extends StatefulWidget {
  const _Story({required this.story});
  final Story story;

  @override
  State<_Story> createState() => _StoryState();
}

class _StoryState extends State<_Story> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final st = widget.story;
    final body = [st.summary, ...st.body];
    final shown = _expanded ? body : body.take(2).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '“${st.quote}”',
          style: AppText.sans(15.5, weight: FontWeight.w600, color: AppColors.brand800, height: 1.5),
        ),
        const SizedBox(height: 12),
        for (final para in shown)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              para,
              style: AppText.sans(14.5, color: AppColors.sand700, height: 1.6),
              maxLines: _expanded ? null : 4,
              overflow: _expanded ? TextOverflow.clip : TextOverflow.ellipsis,
            ),
          ),
        if (body.length > 2)
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Text(
              _expanded ? s.showLess : s.readMore,
              style: AppText.sans(14, weight: FontWeight.w700, color: regionViolet),
            ),
          ),
      ],
    );
  }
}

/// Write a review (on one of the places this step covers) and open the map.
class _ActionBar extends StatelessWidget {
  const _ActionBar({required this.story, required this.nearby});
  final Story story;
  final List<Destination> nearby;

  /// Reviews belong to a place, so this writes about the place this step
  /// covers first.
  void _review(BuildContext context) {
    if (nearby.isEmpty) return;
    final place = nearby.first;
    context.push(Routes.review(place.region, place.slug));
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.paddingOf(context).bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.sand200)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.white,
                minimumSize: const Size(0, 48),
                side: const BorderSide(color: AppColors.sand200),
              ),
              onPressed: nearby.isEmpty ? null : () => _review(context),
              icon: const Icon(Icons.rate_review_outlined, size: 18),
              label: FittedBox(child: Text(s.writeReview)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: regionViolet,
                minimumSize: const Size(0, 48),
              ),
              onPressed: () => launchUrl(
                Uri.parse('https://www.google.com/maps/search/?api=1&query=${story.lat},${story.lng}'),
                mode: LaunchMode.externalApplication,
              ),
              icon: const Icon(Icons.map_outlined, size: 18),
              label: FittedBox(child: Text(s.viewOnMap)),
            ),
          ),
        ],
      ),
    );
  }
}
