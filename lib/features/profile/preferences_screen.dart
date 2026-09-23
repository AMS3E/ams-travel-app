import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../state/locale_provider.dart';
import '../../state/settings_provider.dart';

/// Language, currency, distance unit and notifications. Each row opens a
/// page of its own.
class PreferencesScreen extends StatelessWidget {
  const PreferencesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final locale = context.watch<LocaleProvider>();
    final settings = context.watch<SettingsProvider>();

    return Scaffold(
      appBar: AppBar(title: Text(s.preference, style: AppText.display(20)), centerTitle: true),
      body: ListView(
        padding: EdgeInsets.fromLTRB(20, 12, 20, 24 + MediaQuery.paddingOf(context).bottom),
        children: [
          _Row(
            label: s.language,
            value: locale.isKhmer ? 'ខ្មែរ' : 'English',
            onTap: () => context.push(Routes.language),
          ),
          _Row(
            label: s.currency,
            value: settings.currency == Currency.usd ? '\$  USD' : '៛  KHR',
            onTap: () => context.push(Routes.currency),
          ),
          _Row(
            label: s.unit,
            value: settings.unit == DistanceUnit.metric ? 'Km / m' : 'Mi / ft',
            onTap: () => context.push(Routes.units),
          ),
          _Row(
            label: s.notification,
            value: settings.notifications ? s.onWord : s.offWord,
            onTap: () => context.push(Routes.notifications),
          ),
        ],
      ),
    );
  }
}

/// One settings row: label on the left, the current choice and a chevron.
class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value, required this.onTap});
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: AppColors.sand100,
            borderRadius: BorderRadius.circular(AppTheme.radius),
          ),
          child: Row(
            children: [
              Text(label, style: AppText.sans(15, weight: FontWeight.w600, color: AppColors.sand900)),
              const Spacer(),
              Text(value, style: AppText.sans(14, color: AppColors.sand500)),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right_rounded, color: AppColors.sand400),
            ],
          ),
        ),
      ),
    );
  }
}
