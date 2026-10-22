import 'dart:async';

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../data/api/ams_api.dart';
import '../../widgets/app_image.dart';
import '../../widgets/async_view.dart';
import '../../widgets/common.dart';
import '../search/search_screen.dart';

/// Type-ahead for the browse pages: the first matches from `GET /search?q=`,
/// then what the text could be from `GET /search/suggest`. Submitting opens
/// the full results on the Search screen.
class PopularSearchScreen extends StatefulWidget {
  const PopularSearchScreen({super.key});

  @override
  State<PopularSearchScreen> createState() => _PopularSearchScreenState();
}

class _PopularSearchScreenState extends State<PopularSearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  String _query = '';
  Future<(List<PlaceCard>, List<Suggestion>)>? _answer;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () => _ask(v));
  }

  void _ask(String v) {
    final q = v.trim();
    if (q == _query) return;
    final api = context.read<AmsApi>();
    setState(() {
      _query = q;
      _answer = q.isEmpty ? null : (api.search(q: q, size: 3), api.suggest(q)).wait.then((r) => (r.$1.content, r.$2));
    });
  }

  void _run(String query) {
    final q = query.trim();
    if (q.isEmpty) return;
    context.push('${Routes.search}?q=${Uri.encodeQueryComponent(q)}');
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final answer = _answer;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _SearchRow(
              controller: _controller,
              onChanged: _onChanged,
              onSubmit: () => _run(_controller.text),
              onClear: () {
                _debounce?.cancel();
                _controller.clear();
                _ask('');
              },
            ),
            Expanded(
              child: answer == null
                  ? Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        s.typeToSearch,
                        textAlign: TextAlign.center,
                        style: AppText.sans(14.5, color: AppColors.sand500),
                      ),
                    )
                  : FutureBuilder<(List<PlaceCard>, List<Suggestion>)>(
                      future: answer,
                      builder: (context, snap) {
                        if (snap.hasError) {
                          return ErrorView(
                            error: snap.error!,
                            onRetry: () {
                              _query = '';
                              _ask(_controller.text);
                            },
                          );
                        }
                        if (!snap.hasData) return const LoadingView();
                        final (places, suggestions) = snap.data!;
                        if (places.isEmpty && suggestions.isEmpty) {
                          return SingleChildScrollView(
                            child: EmptyState(
                              icon: Icons.search_off_rounded,
                              title: s.searchNoMatches,
                              body: s.searchNoMatchesBody,
                            ),
                          );
                        }
                        return ListView(
                          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                          padding: EdgeInsets.only(bottom: 20 + MediaQuery.paddingOf(context).bottom),
                          children: [
                            for (final c in places) _PlaceRow(card: c),
                            if (places.isNotEmpty && suggestions.isNotEmpty) const SizedBox(height: 6),
                            for (final sug in suggestions)
                              SuggestionRow(suggestion: sug, onTap: () => openSuggestion(context, sug)),
                          ],
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Back arrow, the words being typed, a way to clear them and the search button.
class _SearchRow extends StatelessWidget {
  const _SearchRow({required this.controller, required this.onChanged, required this.onSubmit, required this.onClear});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmit;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 16, 10),
      child: Row(
        children: [
          IconButton(
            onPressed: () => context.pop(),
            icon: const Icon(Icons.chevron_left_rounded, size: 30, color: AppColors.sand900),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 4, 4, 4),
              decoration: BoxDecoration(color: AppColors.sand100, borderRadius: BorderRadius.circular(16)),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      autofocus: true,
                      textInputAction: TextInputAction.search,
                      onChanged: onChanged,
                      onSubmitted: (_) => onSubmit(),
                      cursorColor: AppColors.violet,
                      style: AppText.sans(14.5, weight: FontWeight.w500, color: AppColors.sand900),
                      decoration: InputDecoration(
                        hintText: s.popularDestinations,
                        hintStyle: AppText.sans(14.5, color: AppColors.sand400),
                        filled: false,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 11),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                      ),
                    ),
                  ),
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: controller,
                    builder: (_, value, _) => value.text.isEmpty
                        ? const SizedBox(width: 6)
                        : IconButton(
                            onPressed: onClear,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            icon: const Icon(Icons.cancel_rounded, size: 20, color: AppColors.sand400),
                          ),
                  ),
                  const SizedBox(width: 6),
                  Material(
                    color: AppColors.violet,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: onSubmit,
                      child: const Padding(
                        padding: EdgeInsets.all(9),
                        child: Icon(Icons.search_rounded, color: Colors.white, size: 20),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One matching place: photo, name, what it is, and a way in.
class _PlaceRow extends StatelessWidget {
  const _PlaceRow({required this.card});
  final PlaceCard card;

  @override
  Widget build(BuildContext context) {
    final c = card;
    final detail = [
      if (c.categoryNames.isNotEmpty) c.categoryNames.first,
      if (c.provinceName != null) c.provinceName!,
    ].join(', ');
    return InkWell(
      onTap: () => context.push(Routes.card(c)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Row(
          children: [
            SizedBox(width: 58, height: 58, child: AppImage(c.coverUrl, radius: BorderRadius.circular(12))),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    c.name,
                    style: AppText.sans(14.5, weight: FontWeight.w700, color: AppColors.sand900),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (detail.isNotEmpty || c.shortDescription != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      detail.isNotEmpty ? detail : c.shortDescription!,
                      style: AppText.sans(12.5, color: AppColors.sand500),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(color: AppColors.violet.withValues(alpha: 0.10), shape: BoxShape.circle),
              child: const Icon(Icons.arrow_forward_rounded, size: 15, color: AppColors.violet),
            ),
          ],
        ),
      ),
    );
  }
}
