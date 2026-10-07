import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/models.dart';
import '../../data/repositories/travel_repository.dart';
import '../../state/settings_provider.dart';
import '../../widgets/app_image.dart';
import '../../widgets/async_view.dart';
import '../../widgets/common.dart';

/// Every room in one stay: photo, who it sleeps, what it includes and the
/// nightly rate.
class RoomsScreen extends StatelessWidget {
  const RoomsScreen({super.key, required this.region, required this.slug});

  final String region;
  final String slug;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final repo = context.read<TravelRepository>();
    final ref = DestinationRef(region, slug);

    return Scaffold(
      appBar: AppBar(title: Text(s.rooms, style: AppText.display(20)), centerTitle: true),
      body: AsyncView<List<Room>>(
        load: () => repo.getRooms(ref),
        builder: (context, rooms, _) {
          if (rooms.isEmpty) {
            return EmptyState(icon: Icons.bed_outlined, title: s.noRooms, body: s.noRoomsBody);
          }
          return ListView.separated(
            padding: EdgeInsets.fromLTRB(16, 14, 16, 28 + MediaQuery.paddingOf(context).bottom),
            itemCount: rooms.length,
            separatorBuilder: (_, _) => const SizedBox(height: 16),
            itemBuilder: (_, i) => _RoomCard(room: rooms[i], region: region, slug: slug),
          );
        },
      ),
    );
  }
}

/// One room: its photo, the facts about it, what the rate includes and the
/// way into the full details.
class _RoomCard extends StatelessWidget {
  const _RoomCard({required this.room, required this.region, required this.slug});
  final Room room;
  final String region;
  final String slug;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final r = room;
    final price = context.watch<SettingsProvider>().price(r.pricePerNight);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.sand200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 180,
            width: double.infinity,
            child: AppImage(r.image, radius: BorderRadius.circular(14)),
          ),
          const SizedBox(height: 12),
          Text(r.name, style: AppText.sans(18, weight: FontWeight.w700, color: AppColors.sand900)),
          const SizedBox(height: 8),

          // The facts a traveller scans first.
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              _Fact(icon: Icons.person_rounded, label: '${s.maxAdults} ${r.guests} ${s.adultsWord}'),
              if (r.breakfast)
                _Fact(
                  icon: Icons.restaurant_rounded,
                  label: s.breakfastIncluded,
                  color: AppColors.success,
                ),
              if (r.sizeSqm != null)
                _Fact(icon: Icons.open_in_full_rounded, label: _size(r.sizeSqm!)),
            ],
          ),

          if (r.highlights.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [for (final h in r.highlights) _Check(label: h)],
            ),
          ],

          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(price, style: AppText.sans(22, weight: FontWeight.w800, color: AppColors.sand900)),
              const SizedBox(width: 8),
              Text(s.perNight, style: AppText.sans(12.5, color: AppColors.sand500)),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.violet,
                minimumSize: const Size(0, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
              ),
              onPressed: () => context.push(Routes.room(region, slug, r.id)),
              child: Text(
                s.roomDetails,
                style: AppText.sans(15, weight: FontWeight.w700, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "60 m²/646 ft²".
String _size(int sqm) => '$sqm m²/${(sqm * 10.7639).round()} ft²';

/// One fact with its symbol.
class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.label, this.color});
  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: color ?? AppColors.sand700),
        const SizedBox(width: 5),
        Text(
          label,
          style: AppText.sans(12.5, weight: FontWeight.w500, color: color ?? AppColors.sand700),
        ),
      ],
    );
  }
}

/// One thing the rate includes, with a tick.
class _Check extends StatelessWidget {
  const _Check({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.sand100,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_rounded, size: 13, color: AppColors.sand600),
          const SizedBox(width: 5),
          Text(label, style: AppText.sans(11.5, color: AppColors.sand700)),
        ],
      ),
    );
  }
}
