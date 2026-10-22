import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../data/api/ams_api.dart';
import '../../state/auth_provider.dart';
import '../../state/collections_provider.dart';
import '../../widgets/async_view.dart';
import '../../widgets/common.dart';
import 'saved_screen.dart';
import 'saved_tiles.dart';

/// The places in one folder. "All" holds every favourite.
///
/// Folders are kept on the phone (parked 2026-10-14, R-008); what they hold are favourites
/// from the API, and a folder shows only what is still saved.
class FolderScreen extends StatefulWidget {
  const FolderScreen({super.key, required this.name});
  final String name;

  /// The folder that holds everything.
  static const allFolder = 'All';

  @override
  State<FolderScreen> createState() => _FolderScreenState();
}

class _FolderScreenState extends State<FolderScreen> {
  late final SavedCards _cards = SavedCards(context.read<AmsApi>(), known: context.read<SavedProvider>().cardFor);
  SavedView _view = SavedView.grid;

  bool get _isAll => widget.name == FolderScreen.allFolder;

  @override
  void dispose() {
    _cards.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    final s = S.read(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('${s.deleteFolder}?', style: AppText.display(20)),
        content: Text(widget.name),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(s.cancel)),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(s.delete)),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    context.read<FoldersProvider>().remove(widget.name);
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final signedIn = context.select<AuthProvider, bool>((a) => a.isSignedIn);
    final saved = context.watch<SavedProvider>();
    final folders = context.watch<FoldersProvider>();
    final all = [for (final f in saved.favorites) ?favoriteKey(f)];
    final savedSet = all.toSet();
    final keys = _isAll
        ? all
        : [
            for (final k in folders.items(widget.name))
              if (savedSet.contains(k)) k,
          ];
    if (!_cards.covers(keys)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _cards.ensure(keys);
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isAll ? s.all : widget.name, style: AppText.display(20)),
        centerTitle: true,
        actions: [
          if (!_isAll && signedIn)
            IconButton(tooltip: s.deleteFolder, onPressed: _delete, icon: const Icon(Icons.delete_outline_rounded)),
        ],
      ),
      body: !signedIn
          ? const SavedSignIn()
          : ListenableBuilder(
              listenable: _cards,
              builder: (context, _) {
                if (_cards.error != null) {
                  return ErrorView(error: _cards.error!, onRetry: () => _cards.retry(keys));
                }
                final cards = _cards.cardsOf(keys);
                if (cards.isEmpty && !_cards.covers(keys)) return const LoadingView();
                if (cards.isEmpty) {
                  return SingleChildScrollView(
                    child: EmptyState(icon: Icons.folder_open_rounded, title: s.emptyFolder, body: s.emptyFolderHint),
                  );
                }
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [ViewToggle(view: _view, onChanged: (v) => setState(() => _view = v))],
                      ),
                    ),
                    Expanded(
                      child: SavedCardsView(cards: cards, view: _view, folder: _isAll ? null : widget.name),
                    ),
                  ],
                );
              },
            ),
    );
  }
}
