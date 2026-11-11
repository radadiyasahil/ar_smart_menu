import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

/// Card wrapper with crisp border and animated hover effect (slim light border + elevation glow).
class HoverCard extends StatefulWidget {
  const HoverCard({
    super.key,
    required this.child,
    this.onTap,
    this.borderRadius = 16,
    this.color,
    this.borderColor,
    this.hoverBorderColor,
    this.padding,
    this.margin,
    this.clipBehavior = Clip.antiAlias,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double borderRadius;
  final Color? color;
  final Color? borderColor;
  final Color? hoverBorderColor;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Clip clipBehavior;

  @override
  State<HoverCard> createState() => _HoverCardState();
}

class _HoverCardState extends State<HoverCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final defaultBg = widget.color ?? (isDark ? AppColors.darkSurface : AppColors.lightSurface);
    final defaultBorder = widget.borderColor ?? (isDark ? AppColors.darkBorder : AppColors.lightBorder);
    final hoverBorder = widget.hoverBorderColor ?? AppColors.primaryOrange.withValues(alpha: 0.85);

    return MouseRegion(
      cursor: widget.onTap != null ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        margin: widget.margin,
        decoration: BoxDecoration(
          color: defaultBg,
          borderRadius: BorderRadius.circular(widget.borderRadius),
          border: Border.all(
            color: _hovered ? hoverBorder : defaultBorder,
            width: _hovered ? 1.4 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: _hovered
                  ? AppColors.primaryOrange.withValues(alpha: isDark ? 0.22 : 0.12)
                  : Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
              blurRadius: _hovered ? 16 : 8,
              offset: _hovered ? const Offset(0, 4) : const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: widget.clipBehavior,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(widget.borderRadius),
            child: Padding(
              padding: widget.padding ?? EdgeInsets.zero,
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}
