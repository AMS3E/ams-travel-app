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
import 'booking.dart';
import 'stay_screen.dart' show amenitiesBySlug, amenityGroupIcon, amenityGroupsOf;

/// Every room in one stay (`GET /stay-rooms?stayId=`): photo, who it sleeps,
/// what it includes, and the quote's total for the chosen nights and guests
/// (`GET /stay-rooms/quote`).
class RoomsScreen extends StatefulWidget {
  const RoomsScreen({super.key, required this.stayId});
  final String stayId;

  @override
  State<RoomsScreen> createState() => _RoomsScreenState();
}

class _RoomsScreenState extends State<RoomsScreen> {
  /// The nights and guests chosen on the stay's page; they are changed
  /// there, not here.
  late final _booking = Booking.forStay(widget.stayId);

  Future<(List<StayRoom>, StayQuote?, Map<String, Amenity>)> _load(AmsApi api) async {
    final (r, q, a) = await (
      api.rooms(widget.stayId),
      _booking.quote(api, widget.stayId).orNull,
      // Without names the cards show the slugs as words.
      api.amenities().or(const []),
    ).wait;
    return (r, q, amenitiesBySlug(a));
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final api = context.read<AmsApi>();

    return Scaffold(
      appBar: AppBar(title: Text(s.rooms, style: AppText.display(20)), centerTitle: true),
      body: AsyncView<(List<StayRoom>, StayQuote?, Map<String, Amenity>)>(
        load: () => _load(api),
        builder: (context, data, _) {
          final (rooms, quote, amenities) = data;
          if (rooms.isEmpty) {
            return EmptyState(icon: Icons.bed_outlined, title: s.noRooms, body: s.noRoomsBody);
          }
          return ListView.separated(
            padding: EdgeInsets.fromLTRB(16, 14, 16, bottomInset(context)),
            itemCount: rooms.length,
            separatorBuilder: (_, _) => const SizedBox(height: 16),
            itemBuilder: (_, i) => _RoomCard(
              stayId: widget.stayId,
              room: rooms[i],
              quote: quote?.forRoom(rooms[i].id),
              amenities: amenities,
            ),
          );
        },
      ),
    );
  }
}

/// "60 m²/646 ft²".
String roomSize(double sqm) => '${sqm.round()} m²/${(sqm * 10.7639).round()} ft²';

/// Who a room takes: "Sleeps 3", or "Max 2 adults" when only that is known.
String? roomCapacity(S s, StayRoom r) {
  if (r.sleeps != null && r.sleeps! > 0) return s.fill(s.sleepsGuests, {'n': r.sleeps!});
  if (r.maxAdults != null) return '${s.maxAdults} ${r.maxAdults} ${s.adultsWord}';
  return null;
}

/// One room: its photo, the facts about it, the quote and the way into the
/// full details.
class _RoomCard extends StatelessWidget {
  const _RoomCard({required this.stayId, required this.room, required this.quote, required this.amenities});
  final String stayId;
  final StayRoom room;
  final RoomQuote? quote;

  /// `GET /amenities` by slug, for the groups.
  final Map<String, Amenity> amenities;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final r = room;
    final capacity = roomCapacity(s, r);
    final groups = amenityGroupsOf(r.amenities, amenities);

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
            child: AppImage(r.photoUrls.isEmpty ? '' : r.photoUrls.first, radius: BorderRadius.circular(14)),
          ),
          const SizedBox(height: 12),
          Text(
            r.name,
            style: AppText.sans(18, weight: FontWeight.w700, color: AppColors.sand900),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              if (capacity != null) RoomFact(icon: Icons.person_rounded, label: capacity),
              if (r.breakfastIncluded)
                RoomFact(icon: Icons.restaurant_rounded, label: s.breakfastIncluded, color: AppColors.success),
              if (r.sizeSqm != null) RoomFact(icon: Icons.open_in_full_rounded, label: roomSize(r.sizeSqm!)),
            ],
          ),
          // What kinds of things are in the room; the items are on its page.
          if (groups.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(spacing: 6, runSpacing: 6, children: [for (final g in groups) _AmenityChip(group: g)]),
          ],
          const SizedBox(height: 14),
          RoomQuoteView(quote: quote),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.violet,
                minimumSize: const Size(0, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
              ),
              onPressed: () => context.push(Routes.stayRoom(stayId, r.id)),
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

/// One amenity group on a room card: its symbol and name in a small pill.
class _AmenityChip extends StatelessWidget {
  const _AmenityChip({required this.group});
  final String group;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.violet.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(amenityGroupIcon(group), size: 14, color: AppColors.violet),
          const SizedBox(width: 5),
          Text(
            group,
            style: AppText.sans(12, weight: FontWeight.w600, color: AppColors.violet),
          ),
        ],
      ),
    );
  }
}

/// One fact with its symbol.
class RoomFact extends StatelessWidget {
  const RoomFact({super.key, required this.icon, required this.label, this.color});
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
