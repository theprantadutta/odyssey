import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';
import 'app_typography.dart';
import 'app_sizes.dart';

/// Odyssey App Theme Configuration
class AppTheme {
  AppTheme._(); // Private constructor

  /// Light Theme (Primary theme - Cinematic Dark with Gold accents)
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,

      // Color Scheme
      colorScheme: ColorScheme.light(
        primary: AppColors.midnightBlue,
        secondary: AppColors.sunsetGold,
        tertiary: AppColors.navyAccent,
        surface: AppColors.frostedWhite,
        error: AppColors.error,
        onPrimary: AppColors.textOnDark,
        onSecondary: AppColors.midnightBlue,
        onSurface: AppColors.textPrimary,
        onError: Colors.white,
      ),

      // Scaffold
      scaffoldBackgroundColor: AppColors.frostedWhite,

      // App Bar Theme
      appBarTheme: AppBarTheme(
        elevation: AppSizes.appBarElevation,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        centerTitle: false,
        titleTextStyle: AppTypography.headlineSmall.copyWith(
          color: AppColors.textPrimary,
        ),
      ),

      // Card Theme
      cardTheme: CardThemeData(
        elevation: AppSizes.cardElevation,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        ),
        color: Colors.white,
        margin: EdgeInsets.zero,
      ),

      // Bottom Navigation Bar
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        elevation: 0,
        backgroundColor: Colors.white,
        selectedItemColor: AppColors.sunsetGold,
        unselectedItemColor: AppColors.textTertiary,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: AppTypography.labelSmall,
        unselectedLabelStyle: AppTypography.labelSmall,
      ),

      // Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSizes.space16,
          vertical: AppSizes.space16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          borderSide: const BorderSide(color: AppColors.textTertiary, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          borderSide: const BorderSide(color: AppColors.textTertiary, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          borderSide: const BorderSide(color: AppColors.sunsetGold, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          borderSide: const BorderSide(color: AppColors.error, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          borderSide: const BorderSide(color: AppColors.error, width: 2),
        ),
        labelStyle: AppTypography.bodyMedium.copyWith(
          color: AppColors.textSecondary,
        ),
        hintStyle: AppTypography.bodyMedium.copyWith(
          color: AppColors.textTertiary,
        ),
      ),

      // Elevated Button Theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: AppColors.sunsetGold,
          foregroundColor: AppColors.midnightBlue,
          minimumSize: const Size.fromHeight(AppSizes.buttonHeightMd),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          ),
          textStyle: AppTypography.labelLarge,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.space24,
            vertical: AppSizes.space16,
          ),
        ),
      ),

      // Text Button Theme
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.sunsetGold,
          textStyle: AppTypography.labelLarge,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.space16,
            vertical: AppSizes.space12,
          ),
        ),
      ),

      // Outlined Button Theme
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.midnightBlue,
          side: const BorderSide(color: AppColors.midnightBlue, width: 1.5),
          minimumSize: const Size.fromHeight(AppSizes.buttonHeightMd),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          ),
          textStyle: AppTypography.labelLarge,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.space24,
            vertical: AppSizes.space16,
          ),
        ),
      ),

      // Chip Theme
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.paleGold,
        deleteIconColor: AppColors.midnightBlue,
        selectedColor: AppColors.sunsetGold,
        secondarySelectedColor: AppColors.softGold,
        labelStyle: AppTypography.labelSmall.copyWith(
          color: AppColors.midnightBlue,
        ),
        secondaryLabelStyle: AppTypography.labelSmall,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.space12,
          vertical: AppSizes.space8,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusFull),
        ),
      ),

      // Floating Action Button Theme
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.sunsetGold,
        foregroundColor: AppColors.midnightBlue,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        ),
      ),

      // Divider Theme
      dividerTheme: const DividerThemeData(
        color: AppColors.textTertiary,
        thickness: 0.5,
        space: AppSizes.space16,
      ),

      // Text Theme
      textTheme: TextTheme(
        displayLarge: AppTypography.displayLarge,
        displayMedium: AppTypography.displayMedium,
        displaySmall: AppTypography.displaySmall,
        headlineLarge: AppTypography.headlineLarge,
        headlineMedium: AppTypography.headlineMedium,
        headlineSmall: AppTypography.headlineSmall,
        titleLarge: AppTypography.titleLarge,
        titleMedium: AppTypography.titleMedium,
        titleSmall: AppTypography.titleSmall,
        bodyLarge: AppTypography.bodyLarge,
        bodyMedium: AppTypography.bodyMedium,
        bodySmall: AppTypography.bodySmall,
        labelLarge: AppTypography.labelLarge,
        labelMedium: AppTypography.labelMedium,
        labelSmall: AppTypography.labelSmall,
      ),

      // Icon Theme
      iconTheme: const IconThemeData(
        color: AppColors.textPrimary,
        size: AppSizes.iconMd,
      ),

      // Progress Indicator Theme
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.sunsetGold,
      ),
    );
  }

  /// Dark Theme (Alternative - Deep navy background)
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,

      // Color Scheme
      colorScheme: ColorScheme.dark(
        primary: AppColors.sunsetGold,
        secondary: AppColors.softGold,
        tertiary: AppColors.navyAccent,
        surface: AppColors.deepNavy,
        error: AppColors.error,
        onPrimary: AppColors.midnightBlue,
        onSecondary: AppColors.midnightBlue,
        onSurface: AppColors.textOnDark,
        onError: Colors.white,
      ),

      // Scaffold
      scaffoldBackgroundColor: AppColors.midnightBlue,

      // App Bar Theme
      appBarTheme: AppBarTheme(
        elevation: AppSizes.appBarElevation,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textOnDark,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        centerTitle: false,
        titleTextStyle: AppTypography.headlineSmall.copyWith(
          color: AppColors.textOnDark,
        ),
      ),

      // Card Theme
      cardTheme: CardThemeData(
        elevation: AppSizes.cardElevation,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        ),
        color: AppColors.deepNavy,
        margin: EdgeInsets.zero,
      ),

      // Bottom Navigation Bar
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        elevation: 0,
        backgroundColor: AppColors.deepNavy,
        selectedItemColor: AppColors.sunsetGold,
        unselectedItemColor: AppColors.textTertiary,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: AppTypography.labelSmall,
        unselectedLabelStyle: AppTypography.labelSmall,
      ),

      // Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.navyAccent,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSizes.space16,
          vertical: AppSizes.space16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          borderSide: const BorderSide(color: AppColors.navyAccent, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          borderSide: const BorderSide(color: AppColors.navyAccent, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          borderSide: const BorderSide(color: AppColors.sunsetGold, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          borderSide: const BorderSide(color: AppColors.error, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          borderSide: const BorderSide(color: AppColors.error, width: 2),
        ),
        labelStyle: AppTypography.bodyMedium.copyWith(
          color: AppColors.textSecondary,
        ),
        hintStyle: AppTypography.bodyMedium.copyWith(
          color: AppColors.textTertiary,
        ),
      ),

      // Elevated Button Theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: AppColors.sunsetGold,
          foregroundColor: AppColors.midnightBlue,
          minimumSize: const Size.fromHeight(AppSizes.buttonHeightMd),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          ),
          textStyle: AppTypography.labelLarge,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.space24,
            vertical: AppSizes.space16,
          ),
        ),
      ),

      // Text Button Theme
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.sunsetGold,
          textStyle: AppTypography.labelLarge,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.space16,
            vertical: AppSizes.space12,
          ),
        ),
      ),

      // Outlined Button Theme
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.sunsetGold,
          side: const BorderSide(color: AppColors.sunsetGold, width: 1.5),
          minimumSize: const Size.fromHeight(AppSizes.buttonHeightMd),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          ),
          textStyle: AppTypography.labelLarge,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.space24,
            vertical: AppSizes.space16,
          ),
        ),
      ),

      // Chip Theme
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.navyAccent,
        deleteIconColor: AppColors.textOnDark,
        selectedColor: AppColors.sunsetGold,
        secondarySelectedColor: AppColors.softGold,
        labelStyle: AppTypography.labelSmall.copyWith(
          color: AppColors.textOnDark,
        ),
        secondaryLabelStyle: AppTypography.labelSmall,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.space12,
          vertical: AppSizes.space8,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusFull),
        ),
      ),

      // Floating Action Button Theme
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.sunsetGold,
        foregroundColor: AppColors.midnightBlue,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        ),
      ),

      // Divider Theme
      dividerTheme: const DividerThemeData(
        color: AppColors.navyAccent,
        thickness: 0.5,
        space: AppSizes.space16,
      ),

      // Text Theme
      textTheme: TextTheme(
        displayLarge: AppTypography.displayLarge.copyWith(
          color: AppColors.textOnDark,
        ),
        displayMedium: AppTypography.displayMedium.copyWith(
          color: AppColors.textOnDark,
        ),
        displaySmall: AppTypography.displaySmall.copyWith(
          color: AppColors.textOnDark,
        ),
        headlineLarge: AppTypography.headlineLarge.copyWith(
          color: AppColors.textOnDark,
        ),
        headlineMedium: AppTypography.headlineMedium.copyWith(
          color: AppColors.textOnDark,
        ),
        headlineSmall: AppTypography.headlineSmall.copyWith(
          color: AppColors.textOnDark,
        ),
        titleLarge: AppTypography.titleLarge.copyWith(
          color: AppColors.textOnDark,
        ),
        titleMedium: AppTypography.titleMedium.copyWith(
          color: AppColors.textOnDark,
        ),
        titleSmall: AppTypography.titleSmall.copyWith(
          color: AppColors.textOnDark,
        ),
        bodyLarge: AppTypography.bodyLarge.copyWith(
          color: AppColors.textOnDark,
        ),
        bodyMedium: AppTypography.bodyMedium.copyWith(
          color: AppColors.textOnDark,
        ),
        bodySmall: AppTypography.bodySmall.copyWith(
          color: AppColors.textOnDark,
        ),
        labelLarge: AppTypography.labelLarge,
        labelMedium: AppTypography.labelMedium,
        labelSmall: AppTypography.labelSmall,
      ),

      // Icon Theme
      iconTheme: const IconThemeData(
        color: AppColors.textOnDark,
        size: AppSizes.iconMd,
      ),

      // Progress Indicator Theme
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.sunsetGold,
      ),
    );
  }
}
