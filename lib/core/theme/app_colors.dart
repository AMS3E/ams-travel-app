import 'package:material_ui/material_ui.dart';

/// Palette taken from the AMS Travel website (Tailwind tokens in its CSS).
class AppColors {
  const AppColors._();

  // Brand — indigo/purple
  static const brand50 = Color(0xFFF4F3FB);
  static const brand100 = Color(0xFFE8E6F6);
  static const brand200 = Color(0xFFD2CFED);
  static const brand300 = Color(0xFFB3AEDE);
  static const brand400 = Color(0xFF8F88C9);
  static const brand500 = Color(0xFF6F66AE);
  static const brand600 = Color(0xFF574D92);

  /// The app's accent: quick actions, chips, section arrows.
  static const violet = Color(0xFF5B2EE5);
  static const brand700 = Color(0xFF443C84);
  static const brand800 = Color(0xFF39326B);
  static const brand900 = Color(0xFF302B57);
  static const brand950 = Color(0xFF1C1935);

  // Sunset — accent red
  static const sunset50 = Color(0xFFFDF3F4);
  static const sunset200 = Color(0xFFF6C8CD);
  static const sunset300 = Color(0xFFEDA0A8);
  static const sunset400 = Color(0xFFE0707E);
  static const sunset500 = Color(0xFFCF4356);
  static const sunset600 = Color(0xFFC12938);
  static const sunset700 = Color(0xFFA11F2D);

  static const plum600 = Color(0xFF86305A);

  // Sand — neutrals
  static const sand50 = Color(0xFFFBFAFC);
  static const sand100 = Color(0xFFF3F2F6);
  static const sand200 = Color(0xFFE6E4EC);
  static const sand300 = Color(0xFFD0CCD8);
  static const sand400 = Color(0xFFA09AAC);
  static const sand500 = Color(0xFF6F6979);
  static const sand600 = Color(0xFF524D5F);
  static const sand700 = Color(0xFF3C3847);
  static const sand800 = Color(0xFF282531);
  static const sand900 = Color(0xFF181620);

  static const star = Color(0xFFF5A524);

  /// Route lines and their numbered stops on the corridor maps.
  static const route = Color(0xFF2B3A8F);
  static const success = Color(0xFF1F8A5B);

  /// Logo gradient (red → indigo), used on hero accents.
  static const logoGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFD42027), plum600, Color(0xFF2B3A8F)],
  );

  /// One marker colour per tourism region, in region order.
  static const regionColors = <String, Color>{
    'ancient-capitals': Color(0xFFB7791F),
    'northeastern-civilization': Color(0xFF2F855A),
    'mekong-tonle-sap': Color(0xFF2B6CB0),
    'mountain-waterfall': Color(0xFF276749),
    'coastal-island': Color(0xFF0987A0),
    'urban-nightlife': Color(0xFF6B46C1),
    'khmer-culinary': Color(0xFFC05621),
    'eco-community': Color(0xFF68803A),
    'luxury': Color(0xFFB83280),
  };

  static Color forRegion(String slug) => regionColors[slug] ?? brand600;
}
