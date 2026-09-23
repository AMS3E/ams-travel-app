import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/models.dart';

/// Ways to reach a place — one line per channel. Used by the stay page and by
/// each of its rooms, so a guest can ask about a room without going back.
class ContactCard extends StatelessWidget {
  const ContactCard({super.key, required this.destination, this.price});
  final Destination destination;

  /// Nightly rate shown above the contacts — the app does not take bookings,
  /// so the price sits next to the ways of asking for one.
  final String? price;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final d = destination;
    Future<void> open(String url) => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

    // Every place has a page on the website, so there is always a link.
    final website = d.website ?? 'https://ams-travel.netlify.app/regions/${d.region}/${d.slug}';
    final telegram = d.telegram == null ? null : '@${d.telegram!.replaceAll('@', '')}';

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
            Text(s.contact, style: AppText.display(17)),
            if (price != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.brand50,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: price, style: AppText.display(20, color: AppColors.brand700)),
                          TextSpan(
                            text: ' / ${s.night}',
                            style: AppText.sans(13, color: AppColors.brand600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(s.bookByContact, style: AppText.sans(13, color: AppColors.sand500, height: 1.45)),
            ],
            const SizedBox(height: 10),
            _ContactRow(
              icon: Icons.language_rounded,
              label: s.website,
              value: website.replaceFirst(RegExp('^https?://'), ''),
              onTap: () => open(website),
            ),
            _ContactRow(
              icon: Icons.call_rounded,
              label: s.call,
              value: d.phone,
              onTap: d.phone == null ? null : () => open('tel:${d.phone}'),
            ),
            _ContactRow(
              icon: Icons.mail_outline_rounded,
              label: s.email,
              value: d.email,
              onTap: d.email == null ? null : () => open('mailto:${d.email}'),
            ),
            _ContactRow(
              icon: Icons.send_rounded,
              label: 'Telegram',
              value: telegram,
              onTap: telegram == null ? null : () => open('https://t.me/${telegram.substring(1)}'),
            ),
            _ContactRow(
              icon: Icons.directions_rounded,
              label: s.directions,
              value: '${d.lat.toStringAsFixed(3)}, ${d.lng.toStringAsFixed(3)}',
              onTap: () => open('https://www.google.com/maps/search/?api=1&query=${d.lat},${d.lng}'),
            ),
          ],
        ),
      ),
    );
  }
}

/// One contact line. Without a [value] it stays greyed out and does nothing —
/// that detail has not reached the app yet.
class _ContactRow extends StatelessWidget {
  const _ContactRow({required this.icon, required this.label, required this.value, this.onTap});

  final IconData icon;
  final String label;
  final String? value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final missing = value == null;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: [
            Icon(icon, size: 19, color: missing ? AppColors.sand300 : AppColors.brand600),
            const SizedBox(width: 12),
            Text(label, style: AppText.sans(14.5, color: AppColors.sand800)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                value ?? s.notListedYet,
                textAlign: TextAlign.right,
                style: AppText.sans(
                  13.5,
                  weight: missing ? FontWeight.w400 : FontWeight.w600,
                  color: missing ? AppColors.sand400 : AppColors.sand700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (!missing) ...[
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.sand400),
            ],
          ],
        ),
      ),
    );
  }
}
