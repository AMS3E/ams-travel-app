import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../state/locale_provider.dart';
import '../../state/settings_provider.dart';

/// Which language the app speaks.
class LanguagePage extends StatelessWidget {
  const LanguagePage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final locale = context.watch<LocaleProvider>();
    return _Page(
      title: s.language,
      children: [
        _Choice(
          label: 'English',
          selected: !locale.isKhmer,
          onTap: () => locale.setKhmer(false),
        ),
        _Choice(
          label: 'Khmer (ភាសាខ្មែរ)',
          selected: locale.isKhmer,
          onTap: () => locale.setKhmer(true),
        ),
      ],
    );
  }
}

/// What prices are shown in.
class CurrencyPage extends StatelessWidget {
  const CurrencyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final settings = context.watch<SettingsProvider>();
    return _Page(
      title: s.currency,
      children: [
        _Choice(
          label: 'Khmer Riel (៛)',
          selected: settings.currency == Currency.khr,
          onTap: () => settings.setCurrency(Currency.khr),
        ),
        _Choice(
          label: 'US Dollar (\$)',
          selected: settings.currency == Currency.usd,
          onTap: () => settings.setCurrency(Currency.usd),
        ),
        const SizedBox(height: 10),
        // The rate is fixed in the app for now; be plain about it.
        Text(
          '1 USD ≈ ${SettingsProvider.rielPerDollar} KHR — ${s.rateNote}',
          style: AppText.sans(12.5, color: AppColors.sand500, height: 1.45),
        ),
      ],
    );
  }
}

/// Kilometres or miles.
class UnitsPage extends StatelessWidget {
  const UnitsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final settings = context.watch<SettingsProvider>();
    return _Page(
      title: s.unit,
      children: [
        _Choice(
          label: 'Kilometers / Meters (km/m)',
          selected: settings.unit == DistanceUnit.metric,
          onTap: () => settings.setUnit(DistanceUnit.metric),
        ),
        _Choice(
          label: 'Miles / Feet (mi/ft)',
          selected: settings.unit == DistanceUnit.imperial,
          onTap: () => settings.setUnit(DistanceUnit.imperial),
        ),
      ],
    );
  }
}

/// One switch, for now.
class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final settings = context.watch<SettingsProvider>();
    return _Page(
      title: s.notification,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 6, 10, 6),
          decoration: BoxDecoration(
            color: AppColors.sand100,
            borderRadius: BorderRadius.circular(AppTheme.radius),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  s.notification,
                  style: AppText.sans(15, weight: FontWeight.w500, color: AppColors.sand900),
                ),
              ),
              Switch(
                value: settings.notifications,
                onChanged: settings.setNotifications,
                activeTrackColor: AppColors.brand600,
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        // TODO(api): connect a push service so this switch reaches a server.
        Text(
          s.notificationsNote,
          style: AppText.sans(12.5, color: AppColors.sand500, height: 1.45),
        ),
      ],
    );
  }
}

/// The shell every preference page shares.
class _Page extends StatelessWidget {
  const _Page({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title, style: AppText.display(20)), centerTitle: true),
      body: ListView(
        padding: EdgeInsets.fromLTRB(20, 12, 20, 24 + MediaQuery.paddingOf(context).bottom),
        children: children,
      ),
    );
  }
}

/// One option: grey and ticked when it is the one in use.
class _Choice extends StatelessWidget {
  const _Choice({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
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
            color: selected ? AppColors.sand100 : Colors.white,
            borderRadius: BorderRadius.circular(AppTheme.radius),
            border: Border.all(color: selected ? AppColors.sand300 : AppColors.sand200),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(label, style: AppText.sans(15, weight: FontWeight.w500, color: AppColors.sand900)),
              ),
              Icon(
                selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                size: 22,
                color: selected ? AppColors.sand900 : AppColors.sand300,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
