import 'package:flutter/material.dart';

/// Brand and UI color palette for AR Smart Menu.
/// Orange + black + white + light gray — SaaS-style accent colors.
class AppColors {
  AppColors._();

  // Primary brand
  static const Color primaryOrange = Color(0xFFFF6B00);
  static const Color primaryOrangeLight = Color(0xFFFF8A3D);
  static const Color primaryOrangeDark = Color(0xFFE55A00);

  // Neutrals
  static const Color black = Color(0xFF1A1A1A);
  static const Color darkGray = Color(0xFF2D2D2D);
  static const Color mediumGray = Color(0xFF6B7280);
  static const Color lightGray = Color(0xFFF3F4F6);
  static const Color borderGray = Color(0xFFE5E7EB);
  static const Color white = Color(0xFFFFFFFF);

  // Semantic
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryOrange, primaryOrangeDark],
  );

  static const LinearGradient darkGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [black, darkGray],
  );
}
