import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../constants/app_routes.dart';
import '../../providers/business_provider.dart';

/// Checks if the business has an active subscription or trial.
/// If active, returns true immediately.
/// If inactive/expired, shows an attractive modal prompt and returns false.
bool checkSubscriptionGuard(BuildContext context, {String featureName = 'this feature'}) {
  final provider = context.read<BusinessProvider>();
  if (provider.hasActiveSubscription) {
    return true;
  }

  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (modalCtx) {
      final isExpired = provider.subscription != null && !provider.subscription!.isActive;
      final hasUsedTrial = provider.hasUsedTrial;

      return Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Color(0xFF181920),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(top: BorderSide(color: Color(0xFF2B2C38), width: 1.5)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isExpired
                        ? [const Color(0xFFEF4444), const Color(0xFFDC2626)]
                        : [const Color(0xFFFF5353), const Color(0xFFFF7043)],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: (isExpired ? const Color(0xFFEF4444) : const Color(0xFFFF5353)).withValues(alpha: 0.35),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Icon(
                  isExpired ? Icons.timer_off_rounded : Icons.workspace_premium_rounded,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                isExpired ? 'Subscription Plan Expired' : 'Plan Activation Required',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                isExpired
                    ? 'Your restaurant subscription has ended. Please renew to continue using $featureName and accept diner orders.'
                    : hasUsedTrial
                        ? 'An active subscription plan is required to use $featureName. Plans start at just ₹833/month.'
                        : 'Unlock $featureName with our 7-Day Free Trial (₹0) or choose an affordable quarterly/annual plan.',
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF9CA3AF),
                  height: 1.45,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(modalCtx).pop(),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF34384B)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Cancel', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(modalCtx).pop();
                        context.push(AppRoutes.subscription);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF5353),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 4,
                      ),
                      icon: const Icon(Icons.stars_rounded, color: Colors.white, size: 18),
                      label: Text(
                        hasUsedTrial ? 'View Plans (+GST)' : 'Start 7-Day Free Trial',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );

  return false;
}
