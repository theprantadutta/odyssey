import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_sizes.dart';
import 'app_typography.dart';
import 'odyssey_tokens.dart';

/// Odyssey 2.0 themes.
///
/// Both `ThemeData` objects are built from the same token table — see
/// [OdysseyTokens], which rides along as a theme extension and carries
/// everything Material's [ColorScheme] has no slot for.
///
/// Material's own widgets are configured here mostly so that anything not yet
/// hand-built (a stray `Dialog`, a `SnackBar`, the text-selection handles)
/// lands on-system rather than shipping Material's purple defaults. The
/// screens themselves draw their own surfaces.
class AppTheme {
  AppTheme._();

  static ThemeData get darkTheme => _build(OdysseyTokens.dark);

  static ThemeData get lightTheme => _build(OdysseyTokens.light);

  static ThemeData _build(OdysseyTokens t) {
    final isDark = t.isDark;
    final brightness = isDark ? Brightness.dark : Brightness.light;

    // An opaque equivalent of the translucent card fill. Material widgets that
    // paint their own background (menus, dialogs, bottom sheets) need a solid
    // colour or they read as muddy over the canvas.
    final opaqueCard = Color.alphaBlend(t.card, t.canvas);
    final opaqueCardAlt = Color.alphaBlend(t.cardAlt, t.canvas);

    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: t.action,
      onPrimary: t.onAction,
      primaryContainer: opaqueCardAlt,
      onPrimaryContainer: t.ink,
      secondary: AppColors.accent,
      onSecondary: AppColors.onAccent,
      secondaryContainer: t.accentTint,
      onSecondaryContainer: t.ink,
      tertiary: t.ink2,
      onTertiary: t.canvas,
      surface: t.canvas,
      onSurface: t.ink,
      surfaceContainerLowest: t.canvas,
      surfaceContainerLow: t.sheet,
      surfaceContainer: opaqueCard,
      surfaceContainerHigh: opaqueCardAlt,
      surfaceContainerHighest: opaqueCardAlt,
      onSurfaceVariant: t.ink2,
      outline: t.hairlineStrong,
      outlineVariant: t.hairline,
      // No red exists in this palette; failure is signalled with copy.
      error: t.ink,
      onError: t.canvas,
      errorContainer: opaqueCard,
      onErrorContainer: t.ink,
      inverseSurface: t.invert,
      onInverseSurface: t.onInvert,
      inversePrimary: t.actionGlyph,
      shadow: Colors.transparent,
      scrim: AppColors.photoTagBg,
    );

    final textTheme = _textTheme(t);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: t.canvas,
      canvasColor: t.canvas,
      splashColor: t.pressTint,
      highlightColor: t.pressTint,
      dividerColor: t.separator,
      shadowColor: Colors.transparent,
      fontFamily: AppTypography.ui,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      extensions: <ThemeExtension<dynamic>>[t],

      // The status bar sits over content on every screen, so its glyphs have
      // to contrast with the canvas rather than with an app bar.
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: t.ink,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: AppTypography.sectionHeading.copyWith(color: t.ink),
        iconTheme: IconThemeData(color: t.ink, size: AppSizes.iconLg),
        actionsIconTheme: IconThemeData(color: t.ink, size: AppSizes.iconLg),
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light.copyWith(
                statusBarColor: Colors.transparent,
                systemNavigationBarColor: AppColors.darkCanvas,
                systemNavigationBarIconBrightness: Brightness.light,
              )
            : SystemUiOverlayStyle.dark.copyWith(
                statusBarColor: Colors.transparent,
                systemNavigationBarColor: AppColors.lightCanvas,
                systemNavigationBarIconBrightness: Brightness.dark,
              ),
      ),

      cardTheme: CardThemeData(
        elevation: 0,
        color: opaqueCard,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusRow),
          side: BorderSide(color: t.hairline),
        ),
      ),

      // Input fields in this design are card boxes with a mono eyebrow above
      // the value, and focus is a lime border rather than a colour shift. See
      // `FieldCard`, which is what the screens actually use; this theme covers
      // the bare `TextField`s that remain.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: opaqueCard,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSizes.space18,
          vertical: AppSizes.space16,
        ),
        border: _fieldBorder(t.hairline),
        enabledBorder: _fieldBorder(t.hairline),
        focusedBorder: _fieldBorder(AppColors.accent),
        disabledBorder: _fieldBorder(t.hairline),
        errorBorder: _fieldBorder(t.ink2),
        focusedErrorBorder: _fieldBorder(t.ink2),
        hintStyle: AppTypography.placeholder.copyWith(color: t.ink3),
        labelStyle: AppTypography.eyebrow.copyWith(color: t.ink3),
        floatingLabelStyle: AppTypography.eyebrow.copyWith(color: t.ink3),
        helperStyle: AppTypography.rowMeta.copyWith(color: t.ink3),
        errorStyle: AppTypography.rowMeta.copyWith(color: t.ink2),
        prefixIconColor: t.ink3,
        suffixIconColor: t.ink3,
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: t.action,
          foregroundColor: t.onAction,
          disabledBackgroundColor: t.cardAlt,
          disabledForegroundColor: t.ink3,
          shadowColor: Colors.transparent,
          minimumSize: const Size(0, AppSizes.buttonHeightLg),
          padding: const EdgeInsets.symmetric(horizontal: AppSizes.space24),
          textStyle: AppTypography.button,
          shape: const StadiumBorder(),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          elevation: 0,
          backgroundColor: t.action,
          foregroundColor: t.onAction,
          disabledBackgroundColor: t.cardAlt,
          disabledForegroundColor: t.ink3,
          minimumSize: const Size(0, AppSizes.buttonHeightLg),
          padding: const EdgeInsets.symmetric(horizontal: AppSizes.space24),
          textStyle: AppTypography.button,
          shape: const StadiumBorder(),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: t.ink2,
          minimumSize: const Size(0, AppSizes.buttonHeightMd),
          padding: const EdgeInsets.symmetric(horizontal: AppSizes.space24),
          textStyle: AppTypography.buttonSmall,
          side: BorderSide(color: t.hairlineStrong),
          shape: const StadiumBorder(),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: t.ink,
          textStyle: AppTypography.buttonSmall,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.space12,
            vertical: AppSizes.space8,
          ),
          shape: const StadiumBorder(),
        ),
      ),

      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: t.ink,
          highlightColor: t.pressTint,
          shape: const CircleBorder(),
        ),
      ),

      iconTheme: IconThemeData(color: t.ink, size: AppSizes.iconLg),

      // The real nav is a floating glass pill (`OdysseyNavBar`); this only
      // catches any Material nav that slips through.
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        backgroundColor: opaqueCard,
        surfaceTintColor: Colors.transparent,
        indicatorColor: t.action,
        indicatorShape: const StadiumBorder(),
        labelTextStyle: WidgetStatePropertyAll(
          AppTypography.navLabel.copyWith(color: t.ink2),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: AppSizes.iconMd,
            color: states.contains(WidgetState.selected) ? t.onAction : t.ink3,
          ),
        ),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: Color.alphaBlend(t.sheet, t.canvas),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        modalElevation: 0,
        showDragHandle: true,
        dragHandleColor: t.ink3,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppSizes.radiusSheet),
          ),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: opaqueCard,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: AppTypography.cardTitleLarge.copyWith(color: t.ink),
        contentTextStyle: AppTypography.subtitle.copyWith(color: t.ink2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusPanel),
          side: BorderSide(color: t.hairline),
        ),
      ),

      // No red: a failed action says so in copy, on the same surface as any
      // other message.
      snackBarTheme: SnackBarThemeData(
        backgroundColor: t.invert,
        contentTextStyle: AppTypography.rowMeta.copyWith(color: t.onInvert),
        actionTextColor: isDark ? AppColors.limeInk : AppColors.accent,
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        insetPadding: const EdgeInsets.fromLTRB(
          AppSizes.screenPadding,
          0,
          AppSizes.screenPadding,
          AppSizes.space20,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusRow),
        ),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: opaqueCard,
        selectedColor: t.action,
        disabledColor: t.cardAlt,
        labelStyle: AppTypography.chip.copyWith(color: t.ink2),
        secondaryLabelStyle: AppTypography.chip.copyWith(color: t.onAction),
        side: BorderSide(color: t.hairline),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.space14,
          vertical: AppSizes.space8,
        ),
        showCheckmark: false,
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? (isDark ? AppColors.obsidian : AppColors.accent)
              : (isDark ? AppColors.darkInk2 : Colors.white),
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? t.action
              : (isDark ? AppColors.darkCardAlt : AppColors.lightDashed),
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
        thumbIcon: const WidgetStatePropertyAll(null),
      ),

      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? t.action
              : Colors.transparent,
        ),
        checkColor: WidgetStatePropertyAll(t.onAction),
        side: BorderSide(color: t.ink3, width: AppSizes.ringWidth),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusChipXs),
        ),
      ),

      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? t.action : t.ink3,
        ),
      ),

      sliderTheme: SliderThemeData(
        activeTrackColor: t.action,
        inactiveTrackColor: t.track,
        thumbColor: t.action,
        overlayColor: t.pressTint,
        trackHeight: AppSizes.progressHeight,
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: t.action,
        linearTrackColor: t.track,
        circularTrackColor: t.track,
        linearMinHeight: AppSizes.progressHeight,
      ),

      tabBarTheme: TabBarThemeData(
        labelColor: t.ink,
        unselectedLabelColor: t.ink3,
        labelStyle: AppTypography.tab,
        unselectedLabelStyle: AppTypography.chip,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        indicator: BoxDecoration(
          color: t.invert,
          borderRadius: BorderRadius.circular(AppSizes.radiusFull),
        ),
      ),

      listTileTheme: ListTileThemeData(
        iconColor: t.ink2,
        textColor: t.ink,
        titleTextStyle: AppTypography.rowLabel.copyWith(color: t.ink),
        subtitleTextStyle: AppTypography.rowMeta.copyWith(color: t.ink3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusRow),
        ),
      ),

      dividerTheme: DividerThemeData(
        color: t.separator,
        thickness: AppSizes.hairlineWidth,
        space: AppSizes.hairlineWidth,
      ),

      popupMenuTheme: PopupMenuThemeData(
        color: opaqueCardAlt,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        textStyle: AppTypography.rowLabel.copyWith(color: t.ink),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
          side: BorderSide(color: t.hairline),
        ),
      ),

      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: t.invert,
          borderRadius: BorderRadius.circular(AppSizes.radiusChip),
        ),
        textStyle: AppTypography.rowMeta.copyWith(color: t.onInvert),
      ),

      drawerTheme: DrawerThemeData(
        backgroundColor: Color.alphaBlend(t.sheet, t.canvas),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.horizontal(
            right: Radius.circular(AppSizes.radiusSheet),
          ),
        ),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        backgroundColor: t.action,
        foregroundColor: t.onAction,
        shape: const CircleBorder(),
      ),

      textSelectionTheme: TextSelectionThemeData(
        cursorColor: AppColors.accent,
        selectionColor: AppColors.accent.withValues(alpha: 0.30),
        selectionHandleColor: AppColors.accent,
      ),

      splashFactory: InkSparkle.splashFactory,

      // No scrollbars. "Chrome reduced to floating glass pills" leaves no room
      // for a grey rail down the edge of every screen, and on a phone the
      // gesture already tells the user where they are.
      scrollbarTheme: const ScrollbarThemeData(
        thumbVisibility: WidgetStatePropertyAll(false),
        thickness: WidgetStatePropertyAll(0),
        thumbColor: WidgetStatePropertyAll(Colors.transparent),
      ),

      // A quiet horizontal fade on every platform. Cupertino's slide builder
      // no longer ships in `package:flutter/material.dart` (Material and
      // Cupertino are being split into standalone packages), and the design's
      // motion spec is restrained enough that the fade is the better fit than
      // the zoom anyway.
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
        },
      ),
    );
  }

  static OutlineInputBorder _fieldBorder(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppSizes.radiusInput),
    borderSide: BorderSide(color: color, width: AppSizes.hairlineWidth),
  );

  /// Maps the design's type roles onto Material's slots, so widgets that read
  /// `Theme.of(context).textTheme` land somewhere sensible. Screens should
  /// prefer [AppTypography] directly — the roles there are named for what they
  /// are rather than for Material's size ladder.
  static TextTheme _textTheme(OdysseyTokens t) {
    final ink = t.ink;
    final ink2 = t.ink2;
    final ink3 = t.ink3;
    return TextTheme(
      displayLarge: AppTypography.statGiant.copyWith(color: ink),
      displayMedium: AppTypography.heroTitle.copyWith(color: ink),
      displaySmall: AppTypography.screenTitle.copyWith(color: ink),
      headlineLarge: AppTypography.statSection.copyWith(color: ink),
      headlineMedium: AppTypography.statCard.copyWith(color: ink),
      headlineSmall: AppTypography.statSmall.copyWith(color: ink),
      titleLarge: AppTypography.sectionHeading.copyWith(color: ink),
      titleMedium: AppTypography.cardTitleXl.copyWith(color: ink),
      titleSmall: AppTypography.rowTitle.copyWith(color: ink),
      bodyLarge: AppTypography.body.copyWith(color: ink),
      bodyMedium: AppTypography.subtitle.copyWith(color: ink2),
      bodySmall: AppTypography.rowMeta.copyWith(color: ink3),
      labelLarge: AppTypography.button.copyWith(color: ink),
      labelMedium: AppTypography.chip.copyWith(color: ink2),
      labelSmall: AppTypography.eyebrow.copyWith(color: ink3),
    );
  }
}
