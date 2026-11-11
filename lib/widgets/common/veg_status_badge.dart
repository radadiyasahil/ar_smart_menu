import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../models/product_model.dart';

/// Reusable Indian Food Standards Veg / Non-Veg indicator badge (green/red dot in rounded square).
class VegStatusBadge extends StatelessWidget {
  const VegStatusBadge({
    super.key,
    required this.vegStatus,
    this.size = 14.0,
  });

  final VegStatus vegStatus;
  final double size;

  static const Color vegColor = Color(0xFF20BF6B);
  static const Color nonVegColor = Color(0xFFFF5353);

  @override
  Widget build(BuildContext context) {
    if (vegStatus == VegStatus.notApplicable) return const SizedBox.shrink();

    final isNonVeg = vegStatus == VegStatus.nonVeg;
    final color = isNonVeg ? nonVegColor : vegColor;
    final dotSize = size * 0.42;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        border: Border.all(color: color, width: 1.5),
        borderRadius: BorderRadius.circular(size * 0.22),
      ),
      alignment: Alignment.center,
      child: Container(
        width: dotSize,
        height: dotSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
        ),
      ),
    );
  }
}

/// Reusable badge indicating whether a dish has interactive 3D AR or standard menu card display.
class ArBadge extends StatelessWidget {
  const ArBadge({
    super.key,
    required this.has3d,
    this.compact = false,
  });

  final bool has3d;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (has3d) {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 8, vertical: 2.5),
        decoration: BoxDecoration(
          color: AppColors.primaryOrange.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.primaryOrange.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.auto_awesome, size: 10, color: AppColors.primaryOrange),
            const SizedBox(width: 3),
            Text(
              '3D AR',
              style: TextStyle(
                fontSize: compact ? 10 : 11,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryOrange,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 8, vertical: 2.5),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        'Standard',
        style: TextStyle(
          fontSize: compact ? 10 : 11,
          color: AppColors.mediumGray,
        ),
      ),
    );
  }
}
