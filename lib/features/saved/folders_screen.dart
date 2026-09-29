import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/models.dart';
import '../../data/repositories/travel_repository.dart';
import '../../state/collections_provider.dart';
import '../../widgets/async_view.dart';
import '../../widgets/common.dart';
import 'saved_tiles.dart';

/// The places inside one collection. "All" gathers everything saved, in any
/// collection or hearted on its own.
class FolderScreen extends StatefulWidget {
  const FolderScreen({super.key, required this.name});
  final String name;

  /// The collection that holds everything.
  static const allFolder = 'All';

  @override
  State<FolderScreen> createState() => _FolderScreenState();
}

class _FolderScreenState extends State<FolderScreen> {
  SavedView _view = SavedView.grid;

  /// Removing from a collection takes it out of that one; from "All" it drops
  /// the place from the saved list and every collection.
  void _remove(String key) {
    final folders = context.read<FoldersProvider>();
    if (widget.name == FolderScreen.allFolder) {
      context.read<SavedProvider>().remove(SavedKind.destination, key);
      folders.removeEverywhere(key);
    } else {
      folders.toggleItem(widget.name, key);
    }
    showToast(context, S.read(context).removedFromList);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final folders = context.watch<FoldersProvider>();
    final saved = context.watch<SavedProvider>();

    final keys = widget.name == FolderScreen.allFolder
        ? {...saved.keysOf(SavedKind.destination), ...folders.folders.values.expand((e) => e)}.toList()
        : folders.items(widget.name);

    return Scaffold(
      appBar: AppBar(title: Text(widget.name, style: AppText.display(20)), centerTitle: true),
      body: keys.isEmpty
          ? EmptyState(icon: Icons.folder_open_rounded, title: s.emptyFolder, body: s.emptyFolderBody)
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ViewToggle(view: _view, onChanged: (v) => setState(() => _view = v)),
                    ],
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
                      if (_view == SavedView.list) {
                        return ListView.builder(
                          padding: EdgeInsets.only(top: 4, bottom: bottom),
                          itemCount: list.length,
                          itemBuilder: (_, i) => SavedRow(
                            destination: list[i],
                            onRemove: () => _remove(list[i].key),
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
                          onRemove: () => _remove(list[i].key),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
