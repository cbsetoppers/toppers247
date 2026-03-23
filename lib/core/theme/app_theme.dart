import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Provides dynamic theme properties and global colors
class AppTheme {
  // Allow dynamic updates via a static variable we can update from the provider
  static Color _dynamicPrimaryColor = const Color(0xFFFFD700); // Default Golden

  // Track current brightness to provide context-less colors for legacy code
  static Brightness _currentBrightness = Brightness.dark;

  static const List<Color> availableColors = [
    Color(0xFFFFD700), // Golden
    Color(0xFFA020F0), // Purple
    Color(0xFF0096FF), // Blue
    Color(0xFF00C853), // Green
    Color(0xFFFFA500), // Orange
  ];

  static List<Color> getOtherColors(Color primary) {
    return availableColors.where((c) => c.toARGB32() != primary.toARGB32()).toList();
  }

  static Color getSectionColor(String section) {
    final others = getOtherColors(_dynamicPrimaryColor);
    switch (section.toUpperCase()) {
      case 'EXPLORE MORE':
        return others.isNotEmpty ? others[0] : _dynamicPrimaryColor;
      case 'JEE':
        return others.length > 1 ? others[1] : _dynamicPrimaryColor;
      case 'NEET':
        return others.length > 2 ? others[2] : _dynamicPrimaryColor;
      case 'CUET':
        return others.length > 3 ? others[3] : _dynamicPrimaryColor;
      default:
        return _dynamicPrimaryColor;
    }
  }

  static void setTheme(Color color, Brightness brightness) {
    _dynamicPrimaryColor = color;
    _currentBrightness = brightness;
  }

  static void setPrimaryColor(Color color) {
    _dynamicPrimaryColor = color;
  }

  // Use getter for dynamic evaluation
  static Color get primaryGold => _dynamicPrimaryColor; 
  static Color get primaryColor => primaryGold;
  static Color get secondaryColor => primaryGold.withAlpha(200);
  static Color get accentColor => primaryGold;

  // Constants that do not change based on dynamic theme color
  static const Color scaffoldBlack = Color(0xFF000000); 
  static const Color cardBlack = Color(0xFF121212); 
  static const Color primaryLight = Color(0xFFFFF4B0);
  
  // Dynamic color getters for text and surfaces
  static Color get textHeadingColorLight => const Color(0xFF1A1A1A);
  static Color get textBodyColorLight => const Color(0xFF4A4A4A);
  static Color get textHeadingColorDark => const Color(0xFFFFFAEB);
  static Color get textBodyColorDark => const Color(0xFFE0E0E0);

  // Legacy bridge getters to fix visibility and lint errors
  static Color get textHeadingColor => _currentBrightness == Brightness.light ? textHeadingColorLight : textHeadingColorDark;
  static Color get textBodyColor => _currentBrightness == Brightness.light ? textBodyColorLight : textBodyColorDark;

  // Gradients
  static Gradient get primaryGradient => LinearGradient(
    colors: [primaryGold, secondaryColor],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static final Gradient surfaceGradient = const LinearGradient(
    colors: [Color(0xFF1E1E1E), Color(0xFF000000)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // Shadows
  static List<BoxShadow> get premiumShadow => [
    BoxShadow(
      color: primaryGold.withOpacity(0.15),
      blurRadius: 30,
      offset: const Offset(0, 15),
    ),
  ];

  static List<BoxShadow> get goldShadow => [
    BoxShadow(
      color: primaryGold.withOpacity(0.3),
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
  ];

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.light,
        primary: primaryColor,
        secondary: secondaryColor,
        surface: Colors.white,
        background: const Color(0xFFF8FAFC),
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: textHeadingColorLight,
        onBackground: textBodyColorLight,
      ),
      scaffoldBackgroundColor: const Color(0xFFF8FAFC),
      splashFactory: InkSparkle.splashFactory,
      textTheme: GoogleFonts.outfitTextTheme().apply(
        bodyColor: textBodyColorLight,
        displayColor: textHeadingColorLight,
      ).copyWith(
        displayLarge: GoogleFonts.outfit(
          fontSize: 34,
          fontWeight: FontWeight.w900,
          color: textHeadingColorLight,
          letterSpacing: -1.2,
        ),
        headlineMedium: GoogleFonts.outfit(
          fontSize: 26,
          fontWeight: FontWeight.w800,
          color: textHeadingColorLight,
          letterSpacing: -0.8,
        ),
        titleLarge: GoogleFonts.outfit(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: textHeadingColorLight,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: primaryGold, size: 24),
        titleTextStyle: GoogleFonts.outfit(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: textHeadingColorLight,
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        margin: const EdgeInsets.all(8),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: BorderSide(color: primaryGold.withOpacity(0.1), width: 1.5),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: primaryGold,
        unselectedItemColor: Colors.grey.shade400,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 26,
          vertical: 20,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: BorderSide(color: primaryGold.withOpacity(0.2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: BorderSide(color: primaryGold, width: 2.5),
        ),
        hintStyle: GoogleFonts.outfit(
          color: Colors.grey.shade400,
          fontWeight: FontWeight.w500,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryGold,
          foregroundColor: Colors.black,
          minimumSize: const Size(double.infinity, 64),
          splashFactory: InkSparkle.splashFactory,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          elevation: 10,
          shadowColor: primaryGold.withOpacity(0.6),
          textStyle: GoogleFonts.outfit(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.dark,
        primary: primaryColor,
        secondary: secondaryColor,
        surface: const Color(0xFF1E293B),
        background: const Color(0xFF0F172A),
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: textHeadingColorDark,
        onBackground: textBodyColorDark,
      ),
      scaffoldBackgroundColor: scaffoldBlack,
      splashFactory: InkSparkle.splashFactory,
      textTheme: GoogleFonts.outfitTextTheme().apply(
        bodyColor: textBodyColorDark,
        displayColor: textHeadingColorDark,
      ).copyWith(
        displayLarge: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -1.2, color: primaryGold),
        headlineMedium: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.8, color: primaryGold),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: primaryGold, size: 24),
        titleTextStyle: GoogleFonts.outfit(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: primaryGold,
        ),
      ),
      cardTheme: CardThemeData(
        color: cardBlack,
        elevation: 0,
        margin: const EdgeInsets.all(8),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: BorderSide(color: primaryGold.withOpacity(0.15), width: 1.5),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: cardBlack,
        selectedItemColor: primaryGold,
        unselectedItemColor: Colors.grey.shade600,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardBlack,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 26,
          vertical: 20,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: BorderSide(color: primaryGold.withOpacity(0.2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: BorderSide(color: primaryGold.withOpacity(0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: BorderSide(color: primaryGold, width: 2.5),
        ),
        hintStyle: GoogleFonts.outfit(
          color: Colors.white24,
          fontWeight: FontWeight.w500,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryGold,
          foregroundColor: Colors.black,
          minimumSize: const Size(double.infinity, 64),
          splashFactory: InkSparkle.splashFactory,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          elevation: 12,
          shadowColor: primaryGold.withOpacity(0.7),
          textStyle: GoogleFonts.outfit(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }
}

