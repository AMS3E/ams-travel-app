import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/models.dart';
import '../../data/repositories/travel_repository.dart';
import '../../widgets/app_image.dart';
import '../../widgets/async_view.dart';
import '../../widgets/common.dart';

/// One room: its photos, who it sleeps, what it includes and the rate.
class RoomScreen extends StatelessWidget {
  const RoomScreen({super.key, required this.region, required this.slug, required this.roomId});

  final String region;
  final String slug;
  final String roomId;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final repo = context.read<TravelRepository>();
    return Scaffold(
      body: AsyncView<(Destination, List<Room>)>(
        load: () => (repo.getDestination(region, slug), repo.getRooms(DestinationRef(region, slug))).wait,
        loading: const Scaffold(body: LoadingView()),
        builder: (context, data, _) {
          final (stay, rooms) = data;
          final room = rooms.where((r) => r.id == roomId).firstOrNull;
          if (room == null) {
            return EmptyState(icon: Icons.bed_outlined, title: s.noRooms, body: s.noRoomsBody);
          }
          return _RoomView(stay: stay, room: room);
        },
      ),
    );
  }
}

class _RoomView extends StatelessWidget {
  const _RoomView({required this.stay, required this.room});
  final Destination stay;
  final Room room;

  /// "60 m²/646 ft²".
  static String _size(int sqm) => '$sqm m²/${(sqm * 10.7639).round()} ft²';

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final r = room;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text(s.roomDetails, style: AppText.display(20)),
        centerTitle: true,
      ),
      body: ListView(
        padding: EdgeInsets.only(bottom: 28 + MediaQuery.paddingOf(context).bottom),
        children: [
          _Gallery(room: r),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Text(r.name, style: AppText.sans(20, weight: FontWeight.w700, color: AppColors.sand900)),
          ),

          // What the room is known for, in one line of facts.
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            child: Text(
              s.featuredAmenities,
              style: AppText.sans(15.5, weight: FontWeight.w700, color: AppColors.violet),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
            child: Wrap(
              spacing: 14,
              runSpacing: 8,
              children: [
                if (r.sizeSqm != null) _Fact(icon: Icons.open_in_full_rounded, label: _size(r.sizeSqm!)),
                if (r.beds != null) _Fact(icon: Icons.bed_rounded, label: r.beds!),
                if (r.view != null) _Fact(icon: Icons.photo_camera_outlined, label: r.view!),
                if (!r.smoking) _Fact(icon: Icons.smoke_free_rounded, label: s.nonSmoking),
                for (final a in r.amenities.take(2)) _Fact(icon: Icons.check_rounded, label: a),
              ],
            ),
          ),

          if (r.description != null)
            Container(
              margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.violet.withValues(alpha: 0.25)),
              ),
              child: Text(
                r.description!,
                style: AppText.sans(13, color: AppColors.sand700, height: 1.6),
              ),
            ),

          // Everything in the room, under the heading it belongs to.
          for (final group in r.amenityGroups.entries) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
              child: Row(
                children: [
                  Icon(_groupIcon(group.key), size: 18, color: AppColors.violet),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      group.key,
                      style: AppText.sans(15.5, weight: FontWeight.w700, color: AppColors.violet),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
              child: Text(
                group.value.join('  ·  '),
                style: AppText.sans(12.5, color: AppColors.sand600, height: 1.6),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A symbol for each group of amenities.
IconData _groupIcon(String group) => switch (group) {
  'Kitchen' => Icons.kitchen_rounded,
  'Entertainment' => Icons.tv_rounded,
  'Comforts' => Icons.weekend_rounded,
  'Clothing and laundry' => Icons.checkroom_rounded,
  'For the kids' => Icons.child_friendly_rounded,
  'Safety and security features' => Icons.verified_user_rounded,
  'Bathroom and toiletries' => Icons.bathtub_rounded,
  'Dining, drinking, and snacking' => Icons.local_cafe_rounded,
  'Layout and furnishings' => Icons.chair_rounded,
  _ => Icons.check_circle_outline_rounded,
};

/// One fact with its symbol.
class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: AppColors.sand700),
        const SizedBox(width: 5),
        Text(label, style: AppText.sans(12, weight: FontWeight.w500, color: AppColors.sand700)),
      ],
    );
  }
}

class _Gallery extends StatefulWidget {
  const _Gallery({required this.room});
  final Room room;

  @override
  State<_Gallery> createState() => _GalleryState();
}

class _GalleryState extends State<_Gallery> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final photos = widget.room.gallery;
    return SizedBox(
      height: 300,
      child: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: photos.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (_, i) => AppImage(photos[i]),
          ),
          Positioned(
            top: MediaQuery.paddingOf(context).top + 8,
            left: 16,
            child: GlassIconButton(
              icon: Icons.arrow_back_rounded,
              tooltip: s.back,
              onPressed: () => context.pop(),
            ),
          ),
          if (photos.length > 1)
            Positioned(
              right: 16,
              bottom: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${_page + 1}/${photos.length}',
                  style: AppText.sans(12.5, weight: FontWeight.w600, color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }
}



