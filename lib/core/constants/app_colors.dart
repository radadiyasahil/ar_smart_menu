import 'package:flutter/material.dart';

/// Brand and UI color palette inspired by modern dark food apps (Instagram reference).
class AppColors {
  AppColors._();

  // Primary brand (Fiery Sunset Orange from Instagram reference)
  static const Color primaryOrange = Color(0xFFEB4F16);
  static const Color primaryOrangeLight = Color(0xFFFF6A3D);
  static const Color primaryOrangeDark = Color(0xFFD43F08);

  // Accent & Semantic
  static const Color accentGreen = Color(0xFF20BF6B);
  static const Color success = Color(0xFF20BF6B);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // Dark Theme (Instagram reference)
  static const Color darkBackground = Color(0xFF121212);
  static const Color darkSurface = Color(0xFF1E1E1E);
  static const Color darkSurfaceElevated = Color(0xFF252525);
  static const Color darkBorder = Color(0xFF2C2C2C);

  // Light Theme
  static const Color lightBackground = Color(0xFFF6F7F9);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightBorder = Color(0xFFE3E6EB);

  // Neutrals
  static const Color black = Color(0xFF121212);
  static const Color darkGray = Color(0xFF1E1E1E);
  static const Color mediumGray = Color(0xFF8E8E93);
  static const Color lightGray = Color(0xFFF3F4F6);
  static const Color borderGray = Color(0xFFE5E7EB);
  static const Color white = Color(0xFFFFFFFF);

  // Gradients
  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFEB4F16), Color(0xFFFF6A3D)],
  );

  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryOrange, primaryOrangeDark],
  );

  static const LinearGradient darkGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1E1E1E), Color(0xFF161616)],
  );
}
