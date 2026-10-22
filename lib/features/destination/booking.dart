import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/dates.dart';
import '../../data/api/ams_api.dart';
import 'place_view.dart';

/// What a traveller is asking a stay about: which nights, and who is coming.
/// It drives the price preview (`GET /stay-rooms/quote`); nothing is booked.
class Booking {
  const Booking({required this.nights, required this.rooms, required this.adults, required this.children});

  final DateTimeRange nights;
  final int rooms;
  final int adults;
  final int children;

  int get nightCount => nights.end.difference(nights.start).inDays;

  Booking copyWith({DateTimeRange? nights, int? rooms, int? adults, int? children}) => Booking(
    nights: nights ?? this.nights,
    rooms: rooms ?? this.rooms,
    adults: adults ?? this.adults,
    children: children ?? this.children,
  );

  /// Tonight to tomorrow, one room, two adults — where everyone starts.
  factory Booking.initial() {
    final from = Dates.dateOnly(DateTime.now());
    return Booking(
      nights: DateTimeRange(start: from, end: from.add(const Duration(days: 1))),
      rooms: 1,
      adults: 2,
      children: 0,
    );
  }

  bool get isDefault {
    final i = Booking.initial();
    return nights == i.nights && rooms == i.rooms && adults == i.adults && children == i.children;
  }

  /// "14 → 15".
  String get nightsLabel => '${nights.start.day} → ${nights.end.day}';

  /// The choice made on a stay's page, kept while the app runs so its rooms
  /// and room pages quote the same nights and guests.
  static final _byStay = <String, Booking>{};

  static Booking forStay(String stayId) {
    final b = _byStay[stayId];
    // Nights that have already begun are no longer on offer.
    if (b == null || b.nights.start.isBefore(Booking.initial().nights.start)) return Booking.initial();
    return b;
  }

  static void remember(String stayId, Booking b) => _byStay[stayId] = b;

  /// The quote for the whole stay with this choice.
  Future<StayQuote> quote(AmsApi api, String stayId) =>
      api.quote(stayId, checkIn: nights.start, checkOut: nights.end, rooms: rooms, adults: adults, children: children);

  /// The quote for one room with this choice.
  Future<RoomQuote> roomQuote(AmsApi api, String roomId) => api.roomQuote(
    roomId,
    checkIn: nights.start,
    checkOut: nights.end,
    rooms: rooms,
    adults: adults,
    children: children,
  );
}

/// Opens the editor for the nights (or, with [onGuests], who is coming).
/// The new choice, remembered for [stayId], or null when the sheet was closed.
Future<Booking?> editBooking(BuildContext context, String stayId, Booking booking, {required bool onGuests}) async {
  final result = await showModalBottomSheet<Booking>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
    builder: (_) => _EditDetails(booking: booking, onGuests: onGuests),
  );
  if (result != null) Booking.remember(stayId, result);
  return result;
}

/// "View booking details" on a stay page: the two fields that open the
/// editor, and once a choice is applied the stay card with the quote's total.
class BookingPanel extends StatefulWidget {
  const BookingPanel({super.key, required this.stayId});
  final String stayId;

  @override
  State<BookingPanel> createState() => _BookingPanelState();
}

class _BookingPanelState extends State<BookingPanel> {
  late Booking _booking = Booking.forStay(widget.stayId);

  /// The stay card appears once the traveller has applied a choice.
  late bool _applied = !_booking.isDefault;

  Future<void> _edit({required bool onGuests}) async {
    final result = await editBooking(context, widget.stayId, _booking, onGuests: onGuests);
    if (result != null) {
      setState(() {
        _booking = result;
        _applied = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.viewBookingDetails, style: AppText.display(17)),
          const SizedBox(height: 12),
          BookingFields(
            booking: _booking,
            onNights: () => _edit(onGuests: false),
            onGuests: () => _edit(onGuests: true),
          ),
          if (_applied) ...[
            const SizedBox(height: 16),
            _StayCard(key: ValueKey(_booking), booking: _booking, stayId: widget.stayId),
          ],
        ],
      ),
    );
  }
}

/// The two rounded fields: the nights on the left, who is coming on the right.
class BookingFields extends StatelessWidget {
  const BookingFields({
    super.key,
    required this.booking,
    required this.onNights,
    required this.onGuests,
    this.activeIndex,
  });

  final Booking booking;
  final VoidCallback onNights;
  final VoidCallback onGuests;

  /// In the editor, the field being edited keeps its colours while the other
  /// one fades back.
  final int? activeIndex;

  @override
  Widget build(BuildContext context) {
    final b = booking;
    return Row(
      children: [
        Expanded(
          child: _Field(
            onTap: onNights,
            dimmed: activeIndex == 1,
            children: [
              const Icon(Icons.calendar_month_rounded, size: 17, color: AppColors.sunset500),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  b.nightsLabel,
                  style: AppText.sans(13.5, weight: FontWeight.w600, color: AppColors.sand900),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _Field(
            onTap: onGuests,
            dimmed: activeIndex == 0,
            children: [
              const Icon(Icons.bed_rounded, size: 17, color: AppColors.sunset500),
              const SizedBox(width: 5),
              Text(
                '${b.rooms}',
                style: AppText.sans(13.5, weight: FontWeight.w600, color: AppColors.sand900),
              ),
              const SizedBox(width: 10),
              const Icon(Icons.person_rounded, size: 17, color: AppColors.violet),
              const SizedBox(width: 5),
              Text(
                '${b.adults}',
                style: AppText.sans(13.5, weight: FontWeight.w600, color: AppColors.sand900),
              ),
              const SizedBox(width: 10),
              const Icon(Icons.child_care_rounded, size: 17, color: AppColors.sunset500),
              const SizedBox(width: 5),
              Text(
                '${b.children}',
                style: AppText.sans(13.5, weight: FontWeight.w600, color: AppColors.sand900),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// One of the two fields, outlined in the sunset-to-violet sweep.
class _Field extends StatelessWidget {
  const _Field({required this.children, required this.onTap, this.dimmed = false});
  final List<Widget> children;
  final VoidCallback onTap;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final alpha = dimmed ? 0.25 : 0.6;
    return InkWell(
      borderRadius: BorderRadius.circular(99),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(1.4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(99),
          gradient: LinearGradient(
            colors: [
              AppColors.sunset500.withValues(alpha: alpha),
              AppColors.violet.withValues(alpha: alpha),
            ],
          ),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(99)),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: children),
        ),
      ),
    );
  }
}

/// The sheet behind both fields: a month to pick the nights in, or the three
/// counters for who is coming.
class _EditDetails extends StatefulWidget {
  const _EditDetails({required this.booking, required this.onGuests});
  final Booking booking;
  final bool onGuests;

  @override
  State<_EditDetails> createState() => _EditDetailsState();
}

class _EditDetailsState extends State<_EditDetails> {
  late Booking _draft = widget.booking;
  late bool _guests = widget.onGuests;
  late DateTime _month = DateTime(_draft.nights.start.year, _draft.nights.start.month);

  void _pickDay(DateTime day) {
    final from = _draft.nights.start;
    setState(() {
      // The first tap after a finished range starts a new one.
      final restart = _draft.nightCount > 0 || !day.isAfter(from);
      _draft = _draft.copyWith(
        nights: DateTimeRange(start: restart ? day : from, end: day),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final nights = _draft.nightCount;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.92),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(color: AppColors.sand300, borderRadius: BorderRadius.circular(99)),
                ),
                const SizedBox(height: 14),
                Text(s.editDetails, style: AppText.display(20)),
                const SizedBox(height: 18),
                BookingFields(
                  booking: _draft,
                  activeIndex: _guests ? 1 : 0,
                  onNights: () => setState(() => _guests = false),
                  onGuests: () => setState(() => _guests = true),
                ),
                const SizedBox(height: 16),
                if (_guests)
                  _GuestCard(booking: _draft, onChanged: (b) => setState(() => _draft = b))
                else ...[
                  _Month(
                    month: _month,
                    range: _draft.nights,
                    onMonth: (m) => setState(() => _month = m),
                    onDay: _pickDay,
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(color: AppColors.sunset500),
                    ),
                    child: Text(
                      '$nights ${nights == 1 ? s.nightSelected : s.nightsSelected}',
                      style: AppText.sans(13.5, weight: FontWeight.w600, color: AppColors.sunset500),
                    ),
                  ),
                ],
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 50),
                          side: const BorderSide(color: AppColors.sand200),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
                        ),
                        onPressed: _draft.isDefault
                            ? null
                            : () => setState(() {
                                _draft = Booking.initial();
                                _month = DateTime(_draft.nights.start.year, _draft.nights.start.month);
                              }),
                        child: Text(
                          s.reset,
                          style: AppText.sans(15, weight: FontWeight.w600, color: AppColors.sand400),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.sunset500,
                          minimumSize: const Size(0, 50),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
                        ),
                        onPressed: nights < 1 ? null : () => Navigator.of(context).pop(_draft),
                        child: Text(
                          s.apply,
                          style: AppText.sans(15, weight: FontWeight.w700, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One month, with the chosen nights marked.
class _Month extends StatelessWidget {
  const _Month({required this.month, required this.range, required this.onMonth, required this.onDay});

  final DateTime month;
  final DateTimeRange range;
  final ValueChanged<DateTime> onMonth;
  final ValueChanged<DateTime> onDay;

  static const _weekdays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month);
    final days = DateTime(month.year, month.month + 1, 0).day;
    final lead = first.weekday % 7; // Sunday first
    final from = Dates.dateOnly(DateTime.now());

    return Column(
      children: [
        Row(
          children: [
            IconButton(
              onPressed: () => onMonth(DateTime(month.year, month.month - 1)),
              icon: const Icon(Icons.chevron_left_rounded),
              color: AppColors.sand700,
            ),
            Expanded(
              child: Text(Dates.monthYear(month), textAlign: TextAlign.center, style: AppText.display(17)),
            ),
            IconButton(
              onPressed: () => onMonth(DateTime(month.year, month.month + 1)),
              icon: const Icon(Icons.chevron_right_rounded),
              color: AppColors.sand700,
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 14),
          decoration: BoxDecoration(
            color: AppColors.sand50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.sunset200),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  for (final w in _weekdays)
                    Expanded(
                      child: Text(
                        w,
                        textAlign: TextAlign.center,
                        style: AppText.sans(12.5, color: AppColors.sand600),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              for (var week = 0; week * 7 < lead + days; week++)
                Row(
                  children: [
                    for (var slot = 0; slot < 7; slot++)
                      Expanded(
                        child: Builder(
                          builder: (_) {
                            final dayNumber = week * 7 + slot - lead + 1;
                            if (dayNumber < 1 || dayNumber > days) {
                              return const SizedBox(height: 38);
                            }
                            final day = DateTime(month.year, month.month, dayNumber);
                            final isStart = day == range.start;
                            final isEnd = day == range.end && range.end != range.start;
                            final inside = day.isAfter(range.start) && day.isBefore(range.end);
                            final past = day.isBefore(from);
                            return _Day(
                              number: dayNumber,
                              selected: isStart || isEnd,
                              inside: inside,
                              past: past,
                              onTap: past ? null : () => onDay(day),
                            );
                          },
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// One day in the month.
class _Day extends StatelessWidget {
  const _Day({
    required this.number,
    required this.selected,
    required this.inside,
    required this.past,
    required this.onTap,
  });

  final int number;
  final bool selected;
  final bool inside;
  final bool past;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: SizedBox(
        height: 38,
        child: Center(
          child: Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.sunset500
                  : inside
                  ? AppColors.sunset50
                  : null,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$number',
              style: AppText.sans(
                13.5,
                weight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected
                    ? Colors.white
                    : past
                    ? AppColors.sand300
                    : AppColors.sand900,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Rooms, adults and children, each with its own counter.
class _GuestCard extends StatelessWidget {
  const _GuestCard({required this.booking, required this.onChanged});
  final Booking booking;
  final ValueChanged<Booking> onChanged;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final b = booking;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.sunset200),
      ),
      child: Column(
        children: [
          _GuestRow(
            label: s.roomsWord,
            value: b.rooms,
            min: 1,
            onChanged: (v) => onChanged(b.copyWith(rooms: v)),
          ),
          const Divider(height: 1, color: AppColors.sand200),
          _GuestRow(
            label: s.adults,
            note: s.agesAdult,
            value: b.adults,
            min: 1,
            onChanged: (v) => onChanged(b.copyWith(adults: v)),
          ),
          const Divider(height: 1, color: AppColors.sand200),
          _GuestRow(
            label: s.children,
            note: s.agesChild,
            value: b.children,
            min: 0,
            onChanged: (v) => onChanged(b.copyWith(children: v)),
          ),
        ],
      ),
    );
  }
}

/// One counter line: what it counts, and the two buttons.
class _GuestRow extends StatelessWidget {
  const _GuestRow({required this.label, required this.value, required this.min, required this.onChanged, this.note});

  final String label;
  final String? note;
  final int value;
  final int min;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppText.sans(15.5, weight: FontWeight.w700, color: AppColors.sand900),
                ),
                if (note != null) ...[
                  const SizedBox(height: 3),
                  Text(note!, style: AppText.sans(12.5, color: AppColors.sand500)),
                ],
              ],
            ),
          ),
          _Round(icon: Icons.remove_rounded, filled: false, onTap: value > min ? () => onChanged(value - 1) : null),
          SizedBox(
            width: 34,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: AppText.sans(15.5, weight: FontWeight.w700, color: AppColors.sand900),
            ),
          ),
          _Round(icon: Icons.add_rounded, filled: true, onTap: value < 20 ? () => onChanged(value + 1) : null),
        ],
      ),
    );
  }
}

/// A round plus or minus.
class _Round extends StatelessWidget {
  const _Round({required this.icon, required this.filled, required this.onTap});
  final IconData icon;
  final bool filled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final off = onTap == null;
    return InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: filled ? (off ? AppColors.sunset200 : AppColors.sunset500) : Colors.white,
          border: filled ? null : Border.all(color: off ? AppColors.sand200 : AppColors.sunset300),
        ),
        child: Icon(icon, size: 19, color: filled ? Colors.white : (off ? AppColors.sand300 : AppColors.sunset500)),
      ),
    );
  }
}

/// What the choice adds up to: the lowest total among the rooms that fit
/// (from the quote), who it is for, and the way to the rooms. A preview: the
/// stay is reached by phone or website to book.
class _StayCard extends StatefulWidget {
  const _StayCard({super.key, required this.booking, required this.stayId});
  final Booking booking;
  final String stayId;

  @override
  State<_StayCard> createState() => _StayCardState();
}

class _StayCardState extends State<_StayCard> {
  late final Future<StayQuote> _quote = widget.booking.quote(context.read<AmsApi>(), widget.stayId);

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final b = widget.booking;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppColors.violet.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.stayDetails, style: AppText.display(19)),
          const SizedBox(height: 8),
          FutureBuilder<StayQuote>(
            future: _quote,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 6),
                  child: SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                );
              }
              final q = snap.data;
              final total = q?.fromTotal;
              if (q == null || total == null) {
                return Text(s.noPriceForDates, style: AppText.sans(13.5, color: AppColors.sand500));
              }
              return Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '${s.fromTime} ',
                      style: AppText.sans(13, color: AppColors.sand500),
                    ),
                    TextSpan(
                      text: totalForNights(s, total, q.currency, q.nights),
                      style: AppText.sans(17, weight: FontWeight.w800, color: AppColors.sand900),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _Fact(icon: Icons.calendar_month_rounded, label: b.nightsLabel),
              _Fact(icon: Icons.bed_rounded, label: '${b.rooms} ${b.rooms == 1 ? s.roomWord : s.roomsWord}'),
              _Fact(icon: Icons.person_rounded, label: '${b.adults} ${b.adults == 1 ? s.guestWord : s.guestsWord}'),
              if (b.children > 0)
                _Fact(
                  icon: Icons.child_care_rounded,
                  label: '${b.children} ${b.children == 1 ? s.childWord : s.childrenWord}',
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(s.priceNoBooking, style: AppText.sans(12, color: AppColors.sand500)),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.violet,
                minimumSize: const Size(0, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
              ),
              onPressed: () => context.push(Routes.stayRooms(widget.stayId)),
              child: Text(
                s.viewRooms,
                style: AppText.sans(15.5, weight: FontWeight.w700, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One fact on the stay card: its symbol and its words.
class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 17, color: AppColors.sunset500),
        const SizedBox(width: 6),
        Text(
          label,
          style: AppText.sans(13.5, weight: FontWeight.w600, color: AppColors.sand900),
        ),
      ],
    );
  }
}

/// A room's price for the chosen nights, and why it may not suit: big, per
/// night (the quote's total over its nights), with the total under it when
/// more than one night is picked.
class RoomQuoteView extends StatelessWidget {
  const RoomQuoteView({super.key, required this.quote, this.large = false});

  /// Null while there is no quote for the room.
  final RoomQuote? quote;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final q = quote;
    final total = q?.total;
    final problems = <String>[
      if (q != null && !q.fitsGuests) s.roomTooSmall,
      if (q != null && !q.enoughRooms) s.notEnoughRooms,
      if (q != null && !q.meetsMinNights) s.fill(s.minNightsNeeded, {'n': q.minNights ?? 2}),
    ];
    if (q != null && problems.isEmpty && !q.bookable) problems.add(s.notBookable);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (q == null || total == null)
          Text(s.noPriceForDates, style: AppText.sans(13.5, color: AppColors.sand500))
        else ...[
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  // Weekend nights may cost more: this is their average.
                  text: money((total / (q.nights < 1 ? 1 : q.nights) * 100).round() / 100, q.currency),
                  style: AppText.sans(large ? 28 : 24, weight: FontWeight.w800, color: AppColors.sand900),
                ),
                TextSpan(
                  text: ' ${s.perNightSuffix}',
                  style: AppText.sans(13, color: AppColors.sand500),
                ),
              ],
            ),
          ),
          if (q.nights > 1)
            Text(totalForNights(s, total, q.currency, q.nights), style: AppText.sans(13, color: AppColors.sand500)),
        ],
        for (final p in problems) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.info_outline_rounded, size: 15, color: AppColors.sunset600),
              const SizedBox(width: 5),
              Expanded(
                child: Text(p, style: AppText.sans(12.5, color: AppColors.sunset600)),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
