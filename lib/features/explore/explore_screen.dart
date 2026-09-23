import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

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
import '../../widgets/interest_card.dart';

const _tabs = ['regions', 'interests', 'provinces', 'corridors'];

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key, this.tab});

  /// One of regions / interests / provinces / corridors (from `?tab=`).
  final String? tab;

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(
    length: _tabs.length,
    vsync: this,
    initialIndex: _indexOf(widget.tab),
  );

  static int _indexOf(String? tab) => tab == null ? 0 : _tabs.indexOf(tab).clamp(0, _tabs.length - 1);

  @override
  void didUpdateWidget(ExploreScreen old) {
    super.didUpdateWidget(old);
    if (widget.tab != old.tab && widget.tab != null) _tabController.animateTo(_indexOf(widget.tab));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(s.exploreTitle, style: AppText.display(24)),
        actions: [
          IconButton(
            onPressed: () => context.push(Routes.search),
            icon: const Icon(Icons.search_rounded),
            tooltip: s.searchTitle,
          ),
          const SizedBox(width: 6),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          tabs: [
            Tab(text: s.tabRegions),
            Tab(text: s.tabInterests),
            Tab(text: s.tabProvinces),
            Tab(text: s.tabCorridors),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [_RegionsTab(), _InterestsTab(), _ProvincesTab(), _CorridorsTab()],
      ),
    );
  }
}

class _Intro extends StatelessWidget {
  const _Intro(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
    child: Text(text, style: AppText.sans(14.5, color: AppColors.sand600, height: 1.5)),
  );
}

// ---------------------------------------------------------------- Regions

class _RegionsTab extends StatelessWidget {
  const _RegionsTab();

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return AsyncView<List<Region>>(
      load: context.read<TravelRepository>().getRegions,
      builder: (context, regions, _) => ListView.separated(
        padding: EdgeInsets.only(bottom: 32 + MediaQuery.paddingOf(context).bottom),
        itemCount: regions.length + 1,
        separatorBuilder: (_, i) => SizedBox(height: i == 0 ? 0 : 14),
        itemBuilder: (_, i) => i == 0
            ? _Intro(s.introRegions)
            : Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: RegionListCard(region: regions[i - 1]),
              ),
      ),
    );
  }
}

class RegionListCard extends StatelessWidget {
  const RegionListCard({super.key, required this.region});
  final Region region;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final (title, subtitle) = bilingual(context, region.name, region.nameKh);
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radius),
        side: const BorderSide(color: AppColors.sand200),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(Routes.region(region.slug)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  AppImage(region.image),
                  Positioned(left: 14, top: 14, child: Pill.onImage(region.number)),
                  Positioned(
                    right: 10,
                    top: 10,
                    child: SaveButton(kind: SavedKind.region, itemKey: region.slug),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppText.display(21)),
                  if (subtitle != null) ...[const SizedBox(height: 2), KhmerText(subtitle, size: 13)],
                  const SizedBox(height: 8),
                  Text(region.summary, style: AppText.sans(14, color: AppColors.sand600, height: 1.5)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text(
                        s.exploreRegion,
                        style: AppText.sans(14, weight: FontWeight.w600, color: AppColors.brand600),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_forward_rounded, size: 17, color: AppColors.brand600),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- Interests

class _InterestsTab extends StatelessWidget {
  const _InterestsTab();

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return AsyncView<List<Interest>>(
      load: context.read<TravelRepository>().getInterests,
      builder: (context, interests, _) => CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _Intro(s.introInterests)),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 32 + MediaQuery.paddingOf(context).bottom),
            sliver: SliverGrid.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 240,
                mainAxisSpacing: 16,
                crossAxisSpacing: 14,
                mainAxisExtent: 252,
              ),
              itemCount: interests.length,
              itemBuilder: (_, i) => InterestCard(interest: interests[i]),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- Provinces

class _ProvincesTab extends StatefulWidget {
  const _ProvincesTab();

  @override
  State<_ProvincesTab> createState() => _ProvincesTabState();
}

class _ProvincesTabState extends State<_ProvincesTab> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return AsyncView<List<Province>>(
      load: context.read<TravelRepository>().getProvinces,
      builder: (context, provinces, _) {
        final q = _query.toLowerCase();
        final list = provinces
            .where(
              (p) =>
                  q.isEmpty ||
                  p.name.toLowerCase().contains(q) ||
                  (p.nameKh?.contains(q) ?? false) ||
                  p.tagline.toLowerCase().contains(q),
            )
            .toList();
        return CustomScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            SliverToBoxAdapter(child: _Intro(s.introProvinces)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: TextField(
                  onChanged: (v) => setState(() => _query = v.trim()),
                  decoration: InputDecoration(
                    hintText: s.searchProvinces,
                    prefixIcon: const Icon(Icons.search_rounded),
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 32 + MediaQuery.paddingOf(context).bottom),
              sliver: SliverGrid.builder(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 240,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 14,
                  childAspectRatio: 0.78,
                ),
                itemCount: list.length,
                itemBuilder: (_, i) => ProvinceTile(province: list[i]),
              ),
            ),
          ],
        );
      },
    );
  }
}

class ProvinceTile extends StatelessWidget {
  const ProvinceTile({super.key, required this.province});
  final Province province;

  @override
  Widget build(BuildContext context) {
    final (title, _) = bilingual(context, province.name, province.nameKh);
    return GestureDetector(
      onTap: () => context.push(Routes.province(province.slug)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Full width, or narrow photos stop short of the tile's edge.
          Expanded(
            child: AppImage(province.image, width: double.infinity, radius: BorderRadius.circular(18)),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: AppText.sans(15, weight: FontWeight.w600, color: AppColors.sand900),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            province.tagline,
            style: AppText.sans(12, color: AppColors.sand500, height: 1.35),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- Corridors

class _CorridorsTab extends StatelessWidget {
  const _CorridorsTab();

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return AsyncView<List<Corridor>>(
      load: context.read<TravelRepository>().getCorridors,
      builder: (context, corridors, _) => ListView.separated(
        padding: EdgeInsets.only(bottom: 32 + MediaQuery.paddingOf(context).bottom),
        itemCount: corridors.length + 1,
        separatorBuilder: (_, i) => SizedBox(height: i == 0 ? 0 : 14),
        itemBuilder: (_, i) => i == 0
            ? _Intro(s.introCorridors)
            : Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: CorridorListCard(corridor: corridors[i - 1]),
              ),
      ),
    );
  }
}

class CorridorListCard extends StatelessWidget {
  const CorridorListCard({super.key, required this.corridor});
  final Corridor corridor;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return SurfaceCard(
      padding: const EdgeInsets.all(18),
      onTap: () => context.push(Routes.corridor(corridor.slug)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Pill(corridor.duration, icon: Icons.schedule_rounded),
              const Spacer(),
              SaveButton(kind: SavedKind.corridor, itemKey: corridor.slug, onImage: false),
            ],
          ),
          const SizedBox(height: 6),
          Text(corridor.name, style: AppText.display(22)),
          const SizedBox(height: 6),
          Text(corridor.description, style: AppText.sans(14, color: AppColors.sand600, height: 1.5)),
          const SizedBox(height: 14),
          StopChain(corridor: corridor),
          const SizedBox(height: 14),
          Row(
            children: [
              Text(
                s.viewCorridor,
                style: AppText.sans(14, weight: FontWeight.w600, color: AppColors.brand600),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.arrow_forward_rounded, size: 17, color: AppColors.brand600),
            ],
          ),
        ],
      ),
    );
  }
}

/// "Angkor → Roluos → Phnom Kulen…" with Khmer names underneath.
class StopChain extends StatelessWidget {
  const StopChain({super.key, required this.corridor});
  final Corridor corridor;

  @override
  Widget build(BuildContext context) {
    final stops = corridor.stops;
    return Wrap(
      spacing: 6,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (var i = 0; i < stops.length; i++) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: AppColors.sand100, borderRadius: BorderRadius.circular(10)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  stops[i].name,
                  style: AppText.sans(12.5, weight: FontWeight.w600, color: AppColors.sand800),
                ),
                if (showKhmerNames && stops[i].nameKh != null)
                  Text(stops[i].nameKh!, style: AppText.sans(11, color: AppColors.sand500)),
              ],
            ),
          ),
          if (i < stops.length - 1)
            Icon(
              corridor.sequential ? Icons.arrow_forward_rounded : Icons.circle,
              size: corridor.sequential ? 15 : 5,
              color: AppColors.sand400,
            ),
        ],
      ],
    );
  }
}
