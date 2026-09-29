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
import 'folders_screen.dart';
import 'saved_tiles.dart';

/// Everything the traveller kept: the places themselves, and the collections
/// they are filed under.
class SavedScreen extends StatefulWidget {
  const SavedScreen({super.key, this.initialTab = 0});

  /// 0 = saves, 1 = collections. `/folders` opens straight on collections.
  final int initialTab;

  @override
  State<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends State<SavedScreen> with SingleTickerProviderStateMixin {
  late final _tabs = TabController(length: 2, vsync: this, initialIndex: widget.initialTab);
  SavedView _view = SavedView.list;

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final saved = context.watch<SavedProvider>();
    final folders = context.watch<FoldersProvider>();
    final keys = saved.keysOf(SavedKind.destination);

    return Scaffold(
      appBar: AppBar(
        title: Text(s.savedTitle, style: AppText.display(20)),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabs,
          // The app theme aligns tabs to the start for scrollable bars; these
          // two share the width.
          tabAlignment: TabAlignment.fill,
          indicatorColor: AppColors.violet,
          labelColor: AppColors.violet,
          tabs: [
            Tab(text: '${s.saves} (${keys.length})'),
            Tab(text: '${s.collections} (${folders.count + 1})'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _SavesTab(
            keys: keys,
            view: _view,
            onView: (v) => setState(() => _view = v),
          ),
          const _CollectionsTab(),
        ],
      ),
    );
  }
}

/// Every saved place, as a list or a grid.
class _SavesTab extends StatelessWidget {
  const _SavesTab({required this.keys, required this.view, required this.onView});
  final List<String> keys;
  final SavedView view;
  final ValueChanged<SavedView> onView;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    if (keys.isEmpty) {
      return SingleChildScrollView(
        child: EmptyState(
          icon: Icons.favorite_border_rounded,
          title: s.emptySaved,
          body: s.emptySavedBody,
        ),
      );
    }

    void remove(String key) {
      context.read<SavedProvider>().remove(SavedKind.destination, key);
      context.read<FoldersProvider>().removeEverywhere(key);
      showToast(context, S.read(context).removedFromList);
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [ViewToggle(view: view, onChanged: onView)],
          ),
        ),
        Expanded(
          child: AsyncView<List<Destination>>(
            key: ValueKey(keys.join('|')),
            load: () => context.read<TravelRepository>().getDestinationsByRefs(
              keys.map(DestinationRef.fromKey).toList(),
            ),
            builder: (context, list, _) {
              final bottom = 24 + MediaQuery.paddingOf(context).bottom;
              if (view == SavedView.list) {
                return ListView.builder(
                  padding: EdgeInsets.only(top: 4, bottom: bottom),
                  itemCount: list.length,
                  itemBuilder: (_, i) => SavedRow(
                    destination: list[i],
                    onRemove: () => remove(list[i].key),
                  ),
                );
              }
              return GridView.builder(
                padding: EdgeInsets.fromLTRB(20, 8, 20, bottom),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 14,
                  mainAxisExtent: 196,
                ),
                itemCount: list.length,
                itemBuilder: (_, i) => SavedTile(
                  destination: list[i],
                  onRemove: () => remove(list[i].key),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// The collections: All, then each folder.
class _CollectionsTab extends StatelessWidget {
  const _CollectionsTab();

  @override
  Widget build(BuildContext context) {
    final folders = context.watch<FoldersProvider>();
    final saved = context.watch<SavedProvider>();

    final all = <String>{
      ...saved.keysOf(SavedKind.destination),
      ...folders.folders.values.expand((e) => e),
    }.toList();
    final names = [FolderScreen.allFolder, ...folders.folders.keys];

    return GridView.builder(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 24 + MediaQuery.paddingOf(context).bottom),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 18,
        crossAxisSpacing: 14,
        mainAxisExtent: 168,
      ),
      itemCount: names.length,
      itemBuilder: (_, i) => _CollectionTile(
        name: names[i],
        keys: i == 0 ? all : folders.items(names[i]),
      ),
    );
  }
}

/// One collection: the first place in it stands for the whole folder.
class _CollectionTile extends StatelessWidget {
  const _CollectionTile({required this.name, required this.keys});
  final String name;
  final List<String> keys;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push(Routes.folder(name)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: keys.isEmpty
                  ? Container(color: AppColors.sand100)
                  : AsyncView<List<Destination>>(
                      key: ValueKey(keys.first),
                      load: () => context.read<TravelRepository>().getDestinationsByRefs([
                        DestinationRef.fromKey(keys.first),
                      ]),
                      loading: Container(color: AppColors.sand100),
                      builder: (context, list, _) =>
                          list.isEmpty ? Container(color: AppColors.sand100) : AppImage(list.first.image),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            name,
            style: AppText.sans(14, weight: FontWeight.w700, color: AppColors.sand900),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            '${keys.length} ${S.of(context).places.toLowerCase()}',
            style: AppText.sans(11.5, color: AppColors.sand500),
          ),
        ],
      ),
    );
  }
}
