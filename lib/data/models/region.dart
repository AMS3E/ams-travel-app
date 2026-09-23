import 'json_utils.dart';

class Region {
  const Region({
    required this.slug,
    required this.order,
    required this.name,
    this.nameKh,
    required this.tagline,
    required this.summary,
    required this.image,
    required this.aboutTitle,
    this.aboutTitleKh,
    required this.coreIdentity,
    this.coreIdentityKh,
    required this.highlightTitle,
    required this.highlightIntro,
    this.highlights = const [],
  });

  final String slug;
  final int order;
  final String name;
  final String? nameKh;
  final String tagline;

  /// Short description used on the region cards.
  final String summary;
  final String image;
  final String aboutTitle;
  final String? aboutTitleKh;
  final String coreIdentity;
  final String? coreIdentityKh;

  /// Each region has one themed list: Historical Coverage, Peoples of the
  /// Northeast, The Water Year, The Luxury Map…
  final String highlightTitle;
  final String highlightIntro;
  final List<RegionHighlight> highlights;

  String get number => order.toString().padLeft(2, '0');

  factory Region.fromJson(Json j) => Region(
    slug: str(j, 'slug'),
    order: integer(j, 'order'),
    name: str(j, 'name'),
    nameKh: strOrNull(j, 'nameKh', alt: ['name_kh']),
    tagline: str(j, 'tagline'),
    summary: str(j, 'summary', alt: ['description']),
    image: str(j, 'image', alt: ['imageUrl', 'image_url']),
    aboutTitle: str(j, 'aboutTitle'),
    aboutTitleKh: strOrNull(j, 'aboutTitleKh'),
    coreIdentity: str(j, 'coreIdentity'),
    coreIdentityKh: strOrNull(j, 'coreIdentityKh'),
    highlightTitle: str(j, 'highlightTitle'),
    highlightIntro: str(j, 'highlightIntro'),
    highlights: objList(j, 'highlights', RegionHighlight.fromJson),
  );

  Json toJson() => {
    'slug': slug,
    'order': order,
    'name': name,
    'nameKh': nameKh,
    'tagline': tagline,
    'summary': summary,
    'image': image,
    'aboutTitle': aboutTitle,
    'aboutTitleKh': aboutTitleKh,
    'coreIdentity': coreIdentity,
    'coreIdentityKh': coreIdentityKh,
    'highlightTitle': highlightTitle,
    'highlightIntro': highlightIntro,
    'highlights': highlights.map((h) => h.toJson()).toList(),
  };
}

class RegionHighlight {
  const RegionHighlight({
    required this.index,
    this.label,
    this.meta,
    required this.title,
    this.subtitle,
    this.titleKh,
    required this.description,
    this.storySlug,
  });

  final int index;

  /// e.g. "c. 600 – 700 CE", "Mondulkiri", "December – April".
  final String? label;

  /// e.g. "Pre-Angkor Period", "Bahnaric · Austroasiatic".
  final String? meta;
  final String title;
  final String? subtitle;
  final String? titleKh;
  final String description;

  /// Set when the item opens a full story page (Ancient Capitals).
  final String? storySlug;

  factory RegionHighlight.fromJson(Json j) => RegionHighlight(
    index: integer(j, 'index'),
    label: strOrNull(j, 'label'),
    meta: strOrNull(j, 'meta'),
    title: str(j, 'title'),
    subtitle: strOrNull(j, 'subtitle'),
    titleKh: strOrNull(j, 'titleKh'),
    description: str(j, 'description'),
    storySlug: strOrNull(j, 'storySlug'),
  );

  Json toJson() => {
    'index': index,
    'label': label,
    'meta': meta,
    'title': title,
    'subtitle': subtitle,
    'titleKh': titleKh,
    'description': description,
    'storySlug': storySlug,
  };
}
