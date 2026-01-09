import 'package:flutter/material.dart';

class AppColors {
  // Primary Colors (Dark Purple Gradient)
  static const Color primaryDark = Color(0xFF2D1B69); // Darkest purple
  static const Color primary = Color.fromARGB(
    255,
    79,
    27,
    126,
  ); // Medium purple
  static const Color primaryLight = Color(0xFF6B46C1); // Light purple
  static const Color primaryAccent = Color(0xFF9F7AEA); // Accent purple

  // Secondary Colors
  static const Color secondary = Color(0xFF2D1B69); // Teal accent
  static const Color secondaryDark = Color.fromARGB(
    255,
    70,
    26,
    123,
  ); // Dark teal

  // Neutral Colors
  static const Color neutralDark = Color(0xFF1A202C);
  static const Color neutralGray = Color(0xFF718096);
  static const Color neutralLight = Color(0xFFF7FAFC);
  static const Color white = Color(0xFFFFFFFF);

  // Status Colors
  static const Color success = Color(0xFF38B2AC); // Success in teal
  static const Color warning = Color(0xFFED8936); // Orange warning
  static const Color error = Color(0xFFE53E3E); // Red erro
  static const Color info = Color(0xFF3182CE); // Blue info
}

class AppTheme {
  static ThemeData lightTheme = ThemeData(
    // Primary Colors with Purple Gradient
    primaryColor: AppColors.primary,
    primaryColorDark: AppColors.primaryDark,
    primaryColorLight: const Color.fromARGB(255, 76, 44, 128),
    scaffoldBackgroundColor: AppColors.neutralLight,

    // Color Scheme
    colorScheme: const ColorScheme.light(
      primary: AppColors.primary,
      secondary: AppColors.secondary,
      surface: AppColors.white,
      error: AppColors.error,
      onPrimary: AppColors.white,
      onSecondary: AppColors.white,
      onSurface: AppColors.neutralDark,
      onError: AppColors.white,
    ),

    // App Bar with Purple Gradient
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.white,
      elevation: 4,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: AppColors.white,
      ),
    ),

    // Buttons with Purple Gradient
    elevatedButtonTheme: ElevatedButtonThemeData(
      style:
          ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.white,
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            // Create gradient effect
            shadowColor: AppColors.primaryDark.withOpacity(0.3),
            elevation: 4,
          ).copyWith(
            overlayColor: WidgetStateProperty.all(
              AppColors.primaryAccent.withOpacity(0.1),
            ),
          ),
    ),

    // Filled Button with Gradient
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),

    // Text Fields
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.neutralGray),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.neutralGray),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      filled: true,
      fillColor: AppColors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      labelStyle: const TextStyle(color: AppColors.neutralGray),
      hintStyle: const TextStyle(color: AppColors.neutralGray),
      floatingLabelStyle: const TextStyle(color: AppColors.primary),
    ),

    // Cards with subtle gradient
    cardTheme: CardThemeData(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: AppColors.white,
      shadowColor: const Color.fromARGB(255, 62, 26, 101).withOpacity(0.1),
      surfaceTintColor: AppColors.primaryLight.withOpacity(0.05),
    ),

    // Bottom Navigation Bar
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.white,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.neutralGray,
      elevation: 8,
    ),

    // Navigation Bar
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.white,
      indicatorColor: AppColors.primaryLight.withOpacity(0.2),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const TextStyle(
            fontWeight: FontWeight.w600,
            color: AppColors.primary,
          );
        }
        return const TextStyle(
          fontWeight: FontWeight.normal,
          color: AppColors.neutralGray,
        );
      }),
    ),

    // Tab Bar
    tabBarTheme: const TabBarThemeData(
      indicatorColor: AppColors.primary,
      labelColor: AppColors.primary,
      unselectedLabelColor: AppColors.neutralGray,
      indicatorSize: TabBarIndicatorSize.tab,
    ),

    // Progress Indicators
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: Color.fromARGB(255, 74, 27, 115),
      circularTrackColor: AppColors.neutralLight,
    ),

    // Text Theme
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.w800,
        color: AppColors.neutralDark,
      ),
      displayMedium: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: AppColors.neutralDark,
      ),
      displaySmall: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: AppColors.neutralDark,
      ),
      headlineMedium: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: AppColors.neutralDark,
      ),
      headlineSmall: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: AppColors.neutralDark,
      ),
      titleLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.neutralDark,
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.normal,
        color: AppColors.neutralDark,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.normal,
        color: AppColors.neutralGray,
      ),
      labelLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.primary,
      ),
    ),

    // Divider
    dividerTheme: const DividerThemeData(
      color: Color(0xFFE2E8F0),
      thickness: 1,
      space: 0,
    ),

    // Use Material 3
    useMaterial3: true,
  );

  // Extension untuk gradient yang mudah digunakan
  static LinearGradient get primaryGradient => const LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color.fromARGB(255, 75, 29, 104),
      AppColors.primary,
      AppColors.primaryLight,
    ],
  );

  static LinearGradient get accentGradient => const LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.primary, AppColors.primaryAccent],
  );

  // Background gradient untuk semua halaman
  static LinearGradient get pageBackgroundGradient => const LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color.fromARGB(255, 110, 70, 140),
      Color.fromARGB(255, 160, 120, 180),
      Color.fromARGB(255, 245, 240, 250),
    ],
  );
}
