import 'package:material_ui/material_ui.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';

/// The app's terms, privacy summary and what the traveller is responsible for.
///
/// TODO(api): placeholder copy from the design — the final wording has to come
/// from AMS Travel (and be translated into Khmer by a person, not the app).
class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  static const _sections = <(String, String, List<String>)>[
    (
      '1. Terms of Service',
      'Welcome to AMS Travel. By accessing or using our mobile application, you agree to comply '
          'with and be bound by these terms. Please review them carefully before proceeding with '
          'your travel planning and bookings.',
      [],
    ),
    (
      '2. Privacy Policy',
      'We take your privacy seriously. In order to offer optimal local suggestions, coordinate '
          'bookings, and display valid achievements:',
      [
        'We safely encrypt password and authentication assets.',
        'Location data maps your current city accurately.',
        'Personal data is never sold to external third parties.',
      ],
    ),
    (
      '3. User Responsibilities',
      'Users are solely responsible for keeping account information accurate and up to date, '
          'including email preferences, currencies, and units. You agree to follow the local laws '
          'of the Kingdom of Cambodia during travel.',
      [],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text(s.termsConditions, style: AppText.display(20)),
        centerTitle: true,
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(20, 8, 20, 32 + MediaQuery.paddingOf(context).bottom),
        children: [
          for (final (heading, body, bullets) in _sections) ...[
            Text(
              heading,
              style: AppText.sans(15.5, weight: FontWeight.w700, color: AppColors.sand900),
            ),
            const SizedBox(height: 8),
            Text(body, style: AppText.sans(14, color: AppColors.sand600, height: 1.55)),
            for (final bullet in bullets)
              Padding(
                padding: const EdgeInsets.only(left: 8, top: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('•  ', style: AppText.sans(14, color: AppColors.sand600)),
                    Expanded(
                      child: Text(
                        bullet,
                        style: AppText.sans(14, color: AppColors.sand600, height: 1.55),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 22),
          ],
        ],
      ),
    );
  }
}
