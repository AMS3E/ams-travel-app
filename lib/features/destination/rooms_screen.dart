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
      appBar: AppBar(title: Text(s.rooms, style: AppText.display(24))),
      body: AsyncView<(Destination, List<Room>)>(
        load: () => (repo.getDestination(region, slug), repo.getRooms(ref)).wait,
        builder: (context, data, _) {
          final (stay, rooms) = data;
          if (rooms.isEmpty) {
            return EmptyState(icon: Icons.bed_outlined, title: s.noRooms, body: s.noRoomsBody);
          }
          return ListView.separated(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 28 + MediaQuery.paddingOf(context).bottom),
            itemCount: rooms.length + 1,
            separatorBuilder: (_, _) => const SizedBox(height: 16),
            itemBuilder: (context, i) => i == 0
                ? Text(
                    stay.name,
                    style: AppText.sans(15, weight: FontWeight.w600, color: AppColors.sand600),
                  )
                : _RoomCard(stay: stay, room: rooms[i - 1]),
          );
        },
      ),
    );
  }
}

class _RoomCard extends StatelessWidget {
  const _RoomCard({required this.stay, required this.room});
  final Destination stay;
  final Room room;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppColors.sand200),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 170, width: double.infinity, child: AppImage(room.image)),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(room.name, style: AppText.display(19)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 14,
                  runSpacing: 6,
                  children: [
                    _Fact(icon: Icons.person_outline_rounded, text: '${room.guests} ${s.guests}'),
                    if (room.beds != null) _Fact(icon: Icons.bed_outlined, text: room.beds!),
                    if (room.sizeSqm != null) _Fact(icon: Icons.crop_free_rounded, text: '${room.sizeSqm} m²'),
                    if (!room.available) _Fact(icon: Icons.event_busy_rounded, text: s.soldOut),
                  ],
                ),
                if (room.amenities.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final a in room.amenities)
                        Pill(a, icon: Icons.check_rounded, color: AppColors.brand700, background: AppColors.brand50),
                    ],
                  ),
                ],
                const SizedBox(height: 14),
                Row(
                  children: [
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: context.watch<SettingsProvider>().price(room.pricePerNight),
                            style: AppText.display(20),
                          ),
                          TextSpan(
                            text: ' / ${s.night}',
                            style: AppText.sans(13, color: AppColors.sand500),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.sand900,
                        minimumSize: const Size(0, 44),
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                      ),
                      onPressed: () => context.push(Routes.room(stay.region, stay.slug, room.id)),
                      child: Text(s.roomDetails),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppColors.sand500),
        const SizedBox(width: 5),
        Text(text, style: AppText.sans(13, color: AppColors.sand600)),
      ],
    );
  }
}
