import 'dart:async';

import 'package:flutter/foundation.dart' show setEquals;
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../data/api/ams_api.dart';
import '../../widgets/async_view.dart';
import '../../widgets/filter_chips.dart';
import '../../widgets/interest_style.dart';

/// What the traveller picked, sent as it is to `GET /search`. Nothing here
/// is ever matched on the phone.
class SearchFilters {
  const SearchFilters({
    this.kind,
    this.regionIds = const {},
    this.provinceIds = const {},
    this.interestIds = const {},
    this.corridorIds = const {},
    this.categoryIds = const {},
    this.tagIds = const {},
  });

  /// `type`: stays, food, corridors, or null for every kind.
  final CardType? kind;

  /// `regionIds`: tourism regions, any of them matches.
  final Set<String> regionIds;

  /// `provinceIds`: provinces, any of them matches.
  final Set<String> provinceIds;

  final Set<String> interestIds;

  /// `corridorIds`: the places along these corridors (R-072).
  final Set<String> corridorIds;
  final Set<String> categoryIds;
  final Set<String> tagIds;

  bool get isEmpty => kind == null && count == 0;

  /// How many picks the Filters sheet holds (the kind has its own chips).
  int get count =>
      regionIds.length +
      provinceIds.length +
      interestIds.length +
      corridorIds.length +
      categoryIds.length +
      tagIds.length;

  /// Only the sheet's picks, keeping the kind.
  SearchFilters cleared() => SearchFilters(kind: kind);

  SearchFilters copyWith({
    CardType? Function()? kind,
    Set<String>? regionIds,
    Set<String>? provinceIds,
    Set<String>? interestIds,
    Set<String>? corridorIds,
    Set<String>? categoryIds,
    Set<String>? tagIds,
  }) => SearchFilters(
    kind: kind == null ? this.kind : kind(),
    regionIds: regionIds ?? this.regionIds,
    provinceIds: provinceIds ?? this.provinceIds,
    interestIds: interestIds ?? this.interestIds,
    corridorIds: corridorIds ?? this.corridorIds,
    categoryIds: categoryIds ?? this.categoryIds,
    tagIds: tagIds ?? this.tagIds,
  );

  /// One page of `GET /search` for these filters and [q].
  Future<PageOf<PlaceCard>> search(AmsApi api, {String? q, int page = 0, int size = 20}) => api.search(
    q: q == null || q.isEmpty ? null : q,
    type: kind,
    regionIds: regionIds.toList(),
    provinceIds: provinceIds.toList(),
    interestIds: interestIds.toList(),
    corridorIds: corridorIds.toList(),
    categoryIds: categoryIds.toList(),
    tagIds: tagIds.toList(),
    page: page,
    size: size,
  );

  @override
  bool operator ==(Object other) =>
      other is SearchFilters &&
      other.kind == kind &&
      setEquals(other.regionIds, regionIds) &&
      setEquals(other.provinceIds, provinceIds) &&
      setEquals(other.interestIds, interestIds) &&
      setEquals(other.corridorIds, corridorIds) &&
      setEquals(other.categoryIds, categoryIds) &&
      setEquals(other.tagIds, tagIds);

  @override
  int get hashCode => Object.hash(
    kind,
    Object.hashAllUnordered(regionIds),
    Object.hashAllUnordered(provinceIds),
    Object.hashAllUnordered(interestIds),
    Object.hashAllUnordered(corridorIds),
    Object.hashAllUnordered(categoryIds),
    Object.hashAllUnordered(tagIds),
  );
}

/// The Filters sheet: tourism regions, provinces, interests and corridors
/// along the top, then the categories and tags that go with those picks, all
/// from the API. Returns the picks, or null when closed.
Future<SearchFilters?> showFilterSheet(BuildContext context, SearchFilters current) =>
    showModalBottomSheet<SearchFilters>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: const Color(0xFFF7F7FA),
      builder: (_) => _FilterSheet(current: current),
    );

/// The picks in [filters] as chips for the results page: each one's name
/// and the filters without it. A whole interest group is one chip ("Stays").
Future<List<(String, SearchFilters)>> appliedFilterChips(AmsApi api, SearchFilters filters) async {
  final c = await _Choices.load(api);
  final chips = <(String, SearchFilters)>[];
  Set<String> less(Set<String> set, Iterable<String> ids) => {...set}..removeAll(ids);

  for (final r in c.regions) {
    if (filters.regionIds.contains(r.id)) {
      chips.add((r.name, filters.copyWith(regionIds: less(filters.regionIds, [r.id]))));
    }
  }
  for (final p in c.provinces) {
    if (filters.provinceIds.contains(p.id)) {
      chips.add((p.name, filters.copyWith(provinceIds: less(filters.provinceIds, [p.id]))));
    }
  }
  var interests = filters.interestIds;
  for (final g in c.groups) {
    final ids = g.interestIds.toSet();
    if (ids.isNotEmpty && interests.containsAll(ids)) {
      // The group with its kind goes as one.
      chips.add((
        (api.khmer ? S.km : S.en).interestGroup(g.name),
        filters.copyWith(interestIds: less(filters.interestIds, ids), kind: () => null),
      ));
      interests = less(interests, ids);
    }
  }
  for (final g in c.groups) {
    for (final i in g.interests) {
      if (interests.contains(i.id)) {
        chips.add((i.name, filters.copyWith(interestIds: less(filters.interestIds, [i.id]))));
      }
    }
  }
  for (final k in c.corridors) {
    if (filters.corridorIds.contains(k.id)) {
      chips.add((k.name, filters.copyWith(corridorIds: less(filters.corridorIds, [k.id]))));
    }
  }
  for (final x in c.categories) {
    if (filters.categoryIds.contains(x.id)) {
      chips.add((x.name, filters.copyWith(categoryIds: less(filters.categoryIds, [x.id]))));
    }
  }
  for (final x in c.tags) {
    if (filters.tagIds.contains(x.id)) chips.add((x.name, filters.copyWith(tagIds: less(filters.tagIds, [x.id]))));
  }
  return chips;
}

/// The chips the sheet offers, from the public reference lists.
class _Choices {
  const _Choices({
    required this.regions,
    required this.provinces,
    required this.groups,
    required this.corridors,
    required this.categories,
    required this.tags,
  });

  final List<CatalogRegion> regions;
  final List<CatalogProvince> provinces;
  final List<InterestGroup> groups;
  final List<PlaceCard> corridors;
  final List<Label> categories;
  final List<Label> tags;

  static Future<_Choices> load(AmsApi api) async {
    final (regions, provinces, groups, corridors, categories, tags) = await (
      api.tourismRegions(),
      api.provinces(),
      api.interestGroups(),
      api.corridors(),
      api.categories(),
      api.tags(),
    ).wait;
    // Display order only: the lists are shared reference data, so sort copies.
    return _Choices(
      regions: [...regions]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder)),
      provinces: [...provinces]..sort((a, b) => a.name.compareTo(b.name)),
      groups: groups,
      corridors: corridors,
      categories: [...categories]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder)),
      tags: [...tags]..sort((a, b) => a.name.compareTo(b.name)),
    );
  }
}

/// The sections of the sheet, as tabs along its top.
enum _Section { regions, provinces, interests, corridors }

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({required this.current});
  final SearchFilters current;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late SearchFilters _filters = widget.current;
  _Section _section = _Section.regions;
  bool _categoriesOpen = true;
  bool _tagsOpen = true;
  bool _allCategories = false;
  bool _allTags = false;

  /// On the Provinces tab: the interest group chosen under the provinces,
  /// and whether its two sections are open.
  int? _group;
  bool _groupFound = false;
  bool _groupsOpen = true;
  bool _groupInterestsOpen = true;

  /// How many places the picks find, asked of the server.
  int? _count;
  Timer? _debounce;
  int _asked = 0;

  @override
  void initState() {
    super.initState();
    _recount();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _set(SearchFilters next) {
    setState(() => _filters = next);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), _recount);
  }

  Future<void> _recount() async {
    if (_filters.count == 0) {
      setState(() => _count = null);
      return;
    }
    final ask = ++_asked;
    try {
      final page = await _filters.search(context.read<AmsApi>(), size: 1);
      if (mounted && ask == _asked) setState(() => _count = page.totalElements);
    } catch (_) {
      if (mounted && ask == _asked) setState(() => _count = null);
    }
  }

  static Set<String> _toggle(Set<String> set, String id) => set.contains(id) ? ({...set}..remove(id)) : {...set, id};

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final api = context.read<AmsApi>();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.92,
      maxChildSize: 0.95,
      builder: (context, scroll) => AsyncView<_Choices>(
        load: () => _Choices.load(api),
        builder: (context, choices, _) {
          // Reopened with a group's interests picked: light that group.
          if (!_groupFound) {
            _groupFound = true;
            final picked = _filters.interestIds;
            final at = choices.groups.indexWhere((g) => picked.isNotEmpty && g.interestIds.toSet().containsAll(picked));
            _group = at < 0 ? null : at;
          }
          // Categories and tags follow the picks along the top.
          final (shownCategories, shownTags) = _following(choices);
          final categories = _allCategories ? shownCategories : shownCategories.take(9).toList();
          final tags = _allTags ? shownTags : shownTags.take(8).toList();

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
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    for (final section in _Section.values)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: PickChip(
                          centred: true,
                          label: switch (section) {
                            _Section.regions => s.tourismRegions,
                            _Section.provinces => s.tabProvinces,
                            _Section.interests => s.tabInterests,
                            _Section.corridors => s.tabCorridors,
                          },
                          selected: _section == section,
                          onTap: () => setState(() => _section = section),
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
                    ..._sectionChips(context, choices),
                    // On Provinces (under the provinces) and on Interests:
                    // the interest groups, then the chosen group's interests.
                    // Corridors is the corridors alone; only Tourism Regions
                    // goes on to categories and tags.
                    if (_section == _Section.provinces || _section == _Section.interests)
                      ..._groupSections(context, choices)
                    else if (_section == _Section.regions) ...[
                      const SizedBox(height: 22),
                      SectionBar(
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
                            for (final c in categories)
                              PickChip(
                                label: c.name,
                                icon: categoryIcons[c.name] ?? Icons.place_outlined,
                                selected: _filters.categoryIds.contains(c.id),
                                onTap: () => _set(_filters.copyWith(categoryIds: _toggle(_filters.categoryIds, c.id))),
                              ),
                            if (shownCategories.length > 9)
                              ViewAllChip(
                                label: s.viewAll,
                                expanded: _allCategories,
                                onTap: () => setState(() => _allCategories = !_allCategories),
                              ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 22),
                      SectionBar(
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
                            for (final t in tags)
                              PickChip(
                                label: t.name,
                                color: tagChipRed,
                                selected: _filters.tagIds.contains(t.id),
                                onTap: () => _set(_filters.copyWith(tagIds: _toggle(_filters.tagIds, t.id))),
                              ),
                            if (shownTags.length > 8)
                              ViewAllChip(
                                label: s.viewAll,
                                color: tagChipRed,
                                expanded: _allTags,
                                onTap: () => setState(() => _allTags = !_allTags),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ],
                ),
              ),
              _Buttons(
                filters: _filters,
                count: _count,
                onReset: () {
                  setState(() => _group = null);
                  _set(_filters.cleared());
                },
                onApply: () => Navigator.pop(context, _filters),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Picks a group, or lets it go when tapped again. A group sends all its
  /// interests until some are picked, and its kind (stays, food,
  /// corridors) as `type`; attraction groups send no type.
  void _pickGroup(_Choices choices, int i) {
    if (_group == i) {
      setState(() => _group = null);
      _set(_filters.copyWith(interestIds: const {}, kind: () => null));
      return;
    }
    final g = choices.groups[i];
    setState(() => _group = i);
    _set(_filters.copyWith(interestIds: g.interestIds.toSet(), kind: () => g.cardType));
  }

  /// The group's interests picked one by one; none picked is the whole group.
  Set<String> _groupPicks(InterestGroup g) {
    final ids = g.interestIds.toSet();
    final picked = _filters.interestIds.intersection(ids);
    return picked.length == ids.length ? const {} : picked;
  }

  void _pickGroupInterest(InterestGroup g, String id) {
    final next = _toggle(_groupPicks(g), id);
    _set(_filters.copyWith(interestIds: next.isEmpty ? g.interestIds.toSet() : next));
  }

  /// The interest groups, then the chosen group's interests (in the Tags
  /// red): the Interests tab, and the Provinces tab under its provinces.
  List<Widget> _groupSections(BuildContext context, _Choices choices) {
    final s = S.of(context);
    final group = _group == null ? null : choices.groups[_group!];
    final picks = group == null ? const <String>{} : _groupPicks(group);
    return [
      if (_section == _Section.provinces) const SizedBox(height: 22),
      SectionBar(
        title: s.tabInterests,
        subtitle: s.filterInterestsSubtitle,
        open: _groupsOpen,
        onToggle: () => setState(() => _groupsOpen = !_groupsOpen),
      ),
      if (_groupsOpen) ...[
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 10,
          children: [
            for (final (i, g) in choices.groups.indexed)
              PickChip(
                label: s.interestGroup(g.name),
                icon: groupStyle(g.name).$1,
                selected: _group == i,
                onTap: () => _pickGroup(choices, i),
              ),
          ],
        ),
      ],
      if (group != null && group.interests.isNotEmpty) ...[
        const SizedBox(height: 22),
        SectionBar(
          title: s.interestGroup(group.name),
          subtitle: s.filterPickAny,
          open: _groupInterestsOpen,
          onToggle: () => setState(() => _groupInterestsOpen = !_groupInterestsOpen),
        ),
        if (_groupInterestsOpen) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 10,
            children: [
              for (final i in group.interests)
                PickChip(
                  label: i.name,
                  icon: interestIcon(i),
                  color: tagChipRed,
                  selected: picks.contains(i.id),
                  onTap: () => _pickGroupInterest(group, i.id),
                ),
            ],
          ),
        ],
      ],
    ];
  }

  /// The categories and tags that go with the picks along the top: with
  /// tourism regions picked, theirs (each region lists its own); otherwise
  /// all of them. Picks already made stay in view.
  // TODO R-073: provinces, interests and corridors carry no categories or
  // tags; once the server answers them for any set of filters, use that.
  (List<Label>, List<Label>) _following(_Choices choices) {
    if (_filters.regionIds.isEmpty) return (choices.categories, choices.tags);
    final picked = [
      for (final r in choices.regions)
        if (_filters.regionIds.contains(r.id)) r,
    ];
    final categoryIds = {for (final r in picked) ...r.categoryIds, ..._filters.categoryIds};
    final tagIds = {for (final r in picked) ...r.tagIds, ..._filters.tagIds};
    return (
      [
        for (final c in choices.categories)
          if (categoryIds.contains(c.id)) c,
      ],
      [
        for (final t in choices.tags)
          if (tagIds.contains(t.id)) t,
      ],
    );
  }

  /// The chips of the tab chosen along the top.
  List<Widget> _sectionChips(BuildContext context, _Choices choices) {
    final s = S.of(context);
    Widget wrap(List<Widget> chips) => Wrap(spacing: 8, runSpacing: 10, children: chips);

    switch (_section) {
      case _Section.regions:
        return [
          _Heading(title: s.tourismRegions, subtitle: s.filterPickAny),
          const SizedBox(height: 12),
          wrap([
            for (final r in choices.regions)
              PickChip(
                label: r.name,
                icon: Icons.landscape_outlined,
                selected: _filters.regionIds.contains(r.id),
                onTap: () => _set(_filters.copyWith(regionIds: _toggle(_filters.regionIds, r.id))),
              ),
          ]),
        ];
      case _Section.provinces:
        return [
          _Heading(title: s.tabProvinces, subtitle: s.filterPickAny),
          const SizedBox(height: 12),
          wrap([
            for (final p in choices.provinces)
              PickChip(
                label: p.name,
                icon: Icons.place_outlined,
                selected: _filters.provinceIds.contains(p.id),
                onTap: () => _set(_filters.copyWith(provinceIds: _toggle(_filters.provinceIds, p.id))),
              ),
          ]),
        ];
      // The group sections below are the whole tab.
      case _Section.interests:
        return const [];
      case _Section.corridors:
        return [
          _Heading(title: s.tabCorridors, subtitle: s.filterPickAny),
          const SizedBox(height: 12),
          wrap([
            for (final c in choices.corridors)
              PickChip(
                label: c.name,
                icon: Icons.route_outlined,
                selected: _filters.corridorIds.contains(c.id),
                onTap: () => _set(_filters.copyWith(corridorIds: _toggle(_filters.corridorIds, c.id))),
              ),
          ]),
        ];
    }
  }
}

/// A section's title, for the tabs that do not fold.
class _Heading extends StatelessWidget {
  const _Heading({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: AppText.sans(17, weight: FontWeight.w700, color: AppColors.sand900),
      ),
      Text(subtitle, style: AppText.sans(12, color: AppColors.sand500)),
    ],
  );
}

/// Reset and Apply, with the server's count of what the picks find.
class _Buttons extends StatelessWidget {
  const _Buttons({required this.filters, required this.count, required this.onReset, required this.onApply});

  final SearchFilters filters;
  final int? count;
  final VoidCallback onReset;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final none = filters.count == 0;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 54),
                  foregroundColor: none ? AppColors.sand400 : tagChipRed,
                  backgroundColor: Colors.white,
                  side: BorderSide(color: none ? AppColors.sand200 : tagChipRed),
                  shape: const StadiumBorder(),
                ),
                onPressed: none ? null : onReset,
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
                onPressed: onApply,
                child: Text(
                  none || count == null ? s.applyFilters : '${s.applyFilters} ($count)',
                  style: AppText.sans(15.5, weight: FontWeight.w700, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
