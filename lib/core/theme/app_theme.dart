import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants/app_colors.dart';
import '../constants/app_spacing.dart';

/// Centralized Material 3 themes for AR Smart Menu (Light & Dark).
/// Features crisp borders, sleek dark mode matching modern food delivery design.
class AppTheme {
  AppTheme._();

  static ThemeData _buildTheme({
    required Brightness brightness,
    required ColorScheme colorScheme,
    required Color scaffoldBg,
    required Color appBarBg,
    required Color appBarFg,
    required SystemUiOverlayStyle overlayStyle,
    required Color cardBg,
    required Color cardBorder,
    required Color primaryBtnBg,
    required Color primaryBtnFg,
    required Color navBarBg,
    required Color navActive,
    required Color navInactive,
    required Color navIndicator,
    required Color inputFill,
    required Color inputBorder,
    required Color dividerColor,
    required Color segmentedSelectedBg,
    required Color segmentedSelectedFg,
    required Color segmentedUnselectedBg,
    required Color segmentedUnselectedFg,
  }) {
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: scaffoldBg,
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: true,
        backgroundColor: appBarBg,
        foregroundColor: appBarFg,
        systemOverlayStyle: overlayStyle,
        iconTheme: IconThemeData(color: appBarFg),
        titleTextStyle: TextStyle(color: appBarFg, fontSize: 18, fontWeight: FontWeight.bold),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          side: BorderSide(color: cardBorder, width: 1.0),
        ),
        margin: EdgeInsets.zero,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: cardBorder, width: 1.0),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBtnBg,
          foregroundColor: primaryBtnFg,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.primary,
          side: BorderSide(color: colorScheme.primary, width: 1.0),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputFill,
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusMd), borderSide: BorderSide(color: inputBorder, width: 1.0)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusMd), borderSide: BorderSide(color: inputBorder, width: 1.0)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusMd), borderSide: BorderSide(color: colorScheme.primary, width: 1.8)),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: navBarBg,
        selectedItemColor: navActive,
        unselectedItemColor: navInactive,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: navBarBg,
        indicatorColor: navIndicator,
        iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(color: states.contains(WidgetState.selected) ? navActive : navInactive)),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(fontSize: 12, fontWeight: states.contains(WidgetState.selected) ? FontWeight.bold : FontWeight.w500, color: states.contains(WidgetState.selected) ? navActive : navInactive),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? segmentedSelectedBg : segmentedUnselectedBg),
          foregroundColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? segmentedSelectedFg : segmentedUnselectedFg),
          side: WidgetStateProperty.all(BorderSide(color: cardBorder, width: 1.0)),
        ),
      ),
      dividerTheme: DividerThemeData(color: dividerColor, thickness: 1),
      floatingActionButtonTheme: FloatingActionButtonThemeData(backgroundColor: colorScheme.primary, foregroundColor: Colors.white),
    );
  }

  // 1. Light Theme
  static ThemeData get lightTheme => _buildTheme(
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primaryOrange,
          brightness: Brightness.light,
          primary: AppColors.primaryOrange,
          onPrimary: AppColors.white,
          surface: AppColors.lightSurface,
          onSurface: AppColors.black,
        ),
        scaffoldBg: AppColors.lightBackground,
        appBarBg: AppColors.lightSurface,
        appBarFg: AppColors.black,
        overlayStyle: SystemUiOverlayStyle.dark,
        cardBg: AppColors.lightSurface,
        cardBorder: AppColors.lightBorder,
        primaryBtnBg: AppColors.primaryOrange,
        primaryBtnFg: AppColors.white,
        navBarBg: AppColors.lightSurface,
        navActive: AppColors.primaryOrange,
        navInactive: AppColors.mediumGray,
        navIndicator: AppColors.primaryOrange.withValues(alpha: 0.15),
        inputFill: AppColors.lightSurface,
        inputBorder: AppColors.lightBorder,
        dividerColor: AppColors.lightBorder,
        segmentedSelectedBg: AppColors.primaryOrange,
        segmentedSelectedFg: AppColors.white,
        segmentedUnselectedBg: AppColors.lightSurface,
        segmentedUnselectedFg: AppColors.black,
      );

  // 2. Dark Theme (Modern Dark Matte - Instagram Reference)
  static ThemeData get darkTheme => _buildTheme(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primaryOrange,
          brightness: Brightness.dark,
          primary: AppColors.primaryOrange,
          onPrimary: AppColors.white,
          surface: AppColors.darkSurface,
          onSurface: Colors.white,
        ),
        scaffoldBg: AppColors.darkBackground,
        appBarBg: AppColors.darkBackground,
        appBarFg: AppColors.white,
        overlayStyle: SystemUiOverlayStyle.light,
        cardBg: AppColors.darkSurface,
        cardBorder: AppColors.darkBorder,
        primaryBtnBg: AppColors.primaryOrange,
        primaryBtnFg: AppColors.white,
        navBarBg: const Color(0xFF161616),
        navActive: AppColors.primaryOrange,
        navInactive: AppColors.mediumGray,
        navIndicator: AppColors.primaryOrange.withValues(alpha: 0.22),
        inputFill: AppColors.darkSurface,
        inputBorder: AppColors.darkBorder,
        dividerColor: AppColors.darkBorder,
        segmentedSelectedBg: AppColors.primaryOrange,
        segmentedSelectedFg: AppColors.white,
        segmentedUnselectedBg: AppColors.darkSurface,
        segmentedUnselectedFg: Colors.white70,
      );
}
