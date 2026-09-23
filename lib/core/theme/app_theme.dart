import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';

import 'app_colors.dart';

/// One family everywhere: Geist, the font in the app header.
class AppText {
  const AppText._();

  /// Titles and headings.
  static TextStyle display(double size, {Color? color, FontWeight weight = FontWeight.w700}) => GoogleFonts.geist(
    fontSize: size,
    fontWeight: weight,
    color: color ?? AppColors.sand900,
    height: 1.15,
    letterSpacing: -0.4,
  );

  static TextStyle sans(double size, {Color? color, FontWeight weight = FontWeight.w400, double? height}) =>
      GoogleFonts.geist(fontSize: size, fontWeight: weight, color: color ?? AppColors.sand800, height: height);

  /// Small uppercase label above section titles ("HANDPICKED", "TRENDING").
  static TextStyle eyebrow({Color? color}) => GoogleFonts.geist(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 2.2,
    color: color ?? AppColors.brand600,
  );
}

class AppTheme {
  const AppTheme._();

  static const double radius = 20;

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(seedColor: AppColors.brand600, brightness: Brightness.light).copyWith(
      primary: AppColors.brand600,
      onPrimary: Colors.white,
      primaryContainer: AppColors.brand100,
      onPrimaryContainer: AppColors.brand900,
      secondary: AppColors.sunset500,
      onSecondary: Colors.white,
      secondaryContainer: AppColors.sunset50,
      onSecondaryContainer: AppColors.sunset700,
      surface: Colors.white,
      onSurface: AppColors.sand900,
      onSurfaceVariant: AppColors.sand500,
      outline: AppColors.sand300,
      outlineVariant: AppColors.sand200,
      error: AppColors.sunset600,
    );

    final base = ThemeData(useMaterial3: true, colorScheme: scheme);
    final textTheme = base.textTheme
        .apply(
          fontFamily: GoogleFonts.geist().fontFamily,
          bodyColor: AppColors.sand800,
          displayColor: AppColors.sand900,
        )
        .copyWith(
          displaySmall: AppText.display(32),
          headlineLarge: AppText.display(30),
          headlineMedium: AppText.display(26),
          headlineSmall: AppText.display(22),
          titleLarge: AppText.display(20),
          titleMedium: AppText.sans(16, weight: FontWeight.w600, color: AppColors.sand900),
          titleSmall: AppText.sans(14, weight: FontWeight.w600, color: AppColors.sand900),
          bodyLarge: AppText.sans(16, height: 1.55),
          bodyMedium: AppText.sans(14, height: 1.5),
          bodySmall: AppText.sans(12, color: AppColors.sand500),
          labelLarge: AppText.sans(14, weight: FontWeight.w600),
        );

    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(14));

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.sand50,
      textTheme: textTheme,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.sand50,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.sand900,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        titleTextStyle: AppText.display(20),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppColors.brand100,
        height: 68,
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => AppText.sans(
            12,
            weight: states.contains(WidgetState.selected) ? FontWeight.w600 : FontWeight.w500,
            color: states.contains(WidgetState.selected) ? AppColors.brand700 : AppColors.sand500,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) =>
              IconThemeData(color: states.contains(WidgetState.selected) ? AppColors.brand700 : AppColors.sand500),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.brand600,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(horizontal: 22),
          shape: shape,
          textStyle: AppText.sans(15, weight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.brand700,
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(horizontal: 22),
          side: const BorderSide(color: AppColors.sand300),
          shape: shape,
          textStyle: AppText.sans(15, weight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.brand600,
          textStyle: AppText.sans(14, weight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        hintStyle: AppText.sans(15, color: AppColors.sand400),
        labelStyle: AppText.sans(15, color: AppColors.sand500),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.sand200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.sand200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.brand500, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.sunset500),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.white,
        selectedColor: AppColors.brand600,
        side: const BorderSide(color: AppColors.sand200),
        labelStyle: AppText.sans(13, weight: FontWeight.w500, color: AppColors.sand700),
        secondaryLabelStyle: AppText.sans(13, weight: FontWeight.w600, color: Colors.white),
        checkmarkColor: Colors.white,
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: AppColors.brand700,
        unselectedLabelColor: AppColors.sand500,
        indicatorColor: AppColors.brand600,
        labelStyle: AppText.sans(14, weight: FontWeight.w600),
        unselectedLabelStyle: AppText.sans(14, weight: FontWeight.w500),
        dividerColor: AppColors.sand200,
        tabAlignment: TabAlignment.start,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.brand950,
        contentTextStyle: AppText.sans(14, color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.sand200, space: 1, thickness: 1),
    );
  }
}
