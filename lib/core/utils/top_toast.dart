import 'dart:async';
import 'package:flutter/material.dart';
import '../../routes/app_router.dart';

/// Centralized Top-Right Toast Notification for success, warning, and error messages.
/// Renders a sleek floating pill at the top-right corner of the screen.
class TopToast {
  static OverlayEntry? _activeEntry;
  static Timer? _dismissTimer;

  static void show(
    BuildContext? context,
    String message, {
    bool isError = false,
    bool isWarning = false,
    Duration? duration,
  }) {
    _dismissTimer?.cancel();
    _activeEntry?.remove();
    _activeEntry = null;

    final targetContext = (context != null && context.mounted)
        ? context
        : rootNavigatorKey.currentContext;
    if (targetContext == null) return;

    final overlay = Overlay.maybeOf(targetContext, rootOverlay: true);
    if (overlay == null) return;

    final isDark = Theme.of(targetContext).brightness == Brightness.dark;

    final lower = message.toLowerCase();
    final detectedError = isError ||
        lower.contains('error') ||
        lower.contains('fail') ||
        lower.contains('cannot') ||
        lower.contains('declined') ||
        lower.contains('❌');
    final detectedWarning = isWarning ||
        lower.contains('⚠️') ||
        lower.contains('warning') ||
        lower.contains('deactivated') ||
        lower.contains('please enter');

    final effectiveError = detectedError && !detectedWarning;
    final effectiveWarning = detectedWarning;

    final effectiveDuration = duration ??
        ((effectiveError || effectiveWarning)
            ? const Duration(milliseconds: 3200)
            : const Duration(milliseconds: 2500));

    final Color bgColor;
    final Color borderColor;
    final IconData iconData;

    if (effectiveError) {
      bgColor = isDark ? const Color(0xFF2E151A) : const Color(0xFFEF4444);
      borderColor = const Color(0xFFEF4444).withValues(alpha: 0.6);
      iconData = Icons.error_outline_rounded;
    } else if (effectiveWarning) {
      bgColor = isDark ? const Color(0xFF2D2312) : const Color(0xFFF59E0B);
      borderColor = const Color(0xFFF59E0B).withValues(alpha: 0.6);
      iconData = Icons.warning_amber_rounded;
    } else {
      bgColor = isDark ? const Color(0xFF14291F) : const Color(0xFF10B981);
      borderColor = const Color(0xFF10B981).withValues(alpha: 0.6);
      iconData = Icons.check_circle_rounded;
    }

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) {
        final topPadding = MediaQuery.of(ctx).padding.top;
        final screenWidth = MediaQuery.of(ctx).size.width;
        final maxW = screenWidth > 450 ? 420.0 : screenWidth - 32.0;

        return Positioned(
          top: topPadding + 14,
          right: 14,
          child: Material(
            color: Colors.transparent,
            child: GestureDetector(
              onTap: () {
                _dismissTimer?.cancel();
                if (_activeEntry == entry) {
                  entry.remove();
                  _activeEntry = null;
                }
              },
              child: AnimatedOpacity(
                opacity: 1.0,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  constraints: BoxConstraints(maxWidth: maxW),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor, width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        iconData,
                        color: Colors.white,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          message,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        Icons.close_rounded,
                        color: Colors.white.withValues(alpha: 0.7),
                        size: 14,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    _activeEntry = entry;
    overlay.insert(entry);

    _dismissTimer = Timer(effectiveDuration, () {
      if (_activeEntry == entry) {
        entry.remove();
        _activeEntry = null;
      }
    });
  }

  static void success(BuildContext? context, String message, {Duration? duration}) {
    show(context, message, isError: false, duration: duration);
  }

  static void error(BuildContext? context, String message, {Duration? duration}) {
    show(context, message, isError: true, duration: duration);
  }

  static void warning(BuildContext? context, String message, {Duration? duration}) {
    show(context, message, isWarning: true, duration: duration);
  }
}
