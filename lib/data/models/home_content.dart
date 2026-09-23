import 'destination.dart';
import 'json_utils.dart';

class HomeContent {
  const HomeContent({
    required this.heroImage,
    required this.stats,
    required this.featured,
    required this.trending,
    required this.whyTitle,
    required this.whyIntro,
    required this.why,
    required this.testimonials,
    required this.planImage,
    required this.contactPhone,
  });

  final String heroImage;
  final List<HomeStat> stats;
  final List<FeaturedPick> featured;
  final List<TrendingPick> trending;
  final String whyTitle;
  final String whyIntro;
  final List<WhyItem> why;
  final List<Testimonial> testimonials;
  final String planImage;
  final String contactPhone;

  factory HomeContent.fromJson(Json j) => HomeContent(
    heroImage: str(j, 'heroImage'),
    stats: objList(j, 'stats', HomeStat.fromJson),
    featured: objList(j, 'featured', FeaturedPick.fromJson),
    trending: objList(j, 'trending', TrendingPick.fromJson),
    whyTitle: str(j, 'whyTitle'),
    whyIntro: str(j, 'whyIntro'),
    why: objList(j, 'why', WhyItem.fromJson),
    testimonials: objList(j, 'testimonials', Testimonial.fromJson),
    planImage: str(j, 'planImage'),
    contactPhone: str(j, 'contactPhone'),
  );
}

class HomeStat {
  const HomeStat({required this.value, required this.suffix, required this.label});

  final String value;
  final String suffix;
  final String label;

  factory HomeStat.fromJson(Json j) =>
      HomeStat(value: str(j, 'value'), suffix: str(j, 'suffix'), label: str(j, 'label'));
}

class FeaturedPick {
  const FeaturedPick({required this.ref, this.badge, this.rating, this.bestTime});

  final DestinationRef ref;
  final String? badge;
  final double? rating;
  final String? bestTime;

  factory FeaturedPick.fromJson(Json j) => FeaturedPick(
    ref: DestinationRef.fromJson(j),
    badge: strOrNull(j, 'badge'),
    rating: dbl(j, 'rating'),
    bestTime: strOrNull(j, 'bestTime'),
  );
}

class TrendingPick {
  const TrendingPick({required this.ref, required this.saves, required this.growth});

  final DestinationRef ref;
  final String saves;
  final String growth;

  factory TrendingPick.fromJson(Json j) =>
      TrendingPick(ref: DestinationRef.fromJson(j), saves: str(j, 'saves'), growth: str(j, 'growth'));
}

class WhyItem {
  const WhyItem({required this.icon, required this.title, required this.body});

  final String icon;
  final String title;
  final String body;

  factory WhyItem.fromJson(Json j) => WhyItem(icon: str(j, 'icon'), title: str(j, 'title'), body: str(j, 'body'));
}

class Testimonial {
  const Testimonial({required this.name, required this.trip, required this.rating, required this.text});

  final String name;
  final String trip;
  final int rating;
  final String text;

  String get initials => name.split(' ').where((p) => p.isNotEmpty).take(2).map((p) => p[0]).join().toUpperCase();

  factory Testimonial.fromJson(Json j) => Testimonial(
    name: str(j, 'name'),
    trip: str(j, 'trip'),
    rating: integer(j, 'rating', fallback: 5),
    text: str(j, 'text'),
  );
}
