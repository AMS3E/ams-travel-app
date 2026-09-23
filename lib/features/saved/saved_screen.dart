import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/models.dart';
import '../../data/repositories/travel_repository.dart';
import '../../state/auth_provider.dart';
import '../../state/collections_provider.dart';
import '../../widgets/app_image.dart';
import '../../widgets/async_view.dart';
import '../../widgets/common.dart';
import '../../widgets/destination_card.dart';
import '../explore/explore_screen.dart';

class SavedScreen extends StatelessWidget {
  const SavedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final saved = context.watch<SavedProvider>();
    final stamps = context.watch<StampsProvider>();
    final signedIn = context.select<AuthProvider, bool>((a) => a.isSignedIn);

    String withCount(String label, int n) => n == 0 ? label : '$label  $n';

    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: 96,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.savedTitle, style: AppText.display(26)),
              const SizedBox(height: 4),
              Text(s.savedSubtitle, style: AppText.sans(13.5, color: AppColors.sand500), maxLines: 2),
            ],
          ),
          bottom: TabBar(
            isScrollable: true,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            tabs: [
              Tab(text: withCount(s.places, saved.keysOf(SavedKind.destination).length)),
              Tab(text: withCount(s.regions, saved.keysOf(SavedKind.region).length)),
              Tab(text: withCount(s.provinces, saved.keysOf(SavedKind.province).length)),
              Tab(text: withCount(s.corridors, saved.keysOf(SavedKind.corridor).length)),
              Tab(text: withCount(s.stamps, signedIn ? stamps.count : 0)),
            ],
          ),
        ),
        body: const TabBarView(
          children: [_PlacesTab(), _RegionsTab(), _ProvincesTab(), _CorridorsTab(), _StampsTab()],
        ),
      ),
    );
  }
}

class _EmptySaved extends StatelessWidget {
  const _EmptySaved();

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return SingleChildScrollView(
      child: EmptyState(
        icon: Icons.favorite_border_rounded,
        title: s.emptySaved,
        body: s.emptySavedBody,
        actionLabel: s.startExploring,
        onAction: () => context.go(Routes.explore),
      ),
    );
  }
}

class _PlacesTab extends StatelessWidget {
  const _PlacesTab();

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final refs = context.watch<SavedProvider>().destinationRefs;
    if (refs.isEmpty) return const _EmptySaved();
    return AsyncView<List<Destination>>(
      key: ValueKey(refs.map((r) => r.key).join('|')),
      load: () => context.read<TravelRepository>().getDestinationsByRefs(refs),
      builder: (context, list, _) => ListView(
        padding: EdgeInsets.fromLTRB(20, 12, 20, 32 + MediaQuery.paddingOf(context).bottom),
        children: [
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(backgroundColor: Colors.white),
              onPressed: () => context.go(Routes.map),
              icon: const Icon(Icons.map_outlined, size: 19),
              label: Text(s.openFullMap),
            ),
          ),
          const SizedBox(height: 8),
          for (final d in list)
            Dismissible(
              key: ValueKey(d.key),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                decoration: BoxDecoration(color: AppColors.sunset50, borderRadius: BorderRadius.circular(16)),
                child: const Icon(Icons.delete_outline_rounded, color: AppColors.sunset600),
              ),
              onDismissed: (_) {
                context.read<SavedProvider>().remove(SavedKind.destination, d.key);
                showToast(
                  context,
                  s.removedFromList,
                  actionLabel: 'Undo',
                  onAction: () => context.read<SavedProvider>().toggle(SavedKind.destination, d.key),
                );
              },
              child: DestinationTile(
                destination: d,
                caption: d.category,
                trailing: SaveButton(kind: SavedKind.destination, itemKey: d.key, onImage: false),
              ),
            ),
        ],
      ),
    );
  }
}

class _RegionsTab extends StatelessWidget {
  const _RegionsTab();

  @override
  Widget build(BuildContext context) {
    final keys = context.watch<SavedProvider>().keysOf(SavedKind.region);
    if (keys.isEmpty) return const _EmptySaved();
    return AsyncView<List<Region>>(
      key: ValueKey(keys.join('|')),
      load: context.read<TravelRepository>().getRegions,
      builder: (context, all, _) {
        final list = [for (final k in keys) ...all.where((r) => r.slug == k)];
        return ListView.separated(
          padding: EdgeInsets.fromLTRB(20, 16, 20, 32 + MediaQuery.paddingOf(context).bottom),
          itemCount: list.length,
          separatorBuilder: (_, _) => const SizedBox(height: 14),
          itemBuilder: (_, i) => RegionListCard(region: list[i]),
        );
      },
    );
  }
}

class _ProvincesTab extends StatelessWidget {
  const _ProvincesTab();

  @override
  Widget build(BuildContext context) {
    final keys = context.watch<SavedProvider>().keysOf(SavedKind.province);
    if (keys.isEmpty) return const _EmptySaved();
    return AsyncView<List<Province>>(
      key: ValueKey(keys.join('|')),
      load: context.read<TravelRepository>().getProvinces,
      builder: (context, all, _) {
        final list = [for (final k in keys) ...all.where((p) => p.slug == k)];
        return GridView.builder(
          padding: EdgeInsets.fromLTRB(20, 16, 20, 32 + MediaQuery.paddingOf(context).bottom),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 240,
            mainAxisSpacing: 16,
            crossAxisSpacing: 14,
            childAspectRatio: 0.78,
          ),
          itemCount: list.length,
          itemBuilder: (_, i) => ProvinceTile(province: list[i]),
        );
      },
    );
  }
}

class _CorridorsTab extends StatelessWidget {
  const _CorridorsTab();

  @override
  Widget build(BuildContext context) {
    final keys = context.watch<SavedProvider>().keysOf(SavedKind.corridor);
    if (keys.isEmpty) return const _EmptySaved();
    return AsyncView<List<Corridor>>(
      key: ValueKey(keys.join('|')),
      load: context.read<TravelRepository>().getCorridors,
      builder: (context, all, _) {
        final list = [for (final k in keys) ...all.where((c) => c.slug == k)];
        return ListView.separated(
          padding: EdgeInsets.fromLTRB(20, 16, 20, 32 + MediaQuery.paddingOf(context).bottom),
          itemCount: list.length,
          separatorBuilder: (_, _) => const SizedBox(height: 14),
          itemBuilder: (_, i) => CorridorListCard(corridor: list[i]),
        );
      },
    );
  }
}

class _StampsTab extends StatelessWidget {
  const _StampsTab();

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final signedIn = context.select<AuthProvider, bool>((a) => a.isSignedIn);
    if (!signedIn) {
      return SingleChildScrollView(
        child: EmptyState(
          icon: Icons.approval_outlined,
          title: s.stamps,
          body: s.logInForStamps,
          actionLabel: s.logIn,
          onAction: () => context.push(Routes.login),
        ),
      );
    }
    final entries = context.watch<StampsProvider>().entries;
    if (entries.isEmpty) {
      return SingleChildScrollView(
        child: EmptyState(
          icon: Icons.approval_outlined,
          title: s.emptyStamps,
          body: s.emptyStampsBody,
          actionLabel: s.startExploring,
          onAction: () => context.go(Routes.explore),
        ),
      );
    }
    final dates = {for (final e in entries) e.key: e.value};
    return AsyncView<List<Destination>>(
      key: ValueKey(entries.map((e) => e.key).join('|')),
      load: () => context.read<TravelRepository>().getDestinationsByRefs(
        entries.map((e) => DestinationRef.fromKey(e.key)).toList(),
      ),
      builder: (context, list, _) => CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: AppColors.logoGradient,
                  borderRadius: BorderRadius.circular(AppTheme.radius),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.approval_rounded, color: Colors.white, size: 34),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: '${list.length} ',
                              style: AppText.display(28, color: Colors.white),
                            ),
                            TextSpan(
                              text: '${s.stamps.toLowerCase()} ${s.collected}',
                              style: AppText.sans(15, color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(20, 14, 20, 32 + MediaQuery.paddingOf(context).bottom),
            sliver: SliverGrid.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 130,
                mainAxisSpacing: 18,
                crossAxisSpacing: 12,
                childAspectRatio: 0.66,
              ),
              itemCount: list.length,
              itemBuilder: (_, i) => _Stamp(destination: list[i], date: dates[list[i].key]!),
            ),
          ),
        ],
      ),
    );
  }
}

class _Stamp extends StatelessWidget {
  const _Stamp({required this.destination, required this.date});
  final Destination destination;
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final (name, _) = bilingual(context, destination.name, destination.nameKh);
    return GestureDetector(
      onTap: () => context.push(Routes.destination(destination.region, destination.slug)),
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.forRegion(destination.region), width: 3),
              ),
              child: ClipOval(child: AppImage(destination.image)),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            name,
            textAlign: TextAlign.center,
            style: AppText.sans(12.5, weight: FontWeight.w600, color: AppColors.sand900),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          Text('${date.day} ${months[date.month - 1]}', style: AppText.sans(11, color: AppColors.sand500)),
        ],
      ),
    );
  }
}
