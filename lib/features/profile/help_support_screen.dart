import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/common.dart';

/// How to reach the team: a line of copy, three ways to get in touch, and
/// the social accounts.
///
/// TODO(api): these details are the ones from the design. Swap them for the
/// real support address, number and site once the backend can serve them.
class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  static const _email = 'support@AMSTravel.com';
  static const _phone = '+855 23 456 789';
  static const _site = 'www.amstravel.com.kh';

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text(s.helpSupport, style: AppText.display(20)),
        centerTitle: true,
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(20, 8, 20, 24 + MediaQuery.paddingOf(context).bottom),
        children: [
          Text(
            s.helpIntro,
            style: AppText.sans(14.5, color: AppColors.sand600, height: 1.5),
          ),
          const SizedBox(height: 20),

          _ContactRow(
            icon: Icons.mail_outline_rounded,
            label: _email,
            onTap: () => launchUrl(Uri.parse('mailto:$_email')),
          ),
          _ContactRow(
            icon: Icons.call_outlined,
            label: _phone,
            onTap: () => launchUrl(Uri.parse('tel:${_phone.replaceAll(' ', '')}')),
          ),
          _ContactRow(
            icon: Icons.language_rounded,
            label: _site,
            onTap: () => launchUrl(
              Uri.parse('https://ams-travel.netlify.app/'),
              mode: LaunchMode.externalApplication,
            ),
          ),

          const SizedBox(height: 22),
          Divider(color: AppColors.sand200, height: 1),
          const SizedBox(height: 22),

          // TODO(api): the app has no social accounts to open yet.
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final icon in const [_Brand.facebook, _Brand.instagram, _Brand.telegram, _Brand.tiktok])
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: IconButton(
                    onPressed: () => showToast(context, s.socialLinkLater),
                    icon: _SocialIcon(brand: icon),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One way of getting in touch.
class _ContactRow extends StatelessWidget {
  const _ContactRow({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppTheme.radius),
            border: Border.all(color: AppColors.sand200),
          ),
          child: Row(
            children: [
              Icon(icon, size: 21, color: AppColors.sand900),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: AppText.sans(15, weight: FontWeight.w500, color: AppColors.sand900),
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.sand400),
            ],
          ),
        ),
      ),
    );
  }
}

/// The social accounts the page links out to.
enum _Brand { facebook, instagram, telegram, tiktok }

/// Each mark in its own colours: one flat colour for Facebook and Telegram,
/// Instagram's gradient, and TikTok's offset cyan/pink glyphs.
class _SocialIcon extends StatelessWidget {
  const _SocialIcon({required this.brand});
  final _Brand brand;

  static const _size = 26.0;

  @override
  Widget build(BuildContext context) {
    switch (brand) {
      case _Brand.facebook:
        return const FaIcon(FontAwesomeIcons.facebook, size: _size, color: Color(0xFF1877F2));
      case _Brand.telegram:
        return const FaIcon(FontAwesomeIcons.telegram, size: _size, color: Color(0xFF229ED9));
      case _Brand.instagram:
        return ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) => const LinearGradient(
            begin: Alignment.bottomLeft,
            end: Alignment.topRight,
            colors: [Color(0xFFF58529), Color(0xFFDD2A7B), Color(0xFF8134AF), Color(0xFF515BD4)],
          ).createShader(bounds),
          child: const FaIcon(FontAwesomeIcons.instagram, size: _size, color: Colors.white),
        );
      case _Brand.tiktok:
        return const SizedBox(
          width: _size,
          height: _size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                left: 0,
                top: 0,
                child: FaIcon(FontAwesomeIcons.tiktok, size: _size, color: Color(0xFF25F4EE)),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: FaIcon(FontAwesomeIcons.tiktok, size: _size, color: Color(0xFFFE2C55)),
              ),
              FaIcon(FontAwesomeIcons.tiktok, size: _size, color: Color(0xFF010101)),
            ],
          ),
        );
    }
  }
}
