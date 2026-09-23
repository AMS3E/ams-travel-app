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
import '../../widgets/async_view.dart';
import '../../widgets/common.dart';
import '../../widgets/app_image.dart';

/// Saved places, grouped into folders.
class FoldersScreen extends StatefulWidget {
  const FoldersScreen({super.key});

  @override
  State<FoldersScreen> createState() => _FoldersScreenState();
}

class _FoldersScreenState extends State<FoldersScreen> {
  Future<void> _create() async {
    final s = S.read(context);
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(s.newFolder, style: AppText.display(20)),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: s.folderNameHint),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: Text(s.cancel)),
          FilledButton(onPressed: () => Navigator.pop(c, controller.text), child: Text(s.create)),
        ],
      ),
    );
    if (name != null && name.trim().isNotEmpty && mounted) {
      context.read<FoldersProvider>().create(name);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final saved = context.watch<SavedProvider>();
    final folders = context.watch<FoldersProvider>();
    final saves = saved.count + folders.itemCount;

    return Scaffold(
      appBar: AppBar(title: Text(s.savedTitle, style: AppText.display(20)), centerTitle: true),
      body: ListView(
        padding: EdgeInsets.fromLTRB(20, 8, 20, 24 + MediaQuery.paddingOf(context).bottom),
        children: [
          Row(
            children: [
              Expanded(
                child: _Stat(value: '$saves', label: s.saves),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _Stat(value: '${folders.count}', label: s.folders),
              ),
            ],
          ),
          const SizedBox(height: 18),
          GestureDetector(
            onTap: _create,
            child: Row(
              children: [
                Text(
                  s.createYourFolder,
                  style: AppText.sans(14.5, weight: FontWeight.w700, color: AppColors.sand900),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.add_rounded, size: 19, color: AppColors.sand900),
              ],
            ),
          ),
          const SizedBox(height: 14),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 16,
            crossAxisSpacing: 14,
            childAspectRatio: 0.82,
            children: [
              _FolderCard(
                label: s.all,
                count: saved.count + folders.itemCount,
                onTap: () => context.push(Routes.folder(FolderScreen.allFolder)),
              ),
              for (final name in folders.folders.keys)
                _FolderCard(
                  label: name,
                  count: folders.items(name).length,
                  onTap: () => context.push(Routes.folder(name)),
                  onLongPress: () => _confirmDelete(name),
                ),
              _FolderCard(label: s.newFolder, count: null, isNew: true, onTap: _create),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(String name) async {
    final s = S.read(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(s.deleteFolder, style: AppText.display(20)),
        content: Text(name, style: AppText.sans(15)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(s.cancel)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.sunset500),
            onPressed: () => Navigator.pop(c, true),
            child: Text(s.delete),
          ),
        ],
      ),
    );
    if (ok == true && mounted) context.read<FoldersProvider>().remove(name);
  }
}

/// The places inside one folder. The "All" folder gathers everything saved,
/// in any folder or hearted on its own.
class FolderScreen extends StatelessWidget {
  const FolderScreen({super.key, required this.name});
  final String name;

  /// The folder that holds everything.
  static const allFolder = 'All';

  /// Removing from a folder takes it out of that folder; from "All" it drops
  /// the place from the saved list and every folder.
  void _remove(BuildContext context, String key) {
    final folders = context.read<FoldersProvider>();
    if (name == allFolder) {
      context.read<SavedProvider>().remove(SavedKind.destination, key);
      folders.removeEverywhere(key);
    } else {
      folders.toggleItem(name, key);
    }
    showToast(context, S.read(context).removedFromList);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final folders = context.watch<FoldersProvider>();
    final saved = context.watch<SavedProvider>();

    final keys = name == allFolder
        ? {...saved.keysOf(SavedKind.destination), ...folders.folders.values.expand((e) => e)}.toList()
        : folders.items(name);

    return Scaffold(
      appBar: AppBar(title: Text(name, style: AppText.display(20)), centerTitle: true),
      body: keys.isEmpty
          ? EmptyState(icon: Icons.folder_open_rounded, title: s.emptyFolder, body: s.emptyFolderBody)
          : AsyncView<List<Destination>>(
              key: ValueKey(keys.join('|')),
              load: () => context.read<TravelRepository>().getDestinationsByRefs(
                keys.map(DestinationRef.fromKey).toList(),
              ),
              builder: (context, list, _) => GridView.builder(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 24 + MediaQuery.paddingOf(context).bottom),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 18,
                  crossAxisSpacing: 14,
                  mainAxisExtent: 210,
                ),
                itemCount: list.length,
                itemBuilder: (_, i) => _SavedCard(
                  destination: list[i],
                  onRemove: () => _remove(context, list[i].key),
                ),
              ),
            ),
    );
  }
}

/// Photo with a red heart (it is saved) and a red minus to take it out, then
/// the name and province.
class _SavedCard extends StatelessWidget {
  const _SavedCard({required this.destination, required this.onRemove});
  final Destination destination;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final d = destination;
    return GestureDetector(
      onTap: () => context.push(Routes.destination(d.region, d.slug)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                AppImage(d.image, radius: BorderRadius.circular(AppTheme.radius)),
                Positioned(
                  top: 8,
                  right: 8,
                  child: _RoundIcon(icon: Icons.remove_rounded, onTap: onRemove),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            d.name,
            style: AppText.sans(14.5, weight: FontWeight.w700, color: AppColors.sand900),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            d.province,
            style: AppText.sans(12.5, color: AppColors.sand500),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// Small white circle with a red icon, sitting on a photo.
class _RoundIcon extends StatelessWidget {
  const _RoundIcon({required this.icon, this.onTap});
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.92),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox.square(
          dimension: 32,
          child: Icon(icon, size: 19, color: AppColors.sunset500),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.sand100,
        borderRadius: BorderRadius.circular(AppTheme.radius),
      ),
      child: Column(
        children: [
          Text(value, style: AppText.display(24)),
          const SizedBox(height: 2),
          Text(label, style: AppText.sans(13, color: AppColors.sand500)),
        ],
      ),
    );
  }
}

/// A folder tile: the icon square, then its name and how much is inside.
class _FolderCard extends StatelessWidget {
  const _FolderCard({
    required this.label,
    required this.count,
    required this.onTap,
    this.onLongPress,
    this.isNew = false,
  });

  final String label;
  final int? count;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  /// The "+" tile that makes another folder.
  final bool isNew;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.sand100,
                borderRadius: BorderRadius.circular(AppTheme.radius),
              ),
              child: Icon(
                isNew ? Icons.add_rounded : Icons.folder_rounded,
                size: isNew ? 44 : 54,
                color: isNew ? AppColors.sand400 : Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: AppText.sans(14.5, weight: FontWeight.w600, color: AppColors.sand900),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (count != null)
            Text('$count ${s.places.toLowerCase()}', style: AppText.sans(12, color: AppColors.sand500)),
        ],
      ),
    );
  }
}
