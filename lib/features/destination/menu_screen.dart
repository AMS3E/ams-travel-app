import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/models.dart';
import '../../data/repositories/travel_repository.dart';
import '../../state/settings_provider.dart';
import '../../widgets/app_image.dart';
import '../../widgets/async_view.dart';
import '../../widgets/common.dart';
import '../../widgets/destination_card.dart';

/// Everything a place serves, section by section, with the price of each
/// dish in the traveller's currency.
class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key, required this.region, required this.slug});

  final String region;
  final String slug;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final repo = context.read<TravelRepository>();
    final ref = DestinationRef(region, slug);

    return Scaffold(
      appBar: AppBar(title: Text(s.menu, style: AppText.display(20)), centerTitle: true),
      body: AsyncView<(Destination, List<MenuSection>)>(
        load: () async => (
          await repo.getDestination(region, slug),
          await repo.getMenu(ref),
        ),
        builder: (context, data, _) {
          final (place, sections) = data;
          if (sections.isEmpty) {
            return EmptyState(icon: Icons.restaurant_menu_rounded, title: s.noMenu, body: s.noMenuBody);
          }
          final (title, _) = bilingual(context, place.name, place.nameKh);

          return ListView(
            padding: EdgeInsets.fromLTRB(16, 14, 16, 28 + MediaQuery.paddingOf(context).bottom),
            children: [
              _Header(title: title, place: place),
              const SizedBox(height: 18),
              for (final section in sections) ...[
                _Section(section: section),
                const SizedBox(height: 18),
              ],
              Text(
                s.pricesGuide,
                textAlign: TextAlign.center,
                style: AppText.sans(12.5, color: AppColors.sand500),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Whose menu this is, and what a meal there costs.
class _Header extends StatelessWidget {
  const _Header({required this.title, required this.place});
  final String title;
  final Destination place;

  @override
  Widget build(BuildContext context) {
    final facts = [
      if (place.priceRange != null) place.priceRange!,
      if (place.serving.isNotEmpty) place.serving.join(', '),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppText.display(22)),
        if (facts.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(facts.join('  ·  '), style: AppText.sans(13.5, color: AppColors.sand600)),
        ],
        if (place.cuisines.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in place.cuisines)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.violet.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    c,
                    style: AppText.sans(12.5, weight: FontWeight.w600, color: AppColors.violet),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// One part of the menu: its heading and the dishes under it.
class _Section extends StatelessWidget {
  const _Section({required this.section});
  final MenuSection section;

  @override
  Widget build(BuildContext context) {
    final (name, _) = bilingual(context, section.name, section.nameKh);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Row(
            children: [
              Text(name, style: AppText.display(17)),
              const SizedBox(width: 8),
              Text('${section.items.length}', style: AppText.sans(13, color: AppColors.sand500)),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.sand200),
          ),
          child: Column(
            children: [
              for (var i = 0; i < section.items.length; i++) ...[
                if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16, color: AppColors.sand200),
                _Dish(item: section.items[i]),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// One dish: what it is called, what is in it, and what it costs.
class _Dish extends StatelessWidget {
  const _Dish({required this.item});
  final MenuItem item;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final (name, _) = bilingual(context, item.name, item.nameKh);
    final price = context.watch<SettingsProvider>().price(item.price);

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (item.image != null) ...[
            AppImage(
              item.image!,
              width: 76,
              height: 76,
              radius: BorderRadius.circular(14),
            ),
            const SizedBox(width: 14),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: AppText.sans(15, weight: FontWeight.w700, color: AppColors.sand900),
                ),
                if (item.description != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    item.description!,
                    style: AppText.sans(13, color: AppColors.sand600, height: 1.4),
                  ),
                ],
                if (item.popular || item.vegetarian || item.spicy) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (item.popular)
                        _Badge(label: s.popularDish, icon: Icons.local_fire_department_rounded, color: AppColors.violet),
                      if (item.vegetarian)
                        _Badge(label: s.vegetarian, icon: Icons.eco_rounded, color: AppColors.success),
                      if (item.spicy)
                        _Badge(label: s.spicy, icon: Icons.whatshot_rounded, color: AppColors.sunset600),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 14),
          Text(price, style: AppText.sans(15, weight: FontWeight.w700, color: AppColors.sand900)),
        ],
      ),
    );
  }
}

/// A word about a dish — popular, vegetarian, spicy.
class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.icon, required this.color});
  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(label, style: AppText.sans(11.5, weight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}
