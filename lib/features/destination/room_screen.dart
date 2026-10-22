import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/html_text.dart';
import '../../data/api/ams_api.dart';
import '../../widgets/app_image.dart';
import '../../widgets/async_view.dart';
import '../../widgets/common.dart';
import '../../widgets/hero_app_bar.dart';
import 'booking.dart';
import 'contact_card.dart';
import 'place_view.dart';
import 'rooms_screen.dart';
import 'stay_screen.dart';

class _RoomData {
  const _RoomData({required this.stay, required this.room, this.amenities = const {}});
  final StayDetail stay;
  final StayRoom? room;
  final Map<String, Amenity> amenities;
}

/// One room: its photos, capacity, size, breakfast, amenities by group,
/// description, and its own quote (`GET /stay-rooms/{id}/quote`) for the
/// nights and guests chosen on the stay. The stay's phone and website close
/// the page: the app takes no bookings.
class RoomScreen extends StatefulWidget {
  const RoomScreen({super.key, required this.stayId, required this.roomId});

  final String stayId;
  final String roomId;

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen> {
  /// The nights and guests chosen on the stay's page; they are changed
  /// there, not here.
  late final _booking = Booking.forStay(widget.stayId);

  Future<_RoomData> _load(AmsApi api) async {
    final (stay, rooms, amenities) = await (
      api.stay(widget.stayId),
      api.rooms(widget.stayId),
      api.amenities().or(const []),
    ).wait;
    return _RoomData(
      stay: stay,
      room: rooms.where((r) => r.id == widget.roomId).firstOrNull,
      amenities: amenitiesBySlug(amenities),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final api = context.read<AmsApi>();
    return AsyncView<_RoomData>(
      load: () => _load(api),
      loading: const Scaffold(body: LoadingView()),
      builder: (context, data, _) {
        final room = data.room;
        if (room == null) {
          return Scaffold(
            appBar: AppBar(title: Text(s.roomDetails, style: AppText.display(20)), centerTitle: true),
            body: EmptyState(icon: Icons.bed_outlined, title: s.noRooms, body: s.noRoomsBody),
          );
        }
        return _RoomView(stay: data.stay, room: room, amenities: data.amenities, booking: _booking);
      },
    );
  }
}

class _RoomView extends StatelessWidget {
  const _RoomView({required this.stay, required this.room, required this.amenities, required this.booking});

  final StayDetail stay;
  final StayRoom room;
  final Map<String, Amenity> amenities;
  final Booking booking;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final r = room;
    final about = htmlToText(r.description);
    final capacity = roomCapacity(s, r);
    final beds = r.beds.entries.map((e) => '${e.value} ${labelOf(e.key).toLowerCase()}').join(', ');

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          _Gallery(photos: r.photoUrls),
          SliverPadding(
            padding: EdgeInsets.only(bottom: bottomInset(context)),
            sliver: SliverList.list(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Text(
                    r.name,
                    style: AppText.sans(20, weight: FontWeight.w700, color: AppColors.sand900),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: _RoomQuoteLoader(booking: booking, roomId: r.id),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: Text(s.priceNoBooking, style: AppText.sans(12, color: AppColors.sand500)),
                ),

                // What the room is known for, in one line of facts.
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
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
                      if (capacity != null) RoomFact(icon: Icons.person_rounded, label: capacity),
                      if (r.maxChildren != null && r.maxChildren! > 0)
                        RoomFact(
                          icon: Icons.child_care_rounded,
                          label: s.fill(s.maxChildrenLabel, {'n': r.maxChildren!}),
                        ),
                      if (r.sizeSqm != null) RoomFact(icon: Icons.open_in_full_rounded, label: roomSize(r.sizeSqm!)),
                      if (beds.isNotEmpty) RoomFact(icon: Icons.bed_rounded, label: beds),
                      if (r.view != null && r.view!.isNotEmpty)
                        RoomFact(icon: Icons.photo_camera_outlined, label: labelOf(r.view!)),
                      if (r.breakfastIncluded)
                        RoomFact(icon: Icons.restaurant_rounded, label: s.breakfastIncluded, color: AppColors.success),
                    ],
                  ),
                ),

                if (about.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.violet.withValues(alpha: 0.25)),
                    ),
                    child: Text(about, style: AppText.sans(13, color: AppColors.sand700, height: 1.6)),
                  ),

                // Everything in the room, under the heading it belongs to.
                if (r.amenities.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                    child: AmenityGroups(slugs: r.amenities, bySlug: amenities),
                  ),

                ContactButtons(phone: stay.phone, website: stay.website),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Gallery extends StatefulWidget {
  const _Gallery({required this.photos});
  final List<String> photos;

  @override
  State<_Gallery> createState() => _GalleryState();
}

class _GalleryState extends State<_Gallery> {
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final photos = widget.photos;
    return HeroAppBar(
      height: 300,
      background: Stack(
        fit: StackFit.expand,
        children: [
          if (photos.isEmpty)
            const AppImage('')
          else
            PageView.builder(
              itemCount: photos.length,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (_, i) => AppImage(photos[i]),
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

/// The room's own quote for the chosen nights and guests, asked once per
/// choice.
class _RoomQuoteLoader extends StatefulWidget {
  const _RoomQuoteLoader({required this.booking, required this.roomId});
  final Booking booking;
  final String roomId;

  @override
  State<_RoomQuoteLoader> createState() => _RoomQuoteLoaderState();
}

class _RoomQuoteLoaderState extends State<_RoomQuoteLoader> {
  late final Future<RoomQuote> _quote = widget.booking.roomQuote(context.read<AmsApi>(), widget.roomId);

  @override
  Widget build(BuildContext context) => FutureBuilder<RoomQuote>(
    future: _quote,
    builder: (context, snap) => snap.connectionState != ConnectionState.done
        ? const Align(
            alignment: Alignment.centerLeft,
            child: SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)),
          )
        : RoomQuoteView(quote: snap.data, large: true),
  );
}
