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
import 'contact_card.dart';

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

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _Gallery(room: room)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(room.name, style: AppText.display(24)),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () => context.push(Routes.destination(stay.region, stay.slug)),
                    child: Row(
                      children: [
                        const Icon(Icons.hotel_rounded, size: 16, color: AppColors.sand500),
                        const SizedBox(width: 5),
                        Text(
                          stay.name,
                          style: AppText.sans(13.5, weight: FontWeight.w600, color: AppColors.brand600),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _Fact(icon: Icons.person_outline_rounded, text: '${room.guests} ${s.guests}'),
                      if (room.beds != null) _Fact(icon: Icons.bed_outlined, text: room.beds!),
                      if (room.sizeSqm != null) _Fact(icon: Icons.crop_free_rounded, text: '${room.sizeSqm} m²'),
                      _Fact(
                        icon: room.available ? Icons.event_available_rounded : Icons.event_busy_rounded,
                        text: room.available ? s.available : s.soldOut,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (room.description != null)
            SliverToBoxAdapter(
              child: _Card(
                title: s.description,
                child: Text(
                  room.description!,
                  style: AppText.sans(14.5, color: AppColors.sand700, height: 1.6),
                ),
              ),
            ),
          if (room.amenities.isNotEmpty)
            SliverToBoxAdapter(
              child: _Card(
                title: s.whatsIncluded,
                child: Column(
                  children: [
                    for (final a in room.amenities)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 7),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_outline_rounded, size: 19, color: AppColors.success),
                            const SizedBox(width: 12),
                            Expanded(child: Text(a, style: AppText.sans(14.5, color: AppColors.sand800))),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          SliverToBoxAdapter(
            child: _Card(
              title: s.policies,
              child: Column(
                children: [
                  _PolicyLine(label: s.checkIn, value: '2PM'),
                  _PolicyLine(label: s.checkOut, value: '12PM'),
                  _PolicyLine(label: s.cancellation, value: s.contactForPolicy),
                ],
              ),
            ),
          ),
          // Same contacts as the stay — a guest asking about this room does
          // not have to go back a page to find them.
          SliverToBoxAdapter(
            child: ContactCard(
              destination: stay,
              price: context.watch<SettingsProvider>().price(room.pricePerNight),
            ),
          ),
          SliverToBoxAdapter(child: SizedBox(height: 28 + MediaQuery.paddingOf(context).bottom)),
        ],
      ),
    );
  }
}

/// Swipeable room photos with a counter and the back button.
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

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.sand200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.sand500),
          const SizedBox(width: 6),
          Text(text, style: AppText.sans(13, color: AppColors.sand700)),
        ],
      ),
    );
  }
}

class _PolicyLine extends StatelessWidget {
  const _PolicyLine({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(child: Text(label, style: AppText.sans(14.5, color: AppColors.sand800))),
          Text(value, style: AppText.sans(13.5, weight: FontWeight.w600, color: AppColors.sand600)),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radius),
          border: Border.all(color: AppColors.sand200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppText.display(17)),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}
