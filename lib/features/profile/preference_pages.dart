import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../data/api/account.dart';
import '../../state/auth_provider.dart';
import '../../state/locale_provider.dart';
import '../../state/settings_provider.dart';
import '../../widgets/common.dart';

/// Signed in, a choice is also saved to the account with
/// `PUT /preferences/me`; a guest keeps it on the phone only.
Future<void> _saveToAccount(BuildContext context, UserPreferences Function(UserPreferences p) change) async {
  final auth = context.read<AuthProvider>();
  if (!auth.isSignedIn) return;
  final s = S.read(context);
  try {
    await auth.savePreferences(change(auth.preferences ?? const UserPreferences()));
  } catch (_) {
    if (context.mounted) showToast(context, s.saveFailed);
  }
}

/// Which language the app speaks.
class LanguagePage extends StatelessWidget {
  const LanguagePage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final locale = context.watch<LocaleProvider>();
    void choose(bool khmer) {
      locale.setKhmer(khmer);
      _saveToAccount(context, (p) => p.copyWith(preferredLanguage: locale.code));
    }

    return _Page(
      title: s.language,
      children: [
        _Choice(label: 'English', selected: !locale.isKhmer, onTap: () => choose(false)),
        _Choice(label: 'Khmer (ភាសាខ្មែរ)', selected: locale.isKhmer, onTap: () => choose(true)),
      ],
    );
  }
}

/// The currency the traveller prefers. Prices show in the currency each one
/// comes in: converting them is parked 2026-10-14 (R-006).
class CurrencyPage extends StatelessWidget {
  const CurrencyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final settings = context.watch<SettingsProvider>();
    void choose(Currency c) {
      settings.setCurrency(c);
      _saveToAccount(context, (p) => p.copyWith(preferredCurrency: c.code));
    }

    return _Page(
      title: s.currency,
      children: [
        _Choice(
          label: 'Khmer Riel (៛)',
          selected: settings.currency == Currency.khr,
          onTap: () => choose(Currency.khr),
        ),
        _Choice(
          label: 'US Dollar (\$)',
          selected: settings.currency == Currency.usd,
          onTap: () => choose(Currency.usd),
        ),
        const SizedBox(height: 10),
        Text(s.currencyNote, style: AppText.sans(12.5, color: AppColors.sand500, height: 1.45)),
      ],
    );
  }
}

/// Kilometres or miles: `distanceUnit` on the account when signed in, on the
/// phone for a guest.
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
          onTap: () {
            settings.setUnit(DistanceUnit.metric);
            _saveToAccount(context, (p) => p.copyWith(distanceUnit: DistanceUnit.metric.code));
          },
        ),
        _Choice(
          label: 'Miles / Feet (mi/ft)',
          selected: settings.unit == DistanceUnit.imperial,
          onTap: () {
            settings.setUnit(DistanceUnit.imperial);
            _saveToAccount(context, (p) => p.copyWith(distanceUnit: DistanceUnit.imperial.code));
          },
        ),
      ],
    );
  }
}

/// The notification switch: `notificationPush` on the account when signed
/// in. Push delivery itself is parked (screens-to-api.md).
class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final settings = context.watch<SettingsProvider>();
    final signedIn = context.select<AuthProvider, bool>((a) => a.isSignedIn);
    void change(bool on) {
      settings.setNotifications(on);
      _saveToAccount(context, (p) => p.copyWith(notificationPush: on));
    }

    return _Page(
      title: s.notification,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 6, 10, 6),
          decoration: BoxDecoration(color: AppColors.sand100, borderRadius: BorderRadius.circular(AppTheme.radius)),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  s.notification,
                  style: AppText.sans(15, weight: FontWeight.w500, color: AppColors.sand900),
                ),
              ),
              Switch(value: settings.notifications, onChanged: change, activeTrackColor: AppColors.brand600),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          signedIn ? s.notificationsAccountNote : s.notificationsNote,
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
                child: Text(
                  label,
                  style: AppText.sans(15, weight: FontWeight.w500, color: AppColors.sand900),
                ),
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
