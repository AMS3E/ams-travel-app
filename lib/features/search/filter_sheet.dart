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

/// A symbol for each category, for the chips in the Categories section.
/// Anything not listed falls back to a map pin.
const _categoryIcons = <String, IconData>{
  'Adventure': Icons.terrain_rounded,
  'Agriculture': Icons.agriculture_rounded,
  'Ancient Cities': Icons.account_balance_rounded,
  'Ancient Roads': Icons.route_rounded,
  'Archaeological Sites': Icons.museum_rounded,
  'Art Gallery': Icons.palette_rounded,
  'Beach': Icons.beach_access_rounded,
  'Bird Sanctuary': Icons.flutter_dash_rounded,
  'Bird Watching': Icons.flutter_dash_rounded,
  'Boat Trip': Icons.directions_boat_rounded,
  'Bridges': Icons.linear_scale_rounded,
  'Camping': Icons.cabin_rounded,
  'Cave': Icons.dark_mode_rounded,
  'City Walk': Icons.directions_walk_rounded,
  'Coffee': Icons.local_cafe_rounded,
  'Community': Icons.groups_rounded,
  'Cooking Class': Icons.soup_kitchen_rounded,
  'Coral': Icons.waves_rounded,
  'Craft': Icons.handyman_rounded,
  'Cruise': Icons.sailing_rounded,
  'Cycling': Icons.pedal_bike_rounded,
  'Diving': Icons.scuba_diving_rounded,
  'Eco Lodge': Icons.cottage_rounded,
  'Farm': Icons.grass_rounded,
  'Fine Dining': Icons.restaurant_rounded,
  'Fishing': Icons.phishing_rounded,
  'Floating Village': Icons.houseboat_rounded,
  'Forest': Icons.forest_rounded,
  'Golf': Icons.golf_course_rounded,
  'Helicopter': Icons.flight_rounded,
  'Homestay': Icons.night_shelter_rounded,
  'Hospitals': Icons.local_hospital_rounded,
  'Indigenous Culture': Icons.diversity_3_rounded,
  'Island': Icons.beach_access_rounded,
  'Local Guide': Icons.tour_rounded,
  'Luxury Hotel': Icons.hotel_rounded,
  'Mangrove': Icons.park_rounded,
  'Michelin': Icons.star_rounded,
  'Mountain': Icons.landscape_rounded,
  'Museums': Icons.museum_rounded,
  'National Park': Icons.park_rounded,
  'Night Market': Icons.storefront_rounded,
  'Photography': Icons.photo_camera_rounded,
  'Private Guide': Icons.person_pin_rounded,
  'Private Island': Icons.holiday_village_rounded,
  'Rice': Icons.rice_bowl_rounded,
  'River Island': Icons.water_rounded,
  'Sacred Mountain': Icons.temple_buddhist_rounded,
  'Seafood': Icons.set_meal_rounded,
  'Shopping': Icons.shopping_bag_rounded,
  'Sky Bar': Icons.local_bar_rounded,
  'Snorkeling': Icons.pool_rounded,
  'Spa': Icons.spa_rounded,
  'Street Food': Icons.lunch_dining_rounded,
  'Sunset': Icons.wb_twilight_rounded,
  'Temples': Icons.temple_buddhist_rounded,
  'Traditional Food': Icons.ramen_dining_rounded,
  'Trekking': Icons.hiking_rounded,
  'VIP Tour': Icons.workspace_premium_rounded,
  'Viewpoint': Icons.visibility_rounded,
  'Village': Icons.holiday_village_rounded,
  'Volcano Lake': Icons.water_drop_rounded,
  'Waterfall': Icons.water_rounded,
  'Wildlife': Icons.pets_rounded,
  'Yacht': Icons.sailing_rounded,
};

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

              // Categories follow the app's own order — the interests, in the
              // order they are listed — so the heritage ones lead rather than
              // whatever happens to come first alphabetically.
              final order = [for (final i in interests) ...i.categories];
              int rank(String c) {
                final at = order.indexOf(c);
                return at < 0 ? order.length : at;
              }

              final categories = places.map((d) => d.category).toSet().toList()
                ..sort((a, b) => rank(a) != rank(b) ? rank(a).compareTo(rank(b)) : a.compareTo(b));

              // Tags lead with the ones most places carry.
              final tagCounts = <String, int>{};
              for (final d in places) {
                for (final t in d.facets.keys) {
                  tagCounts[t] = (tagCounts[t] ?? 0) + 1;
                }
              }
              final tags = tagCounts.keys.toList()
                ..sort((a, b) {
                  final byCount = tagCounts[b]!.compareTo(tagCounts[a]!);
                  return byCount != 0 ? byCount : a.compareTo(b);
                });
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
                                  icon: _categoryIcons[c] ?? Icons.place_outlined,
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
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color color;

  /// Only the scope row stretches its chips, so only it needs the label
  /// pulled back into the middle.
  final bool centred;

  /// A symbol in front of the label, on the category chips.
  final IconData? icon;

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
          // The scope row keeps its plain outline; the category and tag chips
          // are outlined in their own colour.
          border: Border.all(
            color: selected || !centred ? color.withValues(alpha: selected ? 1 : 0.5) : AppColors.sand200,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 15, color: selected ? Colors.white : color),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: AppText.sans(13, weight: FontWeight.w600, color: selected ? Colors.white : AppColors.sand800),
            ),
          ],
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
          color: color,
          borderRadius: BorderRadius.circular(99),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: AppText.sans(13, weight: FontWeight.w600, color: Colors.white),
            ),
            const SizedBox(width: 6),
            Icon(
              expanded ? Icons.remove_circle_rounded : Icons.add_circle_rounded,
              size: 17,
              color: Colors.white,
            ),
          ],
        ),
      ),
    );
  }
}
