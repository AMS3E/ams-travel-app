import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/geo.dart';
import '../../data/models/models.dart';
import '../../data/repositories/travel_repository.dart';
import '../../widgets/app_image.dart';
import '../../widgets/async_view.dart';
import '../../widgets/destination_card.dart';

const _tagRed = Color(0xFFE23E57);

/// Which list the thumbnails at the top of the sheet come from.
enum FilterScope { all, regions, provinces, interests, corridors }

/// What the traveller picked in the Filters sheet.
class SearchFilters {
  const SearchFilters({
    this.scope = FilterScope.all,
    this.items = const {},
    this.categories = const {},
    this.tags = const {},
  });

  final FilterScope scope;

  /// Slugs picked from the thumbnail row, within [scope].
  final Set<String> items;

  /// Destination categories (Temples, Museums…).
  final Set<String> categories;

  /// Facet keys a place must carry (Century, King, UNESCO…).
  final Set<String> tags;

  bool get isEmpty => items.isEmpty && categories.isEmpty && tags.isEmpty;
  int get count => items.length + categories.length + tags.length;

  /// Places matching everything picked.
  List<Destination> apply(
    List<Destination> places, {
    required List<Interest> interests,
    required List<Corridor> corridors,
  }) {
    return places.where((d) {
      if (categories.isNotEmpty && !categories.contains(d.category)) return false;
      for (final tag in tags) {
        if (!d.facets.containsKey(tag)) return false;
      }
      if (items.isEmpty) return true;
      return switch (scope) {
        FilterScope.all => true,
        FilterScope.regions => items.contains(d.region),
        FilterScope.provinces => items.contains(slugify(d.province)),
        FilterScope.interests =>
          interests.where((i) => items.contains(i.slug)).any((i) => i.categories.contains(d.category)),
        FilterScope.corridors =>
          corridors
              .where((c) => items.contains(c.slug))
              .any((c) => c.stops.any((st) => distanceKm(st.lat, st.lng, d.lat, d.lng) <= 35)),
      };
    }).toList();
  }

  SearchFilters copyWith({FilterScope? scope, Set<String>? items, Set<String>? categories, Set<String>? tags}) =>
      SearchFilters(
        scope: scope ?? this.scope,
        items: items ?? this.items,
        categories: categories ?? this.categories,
        tags: tags ?? this.tags,
      );
}

/// The Filters sheet: scope chips, a thumbnail row, categories and tags.
Future<SearchFilters?> showFilterSheet(BuildContext context, SearchFilters current) =>
    showModalBottomSheet<SearchFilters>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: const Color(0xFFF7F7FA),
      builder: (_) => _FilterSheet(current: current),
    );

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({required this.current});
  final SearchFilters current;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late SearchFilters _filters = widget.current;
  bool _categoriesOpen = true;
  bool _tagsOpen = true;
  bool _allCategories = false;
  bool _allTags = false;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final repo = context.read<TravelRepository>();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.92,
      maxChildSize: 0.95,
      builder: (context, scroll) =>
          AsyncView<(List<Region>, List<Province>, List<Interest>, List<Corridor>, List<Destination>)>(
            load: () => (
              repo.getRegions(),
              repo.getProvinces(),
              repo.getInterests(),
              repo.getCorridors(),
              repo.getDestinations(),
            ).wait,
            builder: (context, data, _) {
              final (regions, provinces, interests, corridors, places) = data;

              // Thumbnails for the chosen scope.
              final thumbs = switch (_filters.scope) {
                FilterScope.all || FilterScope.regions => [
                  for (final r in regions) (r.slug, bilingual(context, r.name, r.nameKh).$1, r.image),
                ],
                FilterScope.provinces => [
                  for (final p in provinces) (p.slug, bilingual(context, p.name, p.nameKh).$1, p.image),
                ],
                FilterScope.interests => [for (final i in interests) (i.slug, i.name, i.image)],
                FilterScope.corridors => [for (final c in corridors) (c.slug, c.name, c.image)],
              };

              final categories = places.map((d) => d.category).toSet().toList()..sort();
              final tags = <String>{for (final d in places) ...d.facets.keys}.toList()..sort();
              final shownCategories = _allCategories ? categories : categories.take(7).toList();
              final shownTags = _allTags ? tags : tags.take(6).toList();
              final matches = _filters.apply(places, interests: interests, corridors: corridors);

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 8, 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            s.filters,
                            style: AppText.sans(22, weight: FontWeight.w800, color: AppColors.sand900),
                          ),
                        ),
                        IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 44,
                    child: ListView(
                      controller: null,
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      children: [
                        for (final scope in FilterScope.values)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: _Chip(
                              centred: true,
                              label: switch (scope) {
                                FilterScope.all => s.all,
                                FilterScope.regions => s.tourismRegions,
                                FilterScope.provinces => s.tabProvinces,
                                FilterScope.interests => s.tabInterests,
                                FilterScope.corridors => s.tabCorridors,
                              },
                              selected: _filters.scope == scope,
                              onTap: () => setState(() => _filters = _filters.copyWith(scope: scope, items: {})),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      controller: scroll,
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                      children: [
                        SizedBox(
                          height: 62,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: thumbs.length,
                            separatorBuilder: (_, _) => const SizedBox(width: 10),
                            itemBuilder: (_, i) {
                              final (slug, name, image) = thumbs[i];
                              final selected = _filters.items.contains(slug);
                              return Tooltip(
                                message: name,
                                child: GestureDetector(
                                  onTap: () => setState(() {
                                    final next = {..._filters.items};
                                    next.contains(slug) ? next.remove(slug) : next.add(slug);
                                    _filters = _filters.copyWith(items: next);
                                  }),
                                  child: Stack(
                                    children: [
                                      Container(
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(14),
                                          border: Border.all(
                                            color: selected ? AppColors.violet : Colors.transparent,
                                            width: 2.4,
                                          ),
                                        ),
                                        child: AppImage(
                                          image,
                                          width: 62,
                                          height: 62,
                                          radius: BorderRadius.circular(12),
                                        ),
                                      ),
                                      if (selected)
                                        const Positioned(
                                          right: 2,
                                          top: 2,
                                          child: CircleAvatar(
                                            radius: 9,
                                            backgroundColor: AppColors.violet,
                                            child: Icon(Icons.check_rounded, size: 12, color: Colors.white),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 22),
                        _SectionBar(
                          title: s.categories,
                          subtitle: s.discoverDestination,
                          open: _categoriesOpen,
                          onToggle: () => setState(() => _categoriesOpen = !_categoriesOpen),
                        ),
                        if (_categoriesOpen) ...[
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 10,
                            children: [
                              for (final c in shownCategories)
                                _Chip(
                                  label: c,
                                  selected: _filters.categories.contains(c),
                                  onTap: () => setState(() {
                                    final next = {..._filters.categories};
                                    next.contains(c) ? next.remove(c) : next.add(c);
                                    _filters = _filters.copyWith(categories: next);
                                  }),
                                ),
                              if (categories.length > 7)
                                _ViewAllChip(
                                  label: s.viewAll,
                                  expanded: _allCategories,
                                  onTap: () => setState(() => _allCategories = !_allCategories),
                                ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 22),
                        _SectionBar(
                          title: s.tags,
                          subtitle: s.popularKeywords,
                          open: _tagsOpen,
                          onToggle: () => setState(() => _tagsOpen = !_tagsOpen),
                        ),
                        if (_tagsOpen) ...[
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 10,
                            children: [
                              for (final t in shownTags)
                                _Chip(
                                  label: t,
                                  color: _tagRed,
                                  selected: _filters.tags.contains(t),
                                  onTap: () => setState(() {
                                    final next = {..._filters.tags};
                                    next.contains(t) ? next.remove(t) : next.add(t);
                                    _filters = _filters.copyWith(tags: next);
                                  }),
                                ),
                              if (tags.length > 6)
                                _ViewAllChip(
                                  label: s.viewAll,
                                  color: _tagRed,
                                  expanded: _allTags,
                                  onTap: () => setState(() => _allTags = !_allTags),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(0, 54),
                                foregroundColor: _filters.isEmpty ? AppColors.sand400 : _tagRed,
                                backgroundColor: Colors.white,
                                side: BorderSide(color: _filters.isEmpty ? AppColors.sand200 : _tagRed),
                                shape: const StadiumBorder(),
                              ),
                              onPressed: _filters.isEmpty
                                  ? null
                                  : () => setState(() => _filters = const SearchFilters()),
                              child: Text(s.reset, style: AppText.sans(15.5, weight: FontWeight.w700)),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            flex: 2,
                            child: FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.violet,
                                minimumSize: const Size(0, 54),
                                shape: const StadiumBorder(),
                              ),
                              onPressed: () => Navigator.pop(context, _filters),
                              child: Text(
                                _filters.isEmpty ? s.applyFilters : '${s.applyFilters} (${matches.length})',
                                style: AppText.sans(15.5, weight: FontWeight.w700, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
    );
  }
}

class _SectionBar extends StatelessWidget {
  const _SectionBar({required this.title, required this.subtitle, required this.open, required this.onToggle});
  final String title;
  final String subtitle;
  final bool open;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onToggle,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppText.sans(17, weight: FontWeight.w700, color: AppColors.sand900),
                ),
                Text(subtitle, style: AppText.sans(12, color: AppColors.sand500)),
              ],
            ),
          ),
          Icon(open ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, color: AppColors.sand500),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color = AppColors.violet,
    this.centred = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color color;

  /// Only the scope row stretches its chips, so only it needs the label
  /// pulled back into the middle.
  final bool centred;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        alignment: centred ? Alignment.center : null,
        decoration: BoxDecoration(
          color: selected ? color : Colors.white,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: selected ? color : AppColors.sand200),
        ),
        child: Text(
          label,
          style: AppText.sans(13, weight: FontWeight.w600, color: selected ? Colors.white : AppColors.sand800),
        ),
      ),
    );
  }
}

class _ViewAllChip extends StatelessWidget {
  const _ViewAllChip({required this.label, required this.expanded, required this.onTap, this.color = AppColors.violet});
  final String label;
  final bool expanded;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 8, 10, 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: AppText.sans(13, weight: FontWeight.w600, color: color),
            ),
            const SizedBox(width: 6),
            Icon(
              expanded ? Icons.remove_circle_outline_rounded : Icons.add_circle_outline_rounded,
              size: 17,
              color: color,
            ),
          ],
        ),
      ),
    );
  }
}
