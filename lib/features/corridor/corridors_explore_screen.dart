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
import '../../widgets/browse_bar.dart';

/// The tourism corridors, with the stops each one takes in.
class CorridorsExploreScreen extends StatelessWidget {
  const CorridorsExploreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = context.read<TravelRepository>();
    final s = S.of(context);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: AsyncView<List<Corridor>>(
          load: repo.getCorridors,
          builder: (context, corridors, _) => Column(
            children: [
              BrowseSearchBar(hint: s.exploreCorridors),
              const SizedBox(height: 14),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 20 + MediaQuery.paddingOf(context).bottom),
                  children: [
                    Container(
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.sand200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.tourismCorridors,
                            style: AppText.sans(16, weight: FontWeight.w700, color: AppColors.sand900),
                          ),
                          const SizedBox(height: 6),
                          for (final c in corridors) _CorridorRow(corridor: c),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One corridor: photo, name, the stops along it, and a way in.
class _CorridorRow extends StatelessWidget {
  const _CorridorRow({required this.corridor});
  final Corridor corridor;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final c = corridor;

    return InkWell(
      onTap: () => context.push(Routes.corridor(c.slug)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 54, height: 54, child: AppImage(c.image, radius: BorderRadius.circular(12))),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    c.name,
                    style: AppText.sans(13.5, weight: FontWeight.w700, color: AppColors.sand900),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    c.stops.map((e) => e.name).join(', '),
                    style: AppText.sans(11, color: AppColors.sand500, height: 1.35),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.verified_rounded, size: 12, color: Color(0xFF34D399)),
                      const SizedBox(width: 4),
                      Text(
                        s.recommendByTraveler,
                        style: AppText.sans(10.5, color: AppColors.sand500),
                      ),
                    ],
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
