import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/overview_card.dart';

/// The ways to reach a place, as pills: a number to ring and the page to
/// read, and for an activity's organiser also an e-mail, Telegram, WhatsApp
/// and Facebook. Stays, rooms, food places and activities show these; the
/// app takes no bookings, so asking the place is the way to one.
class ContactButtons extends StatelessWidget {
  const ContactButtons({
    super.key,
    this.phone,
    this.website,
    this.email,
    this.telegram,
    this.whatsapp,
    this.facebookUrl,
    this.column = true,
  });

  final String? phone;
  final String? website;
  final String? email;

  /// A handle ("@kampicruise") or a t.me link.
  final String? telegram;

  /// A phone number.
  final String? whatsapp;
  final String? facebookUrl;

  /// One under the other (stay pages) or side by side (food places).
  final bool column;

  static Future<void> _open(String url) => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

  @override
  Widget build(BuildContext context) {
    final phone = this.phone?.trim() ?? '';
    final website = this.website?.trim() ?? '';
    final email = this.email?.trim() ?? '';
    final telegram = this.telegram?.trim() ?? '';
    final whatsapp = this.whatsapp?.trim() ?? '';
    final facebook = facebookUrl?.trim() ?? '';
    final pills = <Widget>[
      if (phone.isNotEmpty)
        ContactPill(
          icon: const Icon(Icons.phone_in_talk_rounded),
          label: phone,
          onTap: () => _open('tel:${phone.replaceAll(' ', '')}'),
        ),
      if (website.isNotEmpty)
        ContactPill(
          icon: const Icon(Icons.public_rounded),
          label: website.replaceFirst(_scheme, '').split('/').first,
          onTap: () => _open(_link(website)),
        ),
      if (email.isNotEmpty)
        ContactPill(icon: const Icon(Icons.mail_outline_rounded), label: email, onTap: () => _open('mailto:$email')),
      if (telegram.isNotEmpty)
        ContactPill(
          icon: const FaIcon(FontAwesomeIcons.telegram),
          label: telegram.startsWith('@') ? telegram : '@${telegram.split('/').last}',
          onTap: () =>
              _open(telegram.contains('t.me') ? _link(telegram) : 'https://t.me/${telegram.replaceFirst('@', '')}'),
        ),
      if (whatsapp.isNotEmpty)
        ContactPill(
          icon: const FaIcon(FontAwesomeIcons.whatsapp),
          label: whatsapp,
          onTap: () => _open('https://wa.me/${whatsapp.replaceAll(_notDigit, '')}'),
        ),
      if (facebook.isNotEmpty)
        ContactPill(
          icon: const FaIcon(FontAwesomeIcons.facebook),
          label: 'Facebook',
          onTap: () => _open(_link(facebook)),
        ),
    ];
    if (pills.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: column
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < pills.length; i++) ...[if (i > 0) const SizedBox(height: 10), pills[i]],
              ],
            )
          : Wrap(spacing: 10, runSpacing: 10, children: pills),
    );
  }
}

/// One way of getting in touch, as a pill: the stay pages, the rooms and
/// the places to eat all use this.
class ContactPill extends StatelessWidget {
  const ContactPill({super.key, required this.icon, required this.label, required this.onTap});

  /// An [Icon] or a brand's [FaIcon]; sized and coloured here.
  final Widget icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // The orange-to-violet border of the cards around it.
    return GradientFrame(
      radius: 99,
      expand: false,
      padding: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(99),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconTheme.merge(
                data: const IconThemeData(size: 16, color: AppColors.violet),
                child: icon,
              ),
              const SizedBox(width: 7),
              // A long domain or number shortens rather than running over.
              Flexible(
                child: Text(
                  label,
                  style: AppText.sans(13, weight: FontWeight.w600, color: AppColors.sand900),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final _scheme = RegExp('^https?://');
final _notDigit = RegExp(r'\D');

/// [url] with a scheme, for a website typed without one.
String _link(String url) => url.startsWith('http') ? url : 'https://$url';
