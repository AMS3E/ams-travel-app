import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/models.dart';
import '../../data/repositories/travel_repository.dart';
import '../../widgets/app_image.dart';
import '../../widgets/async_view.dart';
import '../../widgets/destination_card.dart';


/// Type-ahead over every place: the closest matches first, then other words
/// worth searching for.
///
/// TODO(api): the suggestions are worked out on the device. Swap them for a
/// `/search/suggestions?q=` endpoint if the backend offers one.
class PopularSearchScreen extends StatelessWidget {
  const PopularSearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = context.read<TravelRepository>();
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: AsyncView<List<Destination>>(
          load: repo.getDestinations,
          builder: (context, places, _) => _Body(places: places),
        ),
      ),
    );
  }
}

class _Body extends StatefulWidget {
  const _Body({required this.places});
  final List<Destination> places;

  @override
  State<_Body> createState() => _BodyState();
}

class _BodyState extends State<_Body> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// The places that hold any of the words, the closest first.
  List<Destination> get _matches {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) {
      return widget.places.where((d) => d.featured).take(8).toList();
    }
    final words = q.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

    int score(Destination d) {
      final text = '${d.name} ${d.province} ${d.category} ${d.blurb}'.toLowerCase();
      var hits = 0;
      for (final w in words) {
        if (text.contains(w)) hits++;
      }
      if (hits == 0) return 0;
      // A name that starts with what was typed is what people mean.
      final name = d.name.toLowerCase();
      return hits * 10 + (name.startsWith(q) ? 5 : 0) + (name.contains(q) ? 3 : 0);
    }

    final hits = [
      for (final d in widget.places)
        if (score(d) > 0) (score(d), d),
    ]..sort((a, b) {
      final byScore = b.$1.compareTo(a.$1);
      return byScore != 0 ? byScore : (b.$2.reviewCount ?? 0).compareTo(a.$2.reviewCount ?? 0);
    });
    return [for (final (_, d) in hits) d];
  }

  /// Other searches that lead somewhere: the places further down the list,
  /// then the categories and provinces they belong to.
  List<String> _suggestions(List<Destination> matches) {
    if (_query.trim().isEmpty) return const [];
    final words = <String>{
      for (final d in matches.skip(3).take(3)) d.name,
      for (final d in matches.take(4)) d.category,
      for (final d in matches.take(4)) d.province,
    }..removeWhere((w) => w.toLowerCase() == _query.trim().toLowerCase());
    return words.take(5).toList();
  }

  void _run(String query) {
    final q = query.trim();
    if (q.isEmpty) return;
    context.push('${Routes.search}?q=${Uri.encodeQueryComponent(q)}');
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final matches = _matches;
    final suggestions = _suggestions(matches);

    return Column(
      children: [
        _SearchRow(
          controller: _controller,
          onChanged: (v) => setState(() => _query = v),
          onSubmit: () => _run(_controller.text),
          onClear: () => setState(() {
            _controller.clear();
            _query = '';
          }),
        ),
        Expanded(
          child: matches.isEmpty && suggestions.isEmpty
              ? Center(
                  child: Text(s.noResults, style: AppText.sans(14.5, color: AppColors.sand500)),
                )
              : ListView(
                  padding: EdgeInsets.only(bottom: 20 + MediaQuery.paddingOf(context).bottom),
                  children: [
                    for (final d in matches.take(3)) _PlaceRow(destination: d),
                    if (suggestions.isNotEmpty) const SizedBox(height: 6),
                    for (final word in suggestions)
                      _SuggestionRow(word: word, onTap: () => _run(word)),
                  ],
                ),
        ),
      ],
    );
  }
}

/// Back arrow, the words being typed, a way to clear them and the search button.
class _SearchRow extends StatelessWidget {
  const _SearchRow({
    required this.controller,
    required this.onChanged,
    required this.onSubmit,
    required this.onClear,
  });

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
              decoration: BoxDecoration(
                color: AppColors.sand100,
                borderRadius: BorderRadius.circular(16),
              ),
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
  const _PlaceRow({required this.destination});
  final Destination destination;

  @override
  Widget build(BuildContext context) {
    final d = destination;
    final (title, _) = bilingual(context, d.name, d.nameKh);
    return InkWell(
      onTap: () => context.push(Routes.destination(d.region, d.slug)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Row(
          children: [
            SizedBox(
              width: 58,
              height: 58,
              child: AppImage(d.image, radius: BorderRadius.circular(12)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppText.sans(14.5, weight: FontWeight.w700, color: AppColors.sand900),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${d.category}, ${d.province}',
                    style: AppText.sans(12.5, color: AppColors.sand500),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: AppColors.violet.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_forward_rounded, size: 15, color: AppColors.violet),
            ),
          ],
        ),
      ),
    );
  }
}

/// Another search worth running.
class _SuggestionRow extends StatelessWidget {
  const _SuggestionRow({required this.word, required this.onTap});
  final String word;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 12, 16, 12),
        child: Row(
          children: [
            const Icon(Icons.search_rounded, size: 19, color: AppColors.violet),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                word,
                style: AppText.sans(14.5, weight: FontWeight.w500, color: AppColors.sand900),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
