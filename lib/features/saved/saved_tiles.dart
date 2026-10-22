import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../data/api/ams_api.dart';
import '../../state/collections_provider.dart';
import '../../widgets/app_image.dart';
import '../../widgets/common.dart';
import '../../widgets/destination_card.dart';

/// Which way the saved places are laid out.
enum SavedView { list, grid }

/// The key a favourite has in a folder and in [SavedCards]; null for a saved
/// region or province, which are not places.
String? favoriteKey(Favorite f) {
  final type = f.targetType.cardType;
  return type == null ? null : FoldersProvider.keyOf(type, f.targetId);
}

/// The cards of saved items, fetched once each: `GET /search/cards?type=&ids=`
/// per kind for whatever is not here yet or in [known].
class SavedCards extends ChangeNotifier {
  SavedCards(this._api, {this.known});

  final AmsApi _api;

  /// Cards already fetched elsewhere ([SavedProvider.cardFor]).
  final PlaceCard? Function(String key)? known;
  final Map<String, PlaceCard> _cards = {};

  /// Asked for already, found or not (an unpublished place has no card).
  final Set<String> _asked = {};
  bool _loading = false;
  Object? _error;

  bool get loading => _loading;
  Object? get error => _error;

  PlaceCard? operator [](String key) => _cards[key];

  /// The cards for [keys] that have arrived, in that order.
  List<PlaceCard> cardsOf(Iterable<String> keys) => [for (final k in keys) ?_cards[k]];

  /// True once every key has been asked for.
  bool covers(Iterable<String> keys) => keys.every(_asked.contains);

  /// Fetches the cards not asked for yet.
  Future<void> ensure(Iterable<String> keys) async {
    if (_loading) return;
    final byType = <CardType, List<String>>{};
    var tookKnown = false;
    for (final key in keys) {
      if (_asked.contains(key)) continue;
      if (known?.call(key) case final card?) {
        _cards[key] = card;
        _asked.add(key);
        tookKnown = true;
        continue;
      }
      final ref = FoldersProvider.parse(key);
      if (ref == null) continue;
      byType.putIfAbsent(ref.$1, () => []).add(ref.$2);
    }
    if (byType.isEmpty) {
      if (tookKnown) notifyListeners();
      return;
    }
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final calls = [for (final e in byType.entries) _api.cards(e.value, type: e.key)];
      for (final cards in await Future.wait(calls)) {
        for (final c in cards) {
          _cards[FoldersProvider.keyOf(c.type, c.id)] = c;
        }
      }
      for (final e in byType.entries) {
        _asked.addAll(e.value.map((id) => FoldersProvider.keyOf(e.key, id)));
      }
    } catch (e) {
      _error = e;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Forgets the failure so [ensure] tries again.
  Future<void> retry(Iterable<String> keys) {
    _error = null;
    return ensure(keys);
  }
}

/// The List / Grid switch above a set of saved places.
class ViewToggle extends StatelessWidget {
  const ViewToggle({super.key, required this.view, required this.onChanged});
  final SavedView view;
  final ValueChanged<SavedView> onChanged;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    Widget half(SavedView value, IconData icon, String label) {
      final on = value == view;
      return InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: () => onChanged(value),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: on ? AppColors.violet : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: on ? Colors.white : AppColors.sand600),
              const SizedBox(width: 5),
              Text(
                label,
                style: AppText.sans(12.5, weight: FontWeight.w600, color: on ? Colors.white : AppColors.sand600),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: AppColors.sand100, borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          half(SavedView.list, Icons.view_list_rounded, s.listView),
          const SizedBox(width: 3),
          half(SavedView.grid, Icons.grid_view_rounded, s.gridView),
        ],
      ),
    );
  }
}

/// A saved place in a row: photo, name, where it is, its score, the heart,
/// and a menu to file it in a folder (or take it out of [folder]).
class SavedRow extends StatelessWidget {
  const SavedRow({super.key, required this.card, this.folder});
  final PlaceCard card;

  /// The folder the row is shown in, if any.
  final String? folder;

  @override
  Widget build(BuildContext context) {
    final d = card;
    final s = S.of(context);
    final where = d.provinceName ?? (d.durationDays != null ? s.daysCount(d.durationDays!) : d.shortDescription) ?? '';
    return InkWell(
      onTap: () => context.push(Routes.card(d)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 4, 8),
        child: Row(
          children: [
            SizedBox(width: 52, height: 52, child: AppImage(d.coverUrl, radius: BorderRadius.circular(12))),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    d.name,
                    style: AppText.sans(14, weight: FontWeight.w700, color: AppColors.sand900),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (where.isNotEmpty)
                    Text(
                      where,
                      style: AppText.sans(11.5, color: AppColors.sand500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (d.averageRating != null) ...[const SizedBox(height: 4), RatingBadge(rating: d.averageRating!)],
                ],
              ),
            ),
            SaveButton(kind: SavedKind.of(d.type), itemKey: d.id, onImage: false),
          ],
        ),
      ),
    );
  }
}

/// Picks a folder for [key] (or makes a new one). Folders stay on the phone:
/// parked 2026-10-14 (R-008).
Future<void> showFolderPicker(BuildContext context, String key) async {
  final s = S.read(context);
  final folder = await showModalBottomSheet<String>(
    context: context,
    useSafeArea: true,
    builder: (sheet) {
      final folders = sheet.watch<FoldersProvider>();
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.addToFolder, style: AppText.display(20)),
              const SizedBox(height: 4),
              Text(s.foldersDeviceNote, style: AppText.sans(12.5, color: AppColors.sand500)),
              const SizedBox(height: 8),
              for (final name in folders.names)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.folder_outlined, color: AppColors.violet),
                  title: Text(name),
                  trailing: folders.contains(name, key)
                      ? const Icon(Icons.check_circle_rounded, color: AppColors.violet)
                      : null,
                  onTap: () => Navigator.pop(sheet, name),
                ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.create_new_folder_outlined, color: AppColors.sand700),
                title: Text(s.newFolder),
                onTap: () async {
                  final name = await askFolderName(sheet);
                  if (name == null || !sheet.mounted) return;
                  sheet.read<FoldersProvider>().create(name);
                  Navigator.pop(sheet, name.trim());
                },
              ),
            ],
          ),
        ),
      );
    },
  );
  if (folder == null || !context.mounted) return;
  final added = context.read<FoldersProvider>().toggleItem(folder, key);
  showToast(context, s.fill(added ? s.addedToFolder : s.removedFromFolder, {'name': folder}));
}

/// Asks for a new folder's name.
Future<String?> askFolderName(BuildContext context) {
  final s = S.read(context);
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(s.newFolder, style: AppText.display(20)),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: InputDecoration(hintText: s.folderName),
        onSubmitted: (v) => Navigator.pop(c, v.trim().isEmpty ? null : v.trim()),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: Text(s.cancel)),
        FilledButton(
          onPressed: () => Navigator.pop(c, controller.text.trim().isEmpty ? null : controller.text.trim()),
          child: Text(s.createWord),
        ),
      ],
    ),
  ).whenComplete(controller.dispose);
}

/// The places as a list or a two-column grid of cards.
class SavedCardsView extends StatelessWidget {
  const SavedCardsView({super.key, required this.cards, required this.view, this.folder, this.header});
  final List<PlaceCard> cards;
  final SavedView view;
  final String? folder;

  /// Scrolls with the places, above them.
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    final bottom = 24 + MediaQuery.paddingOf(context).bottom;
    final header = this.header;
    if (view == SavedView.list) {
      final offset = header == null ? 0 : 1;
      return ListView.builder(
        padding: EdgeInsets.only(top: 4, bottom: bottom),
        itemCount: cards.length + offset,
        itemBuilder: (_, i) => i < offset ? header! : SavedRow(card: cards[i - offset], folder: folder),
      );
    }
    return CustomScrollView(
      slivers: [
        if (header != null)
          SliverPadding(
            padding: const EdgeInsets.only(top: 8),
            sliver: SliverToBoxAdapter(child: header),
          ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(20, 8, 20, bottom),
          sliver: SliverGrid.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 14,
              mainAxisExtent: 196,
            ),
            itemCount: cards.length,
            itemBuilder: (_, i) => SavedTile(card: cards[i]),
          ),
        ),
      ],
    );
  }
}

/// A saved place as a small card: photo with its score and the heart, then
/// the name and where it is.
class SavedTile extends StatelessWidget {
  const SavedTile({super.key, required this.card});
  final PlaceCard card;

  @override
  Widget build(BuildContext context) {
    final d = card;
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
                  if (d.averageRating != null)
                    Positioned(left: 8, top: 8, child: RatingBadge(rating: d.averageRating!, onImage: true)),
                  Positioned(
                    right: 2,
                    top: 2,
                    child: SaveButton(kind: SavedKind.of(d.type), itemKey: d.id, size: 32),
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
          Text(
            d.provinceName ?? '',
            style: AppText.sans(11.5, color: AppColors.sand500),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// The amber score badge.
class RatingBadge extends StatelessWidget {
  const RatingBadge({super.key, required this.rating, this.onImage = false});
  final double rating;
  final bool onImage;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: onImage ? const Color(0xCC1A1206) : AppColors.star.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, size: 12, color: AppColors.star),
          const SizedBox(width: 3),
          Text(
            rating.toStringAsFixed(1),
            style: AppText.sans(10.5, weight: FontWeight.w700, color: onImage ? Colors.white : AppColors.sand800),
          ),
        ],
      ),
    );
  }
}
