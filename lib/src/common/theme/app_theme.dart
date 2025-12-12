import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';
import 'app_typography.dart';
import 'app_sizes.dart';

/// Odyssey App Theme Configuration - Vibrant & Playful
/// Light, friendly design inspired by Duolingo and Headspace
class AppTheme {
  AppTheme._(); // Private constructor

  /// Light Theme (Primary - Vibrant & Playful)
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,

      // Color Scheme - Sunny Yellow as hero
      colorScheme: const ColorScheme.light(
        primary: AppColors.sunnyYellow,
        onPrimary: AppColors.charcoal,
        secondary: AppColors.oceanTeal,
        onSecondary: AppColors.pureWhite,
        tertiary: AppColors.coralBurst,
        onTertiary: AppColors.pureWhite,
        surface: AppColors.snowWhite,
        onSurface: AppColors.charcoal,
        surfaceContainerHighest: AppColors.cloudGray,
        error: AppColors.error,
        onError: AppColors.pureWhite,
      ),

      // Scaffold - Light background
      scaffoldBackgroundColor: AppColors.cloudGray,

      // App Bar Theme - Light and airy
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.charcoal,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        centerTitle: false,
        titleTextStyle: AppTypography.headlineMedium.copyWith(
          color: AppColors.charcoal,
        ),
        iconTheme: const IconThemeData(
          color: AppColors.charcoal,
        ),
      ),

      // Card Theme - White with soft shadows
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        ),
        color: AppColors.snowWhite,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
      ),

      // Bottom Navigation Bar - Clean with yellow accent
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        elevation: 0,
        backgroundColor: AppColors.snowWhite,
        selectedItemColor: AppColors.sunnyYellow,
        unselectedItemColor: AppColors.mutedGray,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: AppTypography.labelSmall.copyWith(
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: AppTypography.labelSmall,
      ),

      // Input Decoration Theme - Rounded and friendly
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.warmGray,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSizes.space20,
          vertical: AppSizes.space16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          borderSide: BorderSide(
            color: AppColors.mutedGray.withValues(alpha: 0.3),
            width: AppSizes.inputBorderWidth,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          borderSide: const BorderSide(
            color: AppColors.sunnyYellow,
            width: AppSizes.inputFocusBorderWidth,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          borderSide: const BorderSide(
            color: AppColors.error,
            width: AppSizes.inputBorderWidth,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          borderSide: const BorderSide(
            color: AppColors.error,
            width: AppSizes.inputFocusBorderWidth,
          ),
        ),
        labelStyle: AppTypography.bodyMedium.copyWith(
          color: AppColors.slate,
        ),
        hintStyle: AppTypography.bodyMedium.copyWith(
          color: AppColors.mutedGray,
        ),
        prefixIconColor: AppColors.slate,
        suffixIconColor: AppColors.slate,
      ),

      // Elevated Button Theme - Yellow with glow
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: AppColors.sunnyYellow,
          foregroundColor: AppColors.charcoal,
          disabledBackgroundColor: AppColors.mutedGray.withValues(alpha: 0.3),
          disabledForegroundColor: AppColors.mutedGray,
          minimumSize: const Size.fromHeight(AppSizes.buttonHeightMd),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          ),
          textStyle: AppTypography.button,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.space24,
            vertical: AppSizes.space16,
          ),
        ),
      ),

      // Text Button Theme
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.sunnyYellow,
          textStyle: AppTypography.labelLarge,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.space16,
            vertical: AppSizes.space12,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusSm),
          ),
        ),
      ),

      // Outlined Button Theme
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.sunnyYellow,
          side: const BorderSide(
            color: AppColors.sunnyYellow,
            width: 2,
          ),
          minimumSize: const Size.fromHeight(AppSizes.buttonHeightMd),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          ),
          textStyle: AppTypography.button,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.space24,
            vertical: AppSizes.space16,
          ),
        ),
      ),

      // Chip Theme - Colorful and playful
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.softCream,
        deleteIconColor: AppColors.charcoal,
        selectedColor: AppColors.sunnyYellow,
        secondarySelectedColor: AppColors.goldenGlow,
        disabledColor: AppColors.warmGray,
        labelStyle: AppTypography.labelSmall.copyWith(
          color: AppColors.charcoal,
        ),
        secondaryLabelStyle: AppTypography.labelSmall,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.space12,
          vertical: AppSizes.space8,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusFull),
        ),
        side: BorderSide.none,
      ),

      // Floating Action Button Theme - Yellow with bounce
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.sunnyYellow,
        foregroundColor: AppColors.charcoal,
        elevation: 8,
        focusElevation: 12,
        hoverElevation: 12,
        highlightElevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        ),
        extendedTextStyle: AppTypography.labelLarge.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),

      // Divider Theme
      dividerTheme: DividerThemeData(
        color: AppColors.mutedGray.withValues(alpha: 0.2),
        thickness: 1,
        space: AppSizes.space16,
      ),

      // Text Theme
      textTheme: TextTheme(
        displayLarge: AppTypography.displayLarge.copyWith(
          color: AppColors.charcoal,
        ),
        displayMedium: AppTypography.displayMedium.copyWith(
          color: AppColors.charcoal,
        ),
        displaySmall: AppTypography.displaySmall.copyWith(
          color: AppColors.charcoal,
        ),
        headlineLarge: AppTypography.headlineLarge.copyWith(
          color: AppColors.charcoal,
        ),
        headlineMedium: AppTypography.headlineMedium.copyWith(
          color: AppColors.charcoal,
        ),
        headlineSmall: AppTypography.headlineSmall.copyWith(
          color: AppColors.charcoal,
        ),
        titleLarge: AppTypography.titleLarge.copyWith(
          color: AppColors.charcoal,
        ),
        titleMedium: AppTypography.titleMedium.copyWith(
          color: AppColors.charcoal,
        ),
        titleSmall: AppTypography.titleSmall.copyWith(
          color: AppColors.charcoal,
        ),
        bodyLarge: AppTypography.bodyLarge.copyWith(
          color: AppColors.charcoal,
        ),
        bodyMedium: AppTypography.bodyMedium.copyWith(
          color: AppColors.charcoal,
        ),
        bodySmall: AppTypography.bodySmall.copyWith(
          color: AppColors.slate,
        ),
        labelLarge: AppTypography.labelLarge.copyWith(
          color: AppColors.charcoal,
        ),
        labelMedium: AppTypography.labelMedium.copyWith(
          color: AppColors.charcoal,
        ),
        labelSmall: AppTypography.labelSmall.copyWith(
          color: AppColors.slate,
        ),
      ),

      // Icon Theme
      iconTheme: const IconThemeData(
        color: AppColors.charcoal,
        size: AppSizes.iconMd,
      ),

      // Progress Indicator Theme - Yellow
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.sunnyYellow,
        circularTrackColor: AppColors.lemonLight,
        linearTrackColor: AppColors.lemonLight,
      ),

      // Tab Bar Theme
      tabBarTheme: TabBarThemeData(
        indicatorColor: AppColors.sunnyYellow,
        labelColor: AppColors.charcoal,
        unselectedLabelColor: AppColors.mutedGray,
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: AppTypography.labelLarge,
        unselectedLabelStyle: AppTypography.labelLarge,
      ),

      // Dialog Theme
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.snowWhite,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusXl),
        ),
        titleTextStyle: AppTypography.headlineSmall.copyWith(
          color: AppColors.charcoal,
        ),
        contentTextStyle: AppTypography.bodyMedium.copyWith(
          color: AppColors.slate,
        ),
      ),

      // Bottom Sheet Theme
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: AppColors.snowWhite,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppSizes.radiusXl),
          ),
        ),
        dragHandleColor: AppColors.mutedGray.withValues(alpha: 0.3),
        dragHandleSize: const Size(40, 4),
      ),

      // Snackbar Theme
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.charcoal,
        contentTextStyle: AppTypography.bodyMedium.copyWith(
          color: AppColors.pureWhite,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        ),
        behavior: SnackBarBehavior.floating,
      ),

      // Slider Theme
      sliderTheme: SliderThemeData(
        activeTrackColor: AppColors.sunnyYellow,
        inactiveTrackColor: AppColors.lemonLight,
        thumbColor: AppColors.sunnyYellow,
        overlayColor: AppColors.sunnyYellow.withValues(alpha: 0.2),
      ),

      // Switch Theme
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.sunnyYellow;
          }
          return AppColors.mutedGray;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.lemonLight;
          }
          return AppColors.warmGray;
        }),
      ),

      // Checkbox Theme
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.sunnyYellow;
          }
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(AppColors.charcoal),
        side: const BorderSide(
          color: AppColors.mutedGray,
          width: 2,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusXs),
        ),
      ),

      // Radio Theme
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.sunnyYellow;
          }
          return AppColors.mutedGray;
        }),
      ),

      // List Tile Theme
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSizes.space16,
          vertical: AppSizes.space8,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        ),
        titleTextStyle: AppTypography.titleMedium,
        subtitleTextStyle: AppTypography.bodySmall.copyWith(
          color: AppColors.slate,
        ),
      ),

      // Date Picker Theme
      datePickerTheme: DatePickerThemeData(
        backgroundColor: AppColors.snowWhite,
        surfaceTintColor: Colors.transparent,
        headerBackgroundColor: AppColors.sunnyYellow,
        headerForegroundColor: AppColors.charcoal,
        dayStyle: AppTypography.bodyMedium,
        todayBorder: const BorderSide(
          color: AppColors.sunnyYellow,
          width: 2,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusXl),
        ),
      ),

      // Time Picker Theme
      timePickerTheme: TimePickerThemeData(
        backgroundColor: AppColors.snowWhite,
        hourMinuteColor: AppColors.softCream,
        dayPeriodColor: AppColors.softCream,
        dialBackgroundColor: AppColors.softCream,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusXl),
        ),
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
