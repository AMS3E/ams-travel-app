import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/models.dart';
import '../../data/repositories/travel_repository.dart';
import '../../state/travel_preferences.dart';
import '../../widgets/app_image.dart';
import '../../widgets/async_view.dart';

const _violet = Color(0xFF5B2EE5);

/// Shown in the footer; keep in step with `version:` in pubspec.yaml.
const appVersionLabel = 'AMS TRAVEL Version 1.0.0(1)';

/// Last onboarding step: what the traveller picked, ready to explore.
class ReadyStep extends StatelessWidget {
  const ReadyStep({super.key, required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final repo = context.read<TravelRepository>();
    final categories = context.watch<TravelPreferences>().categories.toList();

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 76),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              s.readyTitle,
              style: AppText.sans(30, weight: FontWeight.w800, color: Colors.white, height: 1.2),
            ),
          ),
          const SizedBox(height: 26),
          Expanded(
            child: AsyncView<List<Destination>>(
              // Places from the chosen interests; the featured ones otherwise.
              load: () async {
                final places = await repo.getDestinations(categories: categories.isEmpty ? null : categories);
                final picked = places.where((d) => d.featured || d.rating != null).toList();
                return (picked.isEmpty ? places : picked).take(8).toList();
              },
              loading: const SizedBox.shrink(),
              builder: (context, places, _) => ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: places.length,
                separatorBuilder: (_, _) => const SizedBox(width: 14),
                itemBuilder: (_, i) => _ReadyCard(destination: places[i]),
              ),
            ),
          ),
          const SizedBox(height: 26),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: _violet,
                  minimumSize: const Size(0, 60),
                  shape: const StadiumBorder(),
                ),
                onPressed: onStart,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        s.startExploring,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.sans(16, weight: FontWeight.w700, color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Icon(Icons.arrow_forward_rounded, size: 19, color: Colors.white),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              appVersionLabel,
              style: AppText.sans(12, weight: FontWeight.w500, color: Colors.white.withValues(alpha: 0.45)),
            ),
          ),
          const SizedBox(height: 44),
        ],
      ),
    );
  }
}

/// Tall photo card: the place, with its category underneath.
class _ReadyCard extends StatelessWidget {
  const _ReadyCard({required this.destination});
  final Destination destination;

  @override
  Widget build(BuildContext context) {
    final d = destination;
    return SizedBox(
      width: 226,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          fit: StackFit.expand,
          children: [
            AppImage(d.image),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.35, 1],
                  colors: [Color(0x00000000), Color(0xCC000000)],
                ),
              ),
            ),
            Positioned(
              left: 18,
              right: 18,
              bottom: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    d.name,
                    style: AppText.sans(19, weight: FontWeight.w700, color: Colors.white, height: 1.25),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    d.category,
                    style: AppText.sans(13.5, color: Colors.white.withValues(alpha: 0.75)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
