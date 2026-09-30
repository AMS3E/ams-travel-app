import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/models.dart';
import '../../data/repositories/travel_repository.dart';
import '../../widgets/async_view.dart';
import '../../widgets/browse_bar.dart';
import '../../widgets/place_list_row.dart';


/// Everything under "Explore by Popular", in one list.
class PopularScreen extends StatelessWidget {
  const PopularScreen({super.key});

  Future<List<Destination>> _load(TravelRepository repo) async {
    final places = await repo.getDestinations();

    places.sort((a, b) {
      final byFeatured = (b.featured ? 1 : 0).compareTo(a.featured ? 1 : 0);
      if (byFeatured != 0) return byFeatured;
      final byRating = (b.rating ?? 0).compareTo(a.rating ?? 0);
      return byRating != 0 ? byRating : (b.reviewCount ?? 0).compareTo(a.reviewCount ?? 0);
    });

    return places;
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.read<TravelRepository>();
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: AsyncView<List<Destination>>(
          load: () => _load(repo),
          builder: (context, places, _) => _Body(places: places),
        ),
      ),
    );
  }
}

class _Body extends StatefulWidget {
  const _Body({required this.places});

  /// Every place, the best known first.
  final List<Destination> places;

  @override
  State<_Body> createState() => _BodyState();
}

class _BodyState extends State<_Body> {
  /// The best known places, in one list.
  List<Destination> get _popular =>
      widget.places.where((d) => d.featured || (d.rating ?? 0) >= 4.6).toList();

  @override
  Widget build(BuildContext context) {
    final places = _popular;
    // The chips suggest what other people look for: the best known places,
    // then the provinces they sit in.
    final keywords = <String>{
      for (final d in places.take(2)) d.name,
      for (final d in places.take(12)) d.province,
    }.take(6).toList();

    return Column(
      children: [
        BrowseSearchBar(hint: S.of(context).popularDestinations, onWhite: true),
        const SizedBox(height: 12),
        SizedBox(
          height: 34,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: keywords.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, i) => _Keyword(word: keywords[i]),
          ),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: ListView(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 20 + MediaQuery.paddingOf(context).bottom),
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.sand200),
                ),
                child: Column(
                  children: [for (final d in places) PlaceListRow(destination: d)],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// One thing other people search for.
class _Keyword extends StatelessWidget {
  const _Keyword({required this.word});
  final String word;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(99),
      onTap: () => context.push('${Routes.search}?q=${Uri.encodeQueryComponent(word)}'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: AppColors.sand200),
        ),
        child: Row(
          children: [
            const Icon(Icons.place_outlined, size: 15, color: AppColors.sand500),
            const SizedBox(width: 5),
            Text(
              word.toLowerCase(),
              style: AppText.sans(13, weight: FontWeight.w500, color: AppColors.sand800),
            ),
          ],
        ),
      ),
    );
  }
}
