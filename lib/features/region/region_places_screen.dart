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
import '../../widgets/filter_chips.dart';

/// One tourism region: what it is, where its places are, and all of them.
class RegionPlacesScreen extends StatelessWidget {
  const RegionPlacesScreen({super.key, required this.slug});
  final String slug;

  @override
  Widget build(BuildContext context) {
    final repo = context.read<TravelRepository>();
    return Scaffold(
      body: AsyncView<(Region, List<Destination>)>(
        load: () => (repo.getRegion(slug), repo.getDestinations(region: slug)).wait,
        loading: const Scaffold(body: LoadingView()),
        builder: (context, data, _) {
          final (region, places) = data;
          return _Body(region: region, places: places);
        },
      ),
    );
  }
}

class _Body extends StatefulWidget {
  const _Body({required this.region, required this.places});
  final Region region;
  final List<Destination> places;

  @override
  State<_Body> createState() => _BodyState();
}

class _BodyState extends State<_Body> {
  bool _categoriesOpen = true;
  bool _tagsOpen = true;
  bool _allCategories = false;
  bool _allTags = false;

  @override
  Widget build(BuildContext context) {
    final region = widget.region;
    final places = widget.places;
    final s = S.of(context);
    final name = bilingual(context, region.name, region.nameKh).$1;
    final categories = places.map((d) => d.category).toSet().toList()..sort();
    final tags = <String>{for (final d in places) ...d.facets.keys}.toList()..sort();

    return ListView(
      padding: EdgeInsets.only(bottom: 28 + MediaQuery.paddingOf(context).bottom),
      children: [
        _Hero(region: region),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Text(
            name,
            style: AppText.sans(22, weight: FontWeight.w700, color: AppColors.sand900, height: 1.25),
          ),
        ),

        _Card(
          title: s.overview,
          child: _Overview(text: '${region.summary} ${region.coreIdentity}'),
        ),

        _Card(
          title: s.historicalMap,
          subtitle: s.historicalMapSubtitle,
          child: const _PlacesMap(),
        ),

        // What kinds of place the region holds, and what they are known for.
        _Card(
          title: s.categories,
          subtitle: s.discoverDestination,
          onToggle: () => setState(() => _categoriesOpen = !_categoriesOpen),
          open: _categoriesOpen,
          child: _Chips(
            words: categories,
            shown: _allCategories ? categories.length : 7,
            colour: AppColors.violet,
            withIcons: true,
            expanded: _allCategories,
            onViewAll: () => setState(() => _allCategories = !_allCategories),
          ),
        ),
        _Card(
          title: s.tags,
          subtitle: s.popularKeywords,
          onToggle: () => setState(() => _tagsOpen = !_tagsOpen),
          open: _tagsOpen,
          child: _Chips(
            words: tags,
            shown: _allTags ? tags.length : 6,
            colour: tagChipRed,
            withIcons: false,
            expanded: _allTags,
            onViewAll: () => setState(() => _allTags = !_allTags),
          ),
        ),

        // Everything in the region, two to a row.
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
          child: Text(
            name,
            style: AppText.sans(16.5, weight: FontWeight.w700, color: AppColors.sand900),
            maxLines: 2,
          ),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 14,
            mainAxisExtent: 182,
          ),
          itemCount: places.length,
          itemBuilder: (_, i) => _PlaceCard(destination: places[i]),
        ),

      ],
    );
  }
}

/// The map of Cambodia, as a picture.
///
/// TODO(api): `assets/images/cambodia_map.jpg` stands in until the backend
/// serves a map image per region.
class _PlacesMap extends StatelessWidget {
  const _PlacesMap();

  /// The picture's own proportions, so it is not stretched.
  static const _aspect = 1400 / 1182;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: _aspect,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.asset('assets/images/cambodia_map.jpg', fit: BoxFit.fill),
      ),
    );
  }
}

/// The region's photo, with the way back and the usual buttons.
class _Hero extends StatelessWidget {
  const _Hero({required this.region});
  final Region region;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Stack(
      children: [
        SizedBox(
          height: 340,
          width: double.infinity,
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
            child: AppImage(region.image),
          ),
        ),
        Positioned(
          left: 10,
          right: 10,
          top: MediaQuery.paddingOf(context).top + 4,
          child: Row(
            children: [
              GlassIconButton(
                icon: Icons.chevron_left_rounded,
                tooltip: s.back,
                onPressed: () => context.pop(),
              ),
              const Spacer(),
              SaveButton(kind: SavedKind.region, itemKey: region.slug, dark: true, size: 40),
              const SizedBox(width: 8),
              GlassIconButton(
                icon: Icons.ios_share_rounded,
                tooltip: s.share,
                onPressed: () => SharePlus.instance.share(
                  ShareParams(text: '${region.name} — ${region.tagline}'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The region in a few lines, folded until "Read more".
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.text,
          style: AppText.sans(14, color: AppColors.sand700, height: 1.6),
          maxLines: _open ? null : 4,
          overflow: _open ? TextOverflow.visible : TextOverflow.ellipsis,
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: () => setState(() => _open = !_open),
          child: Text(
            _open ? s.readLess : s.readMore,
            style: AppText.sans(13, weight: FontWeight.w700, color: AppColors.violet),
          ),
        ),
      ],
    );
  }
}

/// Photo with a heart, then the name and what travellers make of it.
class _PlaceCard extends StatelessWidget {
  const _PlaceCard({required this.destination});
  final Destination destination;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final d = destination;
    final (title, _) = bilingual(context, d.name, d.nameKh);
    return GestureDetector(
      onTap: () => context.push(Routes.destination(d.region, d.slug)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  AppImage(d.image),
                  Positioned(
                    right: 4,
                    top: 4,
                    child: SaveButton(kind: SavedKind.destination, itemKey: d.key, size: 30),
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
    );
  }
}

/// White panel with a heading — the overview and the map sit in one.
class _Card extends StatelessWidget {
  const _Card({required this.title, this.subtitle, required this.child, this.onToggle, this.open = true});
  final String title;
  final String? subtitle;
  final Widget child;

  /// Sections that fold carry a chevron; the rest do not.
  final VoidCallback? onToggle;
  final bool open;

  @override
  Widget build(BuildContext context) {
    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppText.sans(16, weight: FontWeight.w700, color: AppColors.sand900)),
        if (subtitle != null) ...[
          const SizedBox(height: 3),
          Text(subtitle!, style: AppText.sans(12.5, color: AppColors.sand500)),
        ],
      ],
    );

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.sand200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (onToggle == null)
            heading
          else
            InkWell(
              onTap: onToggle,
              child: Row(
                children: [
                  Expanded(child: heading),
                  Icon(
                    open ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    color: AppColors.violet,
                  ),
                ],
              ),
            ),
          if (open) ...[
            const SizedBox(height: 12),
            child,
          ],
        ],
      ),
    );
  }
}

/// A wrap of chips with a View All at the end.
class _Chips extends StatelessWidget {
  const _Chips({
    required this.words,
    required this.shown,
    required this.colour,
    required this.withIcons,
    required this.expanded,
    required this.onViewAll,
  });

  final List<String> words;
  final int shown;
  final Color colour;
  final bool withIcons;
  final bool expanded;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Wrap(
      spacing: 8,
      runSpacing: 10,
      children: [
        for (final w in words.take(shown))
          PickChip(
            label: w,
            icon: withIcons ? (categoryIcons[w] ?? Icons.place_outlined) : null,
            color: colour,
            selected: false,
            onTap: () => context.push('${Routes.search}?q=${Uri.encodeQueryComponent(w)}'),
          ),
        if (words.length > shown || expanded)
          ViewAllChip(label: s.viewAll, color: colour, expanded: expanded, onTap: onViewAll),
      ],
    );
  }
}
