import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../data/api/ams_api.dart';
import '../../state/collections_provider.dart';
import '../../widgets/app_image.dart';
import '../../widgets/async_view.dart';
import '../../widgets/common.dart';
import '../../widgets/overview_card.dart';
import '../../widgets/hero_app_bar.dart';
import '../../widgets/destination_card.dart';
import '../../widgets/filter_chips.dart';
import '../destination/place_view.dart';
import '../interest/browse_helpers.dart';

/// What the region page reads once: the region, the category and tag labels
/// for its chips, and the first page of its places.
class _RegionData {
  const _RegionData({required this.region, required this.categories, required this.tags, required this.places});

  final CatalogRegion region;
  final List<Label> categories;
  final List<Label> tags;
  final PageOf<PlaceCard> places;
}

/// One tourism region: what it is, its map, and all of its places.
/// The category and tag chips narrow the list on the server.
class RegionPlacesScreen extends StatelessWidget {
  const RegionPlacesScreen({super.key, required this.id});
  final String id;

  Future<_RegionData> _load(AmsApi api) async {
    final (region, categories, tags, places) = await (
      api.region(id),
      api.categories(),
      api.tags(),
      api.search(regionId: id, size: _pageSize),
    ).wait;
    // The chips are the region's own categories and tags, in its order.
    final byCategory = {for (final c in categories) c.id: c};
    final byTag = {for (final t in tags) t.id: t};
    return _RegionData(
      region: region,
      categories: [for (final i in region.categoryIds) ?byCategory[i]],
      tags: [for (final i in region.tagIds) ?byTag[i]],
      places: places,
    );
  }

  @override
  Widget build(BuildContext context) {
    final api = context.read<AmsApi>();
    return Scaffold(
      body: AsyncView<_RegionData>(
        load: () => _load(api),
        builder: (context, data, _) => _Body(data: data),
      ),
    );
  }
}

/// Places per page of the region's list.
const _pageSize = 20;

class _Body extends StatefulWidget {
  const _Body({required this.data});
  final _RegionData data;

  @override
  State<_Body> createState() => _BodyState();
}

class _BodyState extends State<_Body> {
  bool _categoriesOpen = true;
  bool _tagsOpen = true;
  bool _allCategories = false;
  bool _allTags = false;

  /// Ids of the chips that are on; sent to `GET /search`. Empty means all.
  final _pickedCategories = <String>{};
  final _pickedTags = <String>{};

  void _pick(Set<String> into, String id) => setState(() => into.remove(id) ? null : into.add(id));

  bool get _filtered => _pickedCategories.isNotEmpty || _pickedTags.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final api = context.read<AmsApi>();
    final data = widget.data;
    final region = data.region;
    final s = S.of(context);
    final categories = (_pickedCategories.toList()..sort()).join(',');
    final tags = (_pickedTags.toList()..sort()).join(',');

    return CustomScrollView(
      slivers: [
        _Hero(region: region),
        SliverPadding(
          padding: EdgeInsets.only(bottom: bottomInset(context)),
          sliver: SliverList.list(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Text(
                  region.name,
                  style: AppText.sans(22, weight: FontWeight.w700, color: AppColors.sand900, height: 1.25),
                ),
              ),
              // The AMS seal, under the name as on a place's page.
              if (region.amsRecommended)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: Row(
                    children: [
                      const Icon(Icons.verified_rounded, size: 19, color: AppColors.seal),
                      const SizedBox(width: 7),
                      Flexible(
                        child: Text(
                          s.recommendByAms,
                          style: AppText.sans(14, color: AppColors.sand700),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),

              DescriptionCard(long: region.description),

              // One picture staff set for the region; no panel until there is one.
              if (region.mapUrl.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                  child: GradientCard(
                    title: s.regionMap,
                    subtitle: s.regionMapSubtitle,
                    child: _MapPicture(url: region.mapUrl),
                  ),
                ),

              if (data.categories.isNotEmpty)
                _Card(
                  title: s.categories,
                  subtitle: s.discoverDestination,
                  onToggle: () => setState(() => _categoriesOpen = !_categoriesOpen),
                  open: _categoriesOpen,
                  child: _Chips(
                    labels: data.categories,
                    shown: _allCategories ? data.categories.length : 7,
                    colour: AppColors.violet,
                    withIcons: true,
                    expanded: _allCategories,
                    onViewAll: () => setState(() => _allCategories = !_allCategories),
                    picked: _pickedCategories,
                    onPick: (id) => _pick(_pickedCategories, id),
                  ),
                ),
              if (data.tags.isNotEmpty)
                _Card(
                  title: s.tags,
                  subtitle: s.popularKeywords,
                  onToggle: () => setState(() => _tagsOpen = !_tagsOpen),
                  open: _tagsOpen,
                  child: _Chips(
                    labels: data.tags,
                    shown: _allTags ? data.tags.length : 6,
                    colour: tagChipRed,
                    withIcons: false,
                    expanded: _allTags,
                    onViewAll: () => setState(() => _allTags = !_allTags),
                    picked: _pickedTags,
                    onPick: (id) => _pick(_pickedTags, id),
                  ),
                ),

              // What the region holds, as the server finds it for the chips above.
              PagedCards(
                key: ValueKey('$categories|$tags'),
                initial: _filtered ? null : data.places,
                load: (page) => api.search(
                  regionId: region.id,
                  categoryIds: _pickedCategories.toList(),
                  tagIds: _pickedTags.toList(),
                  page: page,
                  // The same page size as the first call, whose answer is the
                  // first page of the unfiltered list.
                  size: _pageSize,
                ),
                empty: Column(
                  children: [
                    _ListHeader(count: _filtered ? 0 : null, onReset: _reset),
                    EmptyState(icon: Icons.search_off_rounded, title: s.noResults, body: s.noResultsBody),
                  ],
                ),
                builder: (context, cards, total, more) => Column(
                  children: [
                    _ListHeader(count: _filtered ? total : null, onReset: _reset),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 14,
                        mainAxisExtent: 214,
                      ),
                      itemCount: cards.length,
                      itemBuilder: (_, i) => _PlaceCard(card: cards[i]),
                    ),
                    ?more,
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _reset() => setState(() {
    _pickedCategories.clear();
    _pickedTags.clear();
  });
}

/// The region's name over its list, with the server's count and a reset
/// while chips are on.
class _ListHeader extends StatelessWidget {
  const _ListHeader({required this.count, required this.onReset});

  /// Null when no chip is on: then only a gap, as the region's name is
  /// already at the top of the page.
  final int? count;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    if (count == null) return const SizedBox(height: 24);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 14, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(s.placeCountText(count!), style: AppText.sans(14, color: AppColors.sand500)),
          ),
          InkWell(
            borderRadius: BorderRadius.circular(99),
            onTap: onReset,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Text(
                s.reset,
                style: AppText.sans(13.5, weight: FontWeight.w600, color: AppColors.violet),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The region's banner, under the way back and the usual buttons, which stay
/// pinned at the top.
class _Hero extends StatelessWidget {
  const _Hero({required this.region});
  final CatalogRegion region;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return HeroAppBar(
      height: 340,
      actions: [
        SaveButton(kind: SavedKind.region, itemKey: region.id, size: 44),
        GlassIconButton(
          icon: Icons.ios_share_rounded,
          tooltip: s.share,
          onPressed: () => SharePlus.instance.share(ShareParams(text: region.name)),
        ),
      ],
      background: ClipRRect(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
        child: AppImage(region.coverUrl),
      ),
    );
  }
}

/// The region's map picture, whole; a tap opens it full screen to zoom.
class _MapPicture extends StatelessWidget {
  const _MapPicture({required this.url});
  final String url;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white),
          body: InteractiveViewer(
            maxScale: 5,
            child: Center(child: AppImage(url, fit: BoxFit.contain)),
          ),
        ),
      ),
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: AspectRatio(
        aspectRatio: 4 / 3,
        child: AppImage(url, fit: BoxFit.contain),
      ),
    ),
  );
}

/// Photo with a heart, then the name, its score and reviews, and its seal.
class _PlaceCard extends StatelessWidget {
  const _PlaceCard({required this.card});
  final PlaceCard card;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final d = card;
    final seal = s.seal(traveler: d.travelerRecommended, verified: d.verified);
    final rated = d.averageRating != null && d.reviewCount > 0;
    return GestureDetector(
      onTap: () => context.push(Routes.card(d)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  AppImage(d.coverUrl),
                  Positioned(
                    right: 4,
                    top: 4,
                    child: SaveButton(kind: SavedKind.of(d.type), itemKey: d.id, size: 30),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            d.name,
            style: AppText.sans(13.5, weight: FontWeight.w700, color: AppColors.sand900),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          // Every card has its score, none yet included; a seal follows it.
          Row(
            children: [
              Icon(Icons.star_rounded, size: 15, color: rated ? AppColors.star : AppColors.sand300),
              const SizedBox(width: 3),
              Text(
                (d.averageRating ?? 0).toStringAsFixed(1),
                style: AppText.sans(12.5, weight: FontWeight.w700, color: AppColors.sand900),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  s.reviewCountText(d.reviewCount),
                  style: AppText.sans(11.5, color: AppColors.sand500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (seal != null) ...[
                const SizedBox(width: 4),
                Tooltip(
                  message: seal,
                  child: const Icon(Icons.verified_rounded, size: 13, color: AppColors.sealOnPhoto),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// A heading and what goes under it, straight on the page (categories, tags).
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
        Text(
          title,
          style: AppText.sans(16, weight: FontWeight.w700, color: AppColors.sand900),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 3),
          Text(subtitle!, style: AppText.sans(12.5, color: AppColors.sand500)),
        ],
      ],
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
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
          if (open) ...[const SizedBox(height: 12), child],
        ],
      ),
    );
  }
}

/// A wrap of chips with a View All at the end.
class _Chips extends StatelessWidget {
  const _Chips({
    required this.labels,
    required this.shown,
    required this.colour,
    required this.withIcons,
    required this.expanded,
    required this.onViewAll,
    required this.picked,
    required this.onPick,
  });

  final List<Label> labels;
  final int shown;
  final Color colour;
  final bool withIcons;
  final bool expanded;
  final VoidCallback onViewAll;

  /// Ids of the chips that are on, and what to do when one is tapped.
  final Set<String> picked;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Wrap(
      spacing: 8,
      runSpacing: 10,
      children: [
        for (final l in labels.take(shown))
          PickChip(
            label: l.name,
            icon: withIcons ? (categoryIcons[l.name] ?? Icons.place_outlined) : null,
            color: colour,
            selected: picked.contains(l.id),
            onTap: () => onPick(l.id),
          ),
        if (labels.length > shown || expanded)
          ViewAllChip(label: s.viewAll, color: colour, expanded: expanded, onTap: onViewAll),
      ],
    );
  }
}
